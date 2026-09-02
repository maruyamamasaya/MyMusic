# MyMusic Analytics v0

MyMusicの再生履歴JSONをPCへ取り込み、ローカルブラウザで閲覧する独立ツールです。iOSアプリのファイル、内部DB、再生処理には接続せず、AnalyticsからMyMusicへの書き戻しも行いません。

iPhoneの「設定」→「データ管理」から生成される`MyMusic-Playback-Events.json`、`MyMusic-Library.json`、`MyMusic-Playback-Preferences.json`に対応します。3ファイルは共通のTrack IDで結合されます。

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
| `MyMusic-Library.json` | `version: 1` + `tracks` | 曲名、Artist、Album、Genre、年、長さ、Format、お気に入り、作成済み音声Fingerprint等のLibrary snapshot |
| `MyMusic-Playback-Preferences.json` | `schemaVersion: 1` + `tracks[].playbackPreference` | Track IDごとの現在のGood／Bad値（-10〜+10） |

Libraryと再生傾向はTrack ID単位でupsertし、同じ内容は重複、値が変わった項目は更新として記録します。`audioFingerprint`はoptionalの64文字lowercase SHA-256として検証し、Tracks画面で作成済み状態を確認できます。Fingerprintが同じ別Track IDの候補検出・alias統合は将来対応であり、現在は自動統合しません。完全に検証できた新しいLibrary snapshotに含まれない曲は現在Libraryから外れたものとして画面から除外しますが、SQLiteのRaw rowは削除せず保持します。Import順は問いません。

有効な文書原本は`imports/`へ衝突しない名前で保存し、受理した各項目のRaw JSONもSQLiteへ保持します。不正な文書はデータを保存しませんが、失敗したImport履歴は記録します。

SQLiteは`data/analytics.sqlite3`です。WALを使用し、日時・Track・Artistに索引を持ちます。`data/`と`imports/`の内容はGit対象外です。バックアップ時はサーバーを停止して両ディレクトリをまとめてコピーしてください。

## Dashboard / API

- Overview: Library曲数、お気に入り数、Good／Bad登録数と分布、今日／7日／30日／全期間の再生回数、時間、Skip率、完走率、日別・時間帯別・曲別・Artist別集計
- Tracks: 未再生曲を含むLibrary、Good／Bad、お気に入り、曲metadata、再生回数、総再生時間、完走率、Skip率、最終再生日時、検索
- Import: 3種類のJSON自動判別アップロードと、新規／更新／重複／エラーを含む直近100件のImport履歴

主なAPIは`GET /api/dashboard?period=7d`、`GET /api/tracks?period=all&search=`、`POST /api/import`、`GET /api/imports`です。FastAPIのAPI仕様は起動中の`/docs`で確認できます。

## テスト

```bash
cd analytics
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
```

Windowsではactivate後の最後の2行は同じです。テストは一時ディレクトリだけを使い、通常の`data/`と`imports/`を変更しません。
