# MyMusic Analytics v0

MyMusicの再生履歴JSONをPCへ取り込み、ローカルブラウザで閲覧する独立ツールです。iOSアプリのファイル、内部DB、再生処理には接続しません。PreferenceだけはAnalytics内で編集し、明示的に書き出したJSONをアプリで読み込む手動連携に対応します。

iPhoneの「設定」→「データ管理」から生成される8種類のJSONに対応します。Library、再生、特徴量、音量、プレイリスト内の曲は共通のTrack IDで結合されます。EQとジャンルプリセットは曲単位ではないため、独立した設定スナップショットとして保持します。

## 構成

```text
analytics/
├── app/          # FastAPI、SQLite、集計query
├── importer/     # playback export v1の検証・保存境界
├── web/          # vanilla HTML/CSS/JavaScript
├── data/         # ローカルSQLite（Git対象外）
├── imports/      # 受理した原本JSON（Git対象外）
├── tests/
├── playback-export-v1.schema.json
├── requirements.txt
├── start.sh
└── start.ps1
```

`analyzer/`やSwift modelを直接importしません。将来のiOS、Android、Analyzer連携は、Importerへ別のversioned data contractを追加する形で拡張できます。

## セットアップと起動

macOS（Python 3.11以上を推奨）:

```bash
cd analytics
chmod +x start.sh
./start.sh
```

Windows PowerShell:

```powershell
cd analytics
.\start.ps1
```

初回は`.venv`を作成して依存を導入します。起動後は [http://127.0.0.1:8766](http://127.0.0.1:8766) を開きます。ブラウザを自動起動しない場合は`MYMUSIC_ANALYTICS_NO_BROWSER=1`（PowerShellは`$env:MYMUSIC_ANALYTICS_NO_BROWSER="1"`）を指定してください。

サーバーはループバックアドレスだけでlistenします。認証機能はないため、`--host 0.0.0.0`へ変更してLANやインターネットへ公開しないでください。

## Playback Export JSON v1

完全な契約は[`playback-export-v1.schema.json`](playback-export-v1.schema.json)、入力例は[`playback-export-v1.example.json`](playback-export-v1.example.json)です。

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-09-02T12:00:00Z",
  "events": [
    {
      "eventId": "87c27231-f86a-4a4c-9a6e-34c160dad897",
      "trackId": "stable-track-id-001",
      "trackTitle": "Night Drive",
      "artist": "Example Artist",
      "album": "City Lights",
      "playedAt": "2026-09-02T11:42:00+09:00",
      "playDuration": 232.5,
      "trackDuration": 238.0,
      "completed": true,
      "skipped": false,
      "playSource": "playlist",
      "selectionType": "manual",
      "sessionId": "session-20260902-001",
      "platform": "iOS",
      "schemaVersion": 1
    }
  ]
}
```

- 日時はタイムゾーン付きISO 8601です。
- durationの単位は秒で、0以上です。
- `completed`と`skipped`を同時に`true`にはできません。
- rootと各eventの`schemaVersion`はv1では`1`です。
- 未知fieldは入力ミスや契約不一致を発見するため拒否します。
- `eventId`は全データソースを通して安定かつ一意にしてください。SQLiteの主キーにし、同じファイル内または後日の再Importでも二重登録しません。
- `trackId`は集計identityです。タイトル変更後も同じ曲として集計するには安定IDを維持してください。
- `playSource`、`selectionType`、`platform`はv0では非空文字列として保持します。将来enumを追加してもRaw eventを再利用できます。

## Importとデータ保持

Import画面ではドラッグ&ドロップまたはファイル選択ができます。20 MBまでのJSONをroot fieldから自動判別し、項目単位で検証して新規・更新・重複・エラー件数を返します。

| ファイル | 判別契約 | 保存内容 |
| --- | --- | --- |
| `MyMusic-Playback-Events.json` | `schemaVersion: 1` + `events` | 追記型のRaw再生イベント。`eventId`で重複排除 |
| `MyMusic-Library.json` | `version: 1` + `tracks` | 曲名、Artist、Album、Genre、年、長さ、Format、作成済み音声Fingerprint等のLibrary snapshot。旧Favorite fieldは互換入力として受理 |
| `MyMusic-Playback-Preferences.json` | `schemaVersion: 2` + `tracks[].playbackPreference/favorite` | Track IDごとの現在のGood／Bad値（-10〜+10）と曲Favorite。schema v1も後方互換で受理 |
| `MyMusic-Track-Features.json` | `version: 1` + `tracks[].features` | Track IDごとの音楽特徴量と解析情報 |
| `MyMusic-Volume-Normalization.json` | `version: 1` + `isEnabled` + `tracks` | Track IDごとのLUFS、True Peak、補正Gain |
| `MyMusic-Playlists.json` | `version: 1` + `playlists` | Playlist metadata、タグ、収録曲とLibrary照合状況 |
| `MyMusic-Equalizer.json` | `kind: mymusic.equalizer` | 現在のEQ設定とカスタムプリセット |
| `MyMusic-Genre-Display-Presets.json` | `kind: mymusic.genre-display-presets` | ジャンル表示プリセットと有効ジャンル |

Libraryと再生傾向はTrack ID単位でupsertし、同じ内容は重複、値が変わった項目は更新として記録します。`audioFingerprint`はoptionalの64文字lowercase SHA-256として検証し、Tracks画面で作成済み状態を確認できます。Fingerprintが同じ別Track IDの候補検出・alias統合は将来対応であり、現在は自動統合しません。完全に検証できた新しいLibrary snapshotに含まれない曲は現在Libraryから外れたものとして画面から除外しますが、SQLiteのRaw rowは削除せず保持します。Import順は問いません。

Tracks画面ではImport済みPreferenceのFavoriteと-10〜+10のGood／Badを編集できます。編集は`playback_preferences`だけを更新し、Library、Playback Events、Features等には触れません。「再生傾向を書き出す」は、現在Libraryに存在してTrack IDが有効なUUIDであるPreferenceだけを`MyMusic-Playback-Preferences.json`（schema v2）へ出力します。古い、未照合、UUIDでない行はSQLiteに保持したままExport対象外とし、アプリ側でもLibrary照合を再実施します。

有効な文書原本は`imports/`へ衝突しない名前で保存し、受理した各項目のRaw JSONもSQLiteへ保持します。不正な文書はデータを保存しませんが、失敗したImport履歴は記録します。

SQLiteは`data/analytics.sqlite3`です。WALを使用し、日時・Track・Artistに索引を持ちます。`data/`と`imports/`の内容はGit対象外です。バックアップ時はサーバーを停止して両ディレクトリをまとめてコピーしてください。

## Dashboard / API

- Overview: Library曲数、お気に入り数、Good／Bad登録数と分布、今日／7日／30日／全期間／任意期間の再生回数、時間、Skip率、完走率、Early Skip数・率、月日・曜日・件数付き日別グラフ、時間帯別・曲別・Artist別集計。Early Skipランキングは回数、総再生回数、率を表示する。日別グラフは土曜と日曜・日本の祝日を色分けし、棒の選択でその1日へ期間を絞り込む。ランキングは共通定義で初期30件から30件ずつ展開
- Music History: JSTの月ごとの再生回数・再生時間・その月の代表曲・代表Artistを新しい月からタイムライン表示し、30か月ずつ展開
- Insights: 「おすすめ」「最近の変化」「時間帯・好み」「再生行動」のタブに分け、再生入口、選択種別、音楽特徴の5段階比較に加え、最近ハマった／飽きてきた／新しい好み／再発見、JST時間帯×特徴、Artist／Album／Genreの変化、Listening Profileを表示する。時間帯・好み内の行形式一覧は共通定義で初期30件、30件ずつ展開する。再生行動の各表は共通の列ソート定義により、見出しから昇順／降順を切り替えられる。現在の好み・評価・完走実績とOverplay減点によるおすすめ、再発見、好みに近い未再生・低再生曲、最大5件の自動Insightカードも提供する。「分析可能データのみ」（既定）と「すべて」の品質フィルターを期間指定と併用可能
- Rankings: 曲／Artist／Album／Genreと再生回数／再生時間を切り替え、今日／7日／30日／全期間／任意期間の上位50件を初期30件から30件ずつ展開
- Tracks: 未再生曲を含むLibrary、Good／Bad、お気に入り、曲metadata、期間別の再生回数・総再生時間・完走率・Skip率・Early Skip回数・率・最終再生日時、項目別AND検索、全表示列の全件基準ソート、30件ページング、Import済みPreferenceの編集と手動Export
- Data Sources: 特徴量、音量、プレイリスト、EQ、ジャンルプリセットに加え、Libraryから自動導出したジャンル一覧をタブ別に表示。ジャンルはiOSアプリと同様に`;`／NULで分割し、空白・空要素・曲内重複を除いて集計する。表示列ごとの全件基準ソートと30件ページングを行い、曲単位データはLibraryとのTrack ID照合状況も表示
- Import履歴: 全列を昇順／降順でソートでき、初期30件から30件ずつ展開
- Import: 8種類のJSON自動判別アップロードと、新規／更新／重複／エラーを含む直近100件のImport履歴

左ナビゲーションとInsights内タブはURL履歴に反映されます。ブラウザの戻る／進むで直前の画面へ移動でき、再読み込み後も選択中の画面とInsightsタブを復元します。

主なAPIは`GET /api/dashboard`、`GET /api/music-history`、`GET /api/insights`、`GET /api/insights/features`、`GET /api/insights/recent-changes`、`GET /api/insights/advanced`、`GET /api/insights/recommendations`、`GET /api/rankings`、`GET /api/tracks`です。Insights系は共通して期間と`quality=analyzable|all`を受け取ります。比較系の`all`は直近30日対その前30日、その他は選択期間対直前の同日数です。特徴量APIは最新の数値`analysisVersion`だけを使用し、レスポンスにもVersionと閾値を明示します。FastAPIのAPI仕様は起動中の`/docs`で確認できます。

Dashboard APIとTracks APIは`period=custom&startDate=YYYY-MM-DD&endDate=YYYY-MM-DD`に対応します。Tracks APIは従来の`period=today|7d|30d|all`と`search=`を維持し、`title`、`artist`、`album`、`genre`、`sort`、`order=asc|desc`、`page`も受け付けます。項目別フィルターは部分一致のAND条件です。`sort`は`title`、`artist`、`album`、`preference`、`playCount`、`totalPlayTime`、`completionRate`、`skipRate`、`earlySkipCount`、`earlySkipRate`、`lastPlayedAt`の許可リストに限定されます。値はすべてSQLiteのparameter bindingで渡します。TracksとData Sourcesは1ページ200件で、APIも`LIMIT`／`OFFSET`によるサーバー側ページングを行います。Data Sourcesは許可リスト方式で名称、補足情報、Library紐付け、取込日時を昇順／降順に並べ替えられます。

期間フィルターと日別・時間帯別集計の基準タイムゾーンは日本標準時（JST、UTC+09:00）です。サーバーを日本以外のタイムゾーンで起動した場合も、「今日」と日付指定はJSTの日付境界で一致します。保存済み日時はUTCのまま保持します。

Playback詳細指標の信頼開始日は`2026-09-01`です。DashboardとTracksのPlay Countはそれ以前のイベントも含めますが、総再生時間、完走率、Skip率、Early Skip、最終再生日時は開始日以降のイベントだけで集計します。Early Skipは`skipped = true AND play_duration <= 30`で、率の分母は信頼開始日以降の詳細イベント数です。旧イベントしかない場合は率などの詳細指標を`null`で返し、画面では`0`や`0%`ではなく「データなし」または`—`と表示します。説明はOverviewに表示し、Tracksの一覧には重ねて表示しません。Rawイベントは変更・削除しません。

## テスト

```bash
cd analytics
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
```

Windowsではactivate後の最後の2行は同じです。テストは一時ディレクトリだけを使い、通常の`data/`と`imports/`を変更しません。
