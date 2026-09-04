---
status: active
updated: 2026-09-03
---

# MyMusic の現在状態

## 現在の位置づけと優先事項

- iPhone 向け個人用ローカル音楽プレイヤー。App Store 正式リリースを示す版番号は確認できません。
- 2026-08-14 の「完成基準版」を、基本体験を維持する基準としている。
- 現在は Original Features Beta を小さく追加し、個別に build・検証・文書化する段階。
- 最優先は、ライブラリ、検索、再生、お気に入り、プレイリスト、データ管理の基準版を回帰させないこと。
- Streaming / server integration は未着手の将来領域。

この方針を採った経緯は [ADR-0002](decisions/ADR-0002-baseline-and-beta-delivery.md)、利用者向け機能説明は [README.md](README.md) を参照してください。

## 実装済み

### ローカルWeb Analytics v0

- リポジトリ直下の`analytics/`に、再生履歴JSON v1を独自SQLiteへ取り込み、Dashboard／Tracks／Import履歴をPCブラウザで確認するFastAPI製ローカルツールを追加した。
- `MyMusic-Library.json`と`MyMusic-Playback-Preferences.json`も自動判別して専用tableへupsertし、Track IDで再生イベントと結合する。DashboardはLibrary／お気に入り／Good・Bad分布、Tracksは未再生曲を含むmetadataと現在評価を表示し、Import済みPreferenceのFavorite／Good・Badを編集できる。
- Dashboard／Tracksの期間フィルターと日別・時間帯別集計は日本標準時（JST、UTC+09:00）を基準とし、「今日」と同じ当日の期間指定が一致する。再生イベントの保存日時はUTCのまま維持する。
- Overviewの日別再生数は月日と曜日を2段で表示し、土曜、日曜・日本の祝日を色分けする。各日の棒を選ぶとOverviewの期間指定をその1日へ切り替える。
- OverviewとTracksは2026-09-01以降の詳細イベントからEarly Skip（skipかつ30秒以下）を集計する。Overviewは総数・率・曲ランキング、Tracksは曲別回数・率とソートを提供し、対象詳細イベントがなければ率をデータなしとして扱う。
- Insightsは期間別に再生入口と選択種別、および両者の組み合わせを動的に集計し、再生回数・詳細再生時間・完走率・Skip率・Early Skipを比較表示する。日時に基づくデータ品質フィルターは分析可能データのみを既定とし、全イベント表示とも切り替えられる。未知の入口・選択種別も固定enumなしで扱う。
- Insightsの音楽特徴と再生行動は最新analysisVersionのTrack FeaturesをTrack IDでPlayback Eventへ結合し、9特徴量を重複しない5スコア帯で比較する。欠損・非数値・0〜1範囲外を除外し、SQLite JSON関数で集計する。
- Insightsは選択期間と直前の同日数を比較して曲・特徴・Artist／Album／Genreの最近の変化を説明可能な閾値で抽出し、JST時間帯別の特徴相性と5段階Listening Profileも表示する。これらを再利用したread-only推薦は特徴一致、Favorite／Good、完走実績を加点し、Skipと最近の聴きすぎを減点する。再発見・未再生／低再生候補と最大5件の自動Insightも理由付きで表示する。
- 長いInsights画面は「おすすめ」「最近の変化」「時間帯・好み」「再生行動」の4タブに分割する。「再生行動」はさらに再生入口、選択種別、組み合わせ、音楽特徴の4サブタブに分け、各表を共通定義で列ソートできる。時間帯・属性・現在の好みにある行形式の一覧は初期30件とし、30件ずつ「続きを見る」で展開する。左ナビゲーションとInsightsタブをURL履歴へ反映し、ブラウザの戻る／進むと再読み込みで表示位置を復元する。
- Overviewと分けたMusic Historyは、JSTの月ごとに再生回数・詳細取得後の再生時間・代表曲・代表Artistをタイムライン表示する。月カードを1件だけインライン展開し、「日ごと」「ランキング」「振り返り」から日別の再生曲、4種類の月間上位、月間指標と前月比を確認できる。Rankingsは今日／7日／30日／全期間／任意期間、Artist／Genreフィルター、再生回数／再生時間を共通条件とし、曲・Artist・Album・Genreの上位50件を4列で同時表示する。
- Analyticsの非ページング一覧は共通定義で初期30件・30件ずつ展開し、TracksとData Sourcesは1ページ30件のサーバーページングを使う。表は表示する全列を見出しから昇順／降順に切り替えられ、ページング表のソートは全件を対象とする。
- Track Features、Volume Normalization、Playlists、Equalizer、Genre Display Presetsの各JSONもImportできる。Data Sources画面で種類別に閲覧し、Libraryの曲metadataからiOSと同じ分割規則で導出したジャンル一覧も表示する。曲単位データはLibraryとのTrack ID照合状況を表示する。
- AnalyticsのImport画面から、確認ダイアログを経てSQLite内の全取込データとImport履歴を一括クリアできる。schemaと保存済み原本JSONは保持し、直後から再Importできる。
- AnalyticsのTrack FeaturesはTrack ID完全一致を優先し、Library入力にoptionalの`relativePath`／`fileSize`がある場合だけ、本体と同じpath・file size・duration（0.5秒許容）・metadata条件で一意候補を救済する。identity不足・曖昧候補は未紐付けを維持し、Library／Featuresの再Import時に再解決する。
- iOSアプリ、iOS内部DB、`analyzer/`とは実装・永続化とも分離する。Analyticsからの書き戻しは、現在Libraryと照合できる有効なUUIDのPreferenceだけをschema v2 JSONへ手動Exportし、アプリの明示Importを経る。受理したeventは`eventId`で重複排除し、Raw JSONとImport原本をローカルに保持する。
- macOSは`analytics/start.sh`、Windowsは`analytics/start.ps1`から`127.0.0.1:8766`で起動する。データ契約とセットアップは`analytics/README.md`を正とする。

### 基準版

- Files / iCloud Drive の複数フォルダ登録、security-scoped bookmark の復元、音源 scan と library cache。
- ライブラリ同期の走査、metadata／Track Identity照合、cache保存、結合・派生モデル構築は専用actorでMainActor外かつ直列に実行する。UIへはフォルダ単位の完成結果だけを反映し、同期中も既存libraryと再生を維持する。
- 曲、アルバム、アーティスト、ジャンル、作曲者別の閲覧、ジャンル表示設定、非同期 sort / 段階表示。ジャンル設定適用時の全ライブラリ再構築は専用actorで実行し、最新の結果だけをMainActorへ反映する。
- ジャンル表示設定では、ライブラリに「作業用BGM」が存在する場合は常に表示対象とし、選択画面に固定項目として表示する。個別設定、全解除、保存済み／旧プリセットからOFFにはできない。
- iTunes / ID3のAlbum Artistと年を保持し、アルバムの統合・表示・検索に使用。検索画面では曲名、アルバム名、アーティスト名、アルバムアーティスト、年代を個別に選べ、225ms debounce、入力Task cancellation、専用actor検索、結果state保持を行う。
- ローカル音源の再生、一時停止、seek、前後移動、queue、shuffle、repeat、EQ、共通 playback transition。
- mini player / Now Playing、audio 情報、簡易 spectrum、lock screen / Control Center 情報、remote command、background audio 設定。
- ホームのライブラリ／アクティビティ各タイルは、ビルド前に所定名のローカル画像を置くと背景へ使用する。未配置・破損時は既存の個別グラデーションを維持する。
- ステーションの「気分を伝えて再生」カードは、ビルド前に所定名のローカル画像を置くと背景へ使用する。未配置・破損時は既存のグラデーションを維持する。
- 曲・アルバム・アーティストのお気に入り、通常 / 作業用 playlist、playlist import / export。
- プレイリスト、ライブラリ、再生履歴、解析データ、設定、分析CSVの共有は共通の`UIActivityViewController`経路を使い、Popoverが必要な端末では常にsource view / rectを設定する。
- 複数条件検索、home の各種再生入口、アクティビティから直接開ける再生分析／音楽史、再生回数・評価・履歴・analytics、calendar / yearly insights / discovery / memory navigation。

### Beta

- **Track Preference責務分離**: 曲Favoriteと`playbackPreference`の正本を`TrackPreferenceStore`／`Application Support/MyMusic/track-preferences.json`（schema v2）へ移した。初回は旧Playback Historyの値をatomic保存・read-back検証して移行し、以後UI、検索、選曲、分析、ExportはPreferenceを参照する。旧History field／SQLite列は後方互換migration用に残す。Preference Exportは`trackId`、`playbackPreference`、`favorite`を含むschema v2とする。
- **Track Preference手動双方向連携**: アプリは同じschema v2 Preference JSONを厳格に全体検証し、現在LibraryにあるTrackだけをmerge保存してからStoreへ反映する。未知field、UUID不正、重複、範囲外、不正構造は全件拒否し、未収録Trackは既存値を変えずskipする。AnalyticsはImport済みPreferenceだけを編集し、現在Libraryと照合できる有効UUIDだけを同契約でExportする。

- **データ管理の解析・設定JSON**: 音量ノーマライズ解析値と音楽特徴量を用途別JSONへ出力する。ローカルWeb Analytics契約に合わせた再生イベントJSONを、保存済みPlayback Eventと現在のLibrary metadataから生成する。曲Favoriteと再生傾向はTrack ID単位のschema v2 Preference JSONへ分離し、再生履歴を混在させず、Preferenceだけは厳格検証付きで再Importできる。現在のEQ＋オリジナルEQプリセット、ジャンル表示プリセットはversioned JSONで出力・読込できる。解析データのiOS再Importは対象外。
- **Analytics用JSON書き出し導線**: 設定の「データ管理」から、PC版Analyticsが対応する8種類の既存JSON書き出しを1画面で個別に共有できる。オンライン同期や自動送信は行わない。
- **Track Fingerprint作成**: データ管理の専用画面で未作成曲を件数上限なく逐次処理し、1曲完了ごとに既存Track identity registryへ保存する。初回起動・通常scanでは自動実行せず、画面離脱、非active、再生開始、Library scan開始でcancelする。既定はdownload済み音源だけで、iCloud取得は明示toggleとする。Library JSONは保存済みFingerprintだけをoptional fieldへ出力する。
- **プレイリストタグ**: 通常／作業用Playlistへ複数タグを保存し、一覧と曲の追加先を1タグで絞り込む。旧Playlist JSONは空タグでdecodeし、JSON／Markdown import / exportでもタグを保持する。タグ・曲構成の更新は再生開始時のPlayerStore queue snapshotへ伝播させず、Playlist保存は更新順に直列化する。
- **Track Adjustments**: 通常Now Playingのアートワーク面を「アートワーク→オーディオ情報→曲別調整」の3状態にし、Stable Track IDごとの開始位置・終了位置・前回位置・±2 dBの手動ノーマライズ微調整を端末内へ保存する。開始／終了位置に共通の1秒戻る操作と、登録成功時のインラインフィードバックを持つ。終了位置はPlayerStoreの再生時刻eventから既存の次曲処理へ合流する。
- **音量ノーマライズ**: Mac Analyzerが全曲のIntegrated LUFS / True Peakと控えめな固定ゲインを算出し、特徴量JSON経由でiPhoneへ渡す。-17〜-11 LUFSは無補正、最大±4 dB、-1 dBTP ceiling。設定は初期OFFで、音源変更・動的圧縮は行わない。
- **1曲ごとの再生履歴リセット**: 分析の「よく再生している曲」を長押し、確認後にその曲の再生回数・日時履歴だけを削除できる。お気に入りや評価、シャッフル除外は保持し、全曲一括リセットは持たない。
- **Playback History 拡張**: 再生履歴は初回／最終再生日時、総再生時間、スキップ／完走、連続再生、リピート再生、manual / automatic、入口別、日別集計を保持する。再生中はPlayerStore内で軽量に集計し、曲変更・停止・一定間隔・background移行でまとめて保存する。日別集計は再生された日のみ保持し、直近7日／30日は保存値ではなく集計から算出する。
  - ハイライト入口の再生は、実聴5秒未満でユーザーが離脱した場合だけ分析上のSkipとする。5秒以上では`endKind = user_skipped`を操作事実として保持しつつ、Skip／Early Skip集計から除外する。
  - Playback Event Foundationは開始／終了日時、実聴秒数、完走率、skip／完走、開始種別／入口、終了理由をセッション終了時に1件へ確定する。early skipの基礎定義は`wasSkipped && listenedSeconds <= 30`。日別集計は完走、skip、early skip件数も保持し、候補判定、Overplay、Preference Drift、選曲補正は後続M2〜M4で利用する。
  - 通常運用の正本は `Application Support/MyMusic/playback-history.sqlite3`。旧JSONは変更せず永久migration backupへatomic copyし、transaction importと全項目read-back検証後だけ`verified`へ切り替える。通常更新は対象曲と正規化した子レコードだけをtransaction更新する。
  - 起動時に前回から24時間以上ならSQLite snapshotを`Backups/Daily`へatomic JSON出力し、直近7世代を保持する。`Backups/Migration`はrotation対象外。Restore UIは未実装。
  - CSVエクスポートの運用フォーマットは `種類,日時,曲名,アーティスト,再生回数,値,詳細` で固定し、`楽曲別再生行動`（manual/automatic、7日/30日、初回/最終再生）と`楽曲別再生入口`（入口別集計）を追加する。既存CSVインポートは未対応のため、この形式を基準（正）とする。
- **ライブラリ整理候補 M2**: 通常曲の新形式Playback Eventを直近20件まで使い、最低5件、ユーザーの「次へ」による途中スキップ率50%以上、平均再生率10%以下をすべて満たす曲を確認できる。既存`playCount`や直接選択、Good / Badは判定に使わない。候補提示は評価、飽き度、恒久非表示、履歴を自動変更しない。
- **Behavior Scoring M3**: 保存済み日別集計から直近7日対過去56日のOverplayと、直近30日対それ以前の完走率によるPreference Driftを都度導出する。Good / Bad重みは専用Policyの-10〜+10テーブルへ分離し、設定の「再生傾向」で候補を確認できる。スコアは保存せず、評価・飽き度・恒久非表示を自動変更しない。選曲補正はM4対象。
- **Selection Integration M4**: Overplayを保存済み日別集計から選曲処理ごとに導出し、通常の自動shuffle系は最大50%、Mood Stationは候補pool確定後のrankingだけを最大20%減衰する。手動選択、未再生Discovery、作業用再生には適用せず、Preference Drift、Good / Bad、Boredom、永続データを変更しない。
- **ハイライト再生**: 約30秒の候補区間、縦 paging、先読み cache、反応による傾向調整。
- **作業用サイズ再生**: 20分以上または「作業用BGM」の曲を通常ランダム再生から分離し、専用 player / playlist を提供。ホームの入口から曲名、アルバム、アーティスト、アルバムアーティスト、プレイリスト別の専用一覧へ進み、各一覧を検索できる。ホームではこの入口を先頭に、最大10件の作業用プレイリストを表示し、残りがある場合は12枠目を「続きを見る」とする。
- **選択してランダム再生**: 最初の候補曲と共通ジャンルを起点に queue を作成。
- **ホーム代表アートワーク**: 「マイミュージック」の各タイルは通常再生対象の代表Trackをホーム表示時と約1分ごとに選び、単なる再描画では変更しない。即時ランダム再生では表示中の代表Trackを先頭へ置き、後続は既存の選曲順を重複なしで維持する。
- **気分ステーションの年代指定**: 気分・音の特徴に加え、通常再生対象かつ特徴量のある曲の年metadataから10年単位の候補を構成し、任意の年代へ絞って一時queueを生成できる。年がないlibraryでは年代質問を省略し、「すべての年代」では従来の選曲を維持する。
- **共通再生トランジション**: 設定可能な fade と切替時の安全減衰。crossfade ではない。
- **音楽特徴量 Beta 1 / 3**: Mac Analyzer の schema v1 JSON を安全に照合・永続化し、audio 情報面で分類 badge と詳細を表示。
- **Semantic v2 Analyzer**: 保存済みEmbeddingと学習済みheadからVocal / Instrumental、Mood、音色系特徴量を生成する。通常運用は音楽Rootを再帰走査し、relativePathとfileSize / mtimeNSで新規・更新・削除を差分反映する。library単位のcacheを維持したまま、完了済みJSONだけを`--export-all`でアプリ用の1ファイルへ統合できる。2026-08-29にインスト／OST中心3,837曲と従来3,552曲で分布を評価し、追加calibrationなしでraw headをFIXした。
- **DSP Analyzer複数Root統合**: Root manifestとread-only棚卸し／master exportを追加した。現在のsize・mtimeNS・analysisVersion・設定が一致する成功cacheだけを統合し、relativePath衝突時はfail closedする。Unicode合成形違いの旧Root cacheも再解析せず再利用する。AnalyticsのTrack Features ImportはTrack ID単位mergeとなり、部分Importで別Root分を削除しない。

Beta の操作と制約は [README.md](README.md)、特徴量の contract は [Documentation/TrackFeatureBeta1.md](Documentation/TrackFeatureBeta1.md) と [Documentation/TrackFeatureBeta3.md](Documentation/TrackFeatureBeta3.md) を参照してください。

## テスト・検証の現状

- `MyMusicTests` に音楽特徴量の import / matching / persistence / presentation / Observation / layout を対象とする XCTest がある。
- `analyzer/tests` に discovery、cache、schema、audio analysis、CLI を対象とする Python unittest がある。
- Semantic v2の差分更新testでは、既存曲Skip、新規曲と新規subfolderだけのaudio read、再実行の全Skip、head再評価時の`audioReads=0`、更新・削除・中断再開、20,000行reconciliationを確認している。
- Semantic v2統合testでは、defaultのみ、workspace 1件／複数件、空／破損JSON、relativePath衝突、別libraryの同名file、source manifest、統合件数、fail-closedを確認している。
- 2026-08-27 の特徴量 Beta 3 記録では iPhone 17 / iOS 26.5 Simulator の XCTest 19件と Debug build が成功。
- 2026-08-29 のTrack Adjustments追加後、iPhone 17 / iOS 26.5 SimulatorのXCTest 54件とDebug buildが成功。Analyzer / Semantic unittest 36件もPython 3.12環境で成功。
- 2026-08-30 のジャンルフィルタ非同期化後、連続する設定変更で最新結果だけが反映されるXCTestを追加し、iPhone 17 / iOS 26.5 Simulatorの全XCTestとiOS Device Debug buildが成功。
- 2026-08-30 のホームタイル画像設定追加後、画像名mappingを含むiPhone 17 / iOS 26.5 Simulatorの全XCTestとDebug test buildが成功。
- 2026-08-30 のAlbum Artist / 年代検索追加後、metadata field別検索と複合条件のXCTestを追加し、iPhone 17 / iOS 26.5 Simulatorの全XCTestとDebug buildが成功。
- 2026-08-30 の気分ステーション年代指定追加後、年代候補、年metadata絞り込み、質問遷移、Dynamic Type / Dark Modeを含むiPhone 17 / iOS 26.5 Simulatorの全XCTestとDebug buildが成功。
- 2026-08-30 のプレイリストタグ追加後、旧data decode、正規化、絞り込み、連続保存、import / export、再生中のPlaylist更新とqueue分離を含むiPhone 17 / iOS 26.5 Simulatorの全XCTestとDebug test buildが成功。
- 2026-08-30 のデータ管理拡張後、解析JSONの内容、EQ／ジャンルプリセットのround-trip・同名merge・永続化・不正値拒否を含むiPhone 17 / iOS 26.5 Simulatorの全XCTest 74件とDebug test buildが成功。
- 2026-08-30 の共有Popover修正後、iPhone 17 / iOS 26.5 Simulatorの全XCTestと、iPad Pro 11-inch (M5) / iOS 26.5 Simulatorの共有専用XCTest 2件が成功。
- 2026-08-31 のホーム作業用タイル上限変更後、iPhone 17 / iOS 26.5 Simulatorの全XCTest 79件とDebug buildが成功。
- 2026-08-31 の作業用ライブラリ追加後、専用catalog・項目順のテストを含むiPhone 17 / iOS 26.5 Simulatorの全XCTest 81件とDebug buildが成功。
- 2026-09-01 のPlayback History拡張後、履歴基盤のXCTestを追加し、Debug test buildが成功。Simulator runtime検出がCoreSimulatorの`simdiskimaged`不調で失敗したため、実行XCTestは未完了。
- 2026-09-01 のPlayback History分析CSV運用定義を確定。旧インポートが未対応のため、新規ダウンロードCSVの現行ヘッダ定義を正式運用に採用。
- 2026-09-01 にPlayback HistoryのSQLite正本化、旧JSONのfail-closed migration、永久migration backup、24時間単位の日次JSON snapshotを実装。ユーザー指定によりXcode build / Simulator / 実機検証は後日ローカルMacで実施する。
- 2026-09-01 にPlayback Event Foundationを追加。CloudではSwift parseとdiff静的検査のみ実施し、Xcode build、Simulator XCTest、実機、実データschema migrationはローカルMacで未検証。
- 2026-09-01 にライブラリ整理候補 M2を追加。CloudではSwift parseとdiff静的検査のみ実施し、Xcode build、Simulator XCTest、実機UIはローカルMacで未検証。
- 2026-09-01 にライブラリ整理候補をPlayback Event比率判定へ更新。SQLite schema v3、終了理由、直近20件／最低5件、途中スキップ率50%以上、平均再生率10%以下を対象とし、iPhone 17 / iOS 26.5 Simulatorの全XCTest 120件とDebug buildが成功。
- 2026-09-01 にBehavior Scoring M3を追加。CloudではSwift parse、独立Scoring typecheck、diff静的検査のみ実施し、Xcode build、Simulator XCTest、実機はローカルMacで未検証。Overplayの選曲適用はM4へ保留。
- 2026-09-02 にTrack Preference責務分離後のMood Station描画testへ不足していた`TrackPreferenceStore`のtest fixture注入を追加し、Xcode 26.6、iPhone 17 / iOS 26.5 Simulatorで全XCTest 129件が成功した。
- 2026-09-02 にTrack Fingerprint作成の1日100曲上限を撤廃。件数無制限の処理testは成功し、Debug test buildも成功した。全XCTestでは無関係なTrack Preference永続化testが一度失敗したが、同testの単独再実行は成功した。
- 専用 lint 設定、Swift Package Manager 依存、CI/CD workflow はリポジトリ内で確認できない。

## 既知の制約・未検証

- 特徴量分類とハイライト候補は軽量 heuristic であり、学習済み分類器の確率やサビ判定ではない。
- Semantic v2のVocal / Instrumentalは学習済みbinary headだが、game / OST音色をVocalとする局所的なdomain shiftが残る。Artist / Title / Folderによる補正は行わず、再調整は作品横断の人手ラベル付き評価ができた場合に限定する。
- Semantic単独では新規Trackの`energy` / `tempo`を生成しない。同一relativePathのproduction DSP baselineがある場合だけ値を継承し、2.048秒未満の曲はmodel patchを構成できないため未解析となる。
- schema v1はmusic-root識別fieldを持たない。異なるrootの同一relativePathはmerged JSONで両方保持するが、fileSize / durationまで同じ複製音源はiPhone importでAmbiguousになり得る。source/library対応はimport対象外sidecarに保持する。
- 特徴量 schema v1 の `contentHash` は予約項目で、iPhone での生成・照合は未実装。未照合 / 曖昧項目の修正 UI もない。
- 作業用の20分境界、暗転時間、完全一致 genre 名は固定。通常ライブラリから直接選曲した場合は通常 playerを使い、作業用専用一覧からの選曲時だけ専用 playerを使う。
- crossfade、streaming、server integration、offline download、ReplayGain は未実装。
- 実音源での全再生回帰、実機 background / lock screen / AirPods、特徴量の聴感妥当性は、最新資料上では未確認。
- Playback History SQLite移行とPlayback Event FoundationのXCTestは追加済みだが未実行。Xcode build、Simulator、実機でのmigration／長期運用／ディスク障害検証、Restore UI、月次集約、生event retentionは未検証または将来拡張である。
- 音量ノーマライズのTrue Peak ceilingは元音源＋固定ゲインを対象とし、後段EQによるピーク増加は保証しない。実ライブラリ全曲解析時間と実機聴感は未確認。
- Track Adjustmentsの開始・終了位置、background時の位置保存、手動補正の聴感はSimulatorのunit/integration testまで確認済み。実音源・実機での境界精度、background直後の永続化完了、操作性は未確認。
- 気分ステーションの年代指定はTrackの年metadataを10年単位で扱う。年代指定時、年がない曲は候補外となり、年metadata自体の正確性は音源tagに依存する。
- プレイリストタグは1プレイリスト20件・1タグ40文字までで、絞り込みは一度に1タグ。タグの一括名称変更、色、階層は未実装。
- `MetadataService` は `.m4a` container を AAC と表示し、ALAC の stream-level 判別は未実装。
- Xcode の Deployment Target は 26.5。変更理由は今回確認した資料・履歴だけでは不明であり、明示依頼なしに変更しない。
- 既存ライブラリキャッシュはそのままdecodeできる。Album Artistを旧キャッシュへ補完するには一度「再スキャン」が必要で、metadata revisionにより旧Trackだけを一度再抽出する。

## 次のアクション

1. 新しい Beta は一機能ずつ実装し、対象 test と Simulator build を成功させる。
2. Semantic v2はraw head仕様を維持する。変更が必要になった場合は、作品横断の人手ラベル付き評価で現行仕様との回帰を測る。
3. 実機確認が必要なリリース候補では、再生操作、background、lock screen / Control Center / AirPods、データ削除の非破壊性を検証する。
4. CI / lint を導入する場合は、既存環境に存在しないことを前提に別タスクとして設計判断を記録する。
