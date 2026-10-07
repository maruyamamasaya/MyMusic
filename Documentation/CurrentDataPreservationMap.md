# 現行データ地図とバックアップ境界

調査日: 2026-10-07、更新: 2026-10-08。MyMusic HEAD `e15a26e`、HomeStereo HEAD `347a1ac` と作業ツリーのコードを対象にした静的調査。初回調査に加え、下記のbackup保全Beta実装と隔離検証結果を反映した。

共通契約は両Gitのrevision 3を`cmp`で照合し、本文一致を確認した。契約の保全要件は、実装・復元保証の達成を意味しない。実端末の保存内容、実際に利用されているバックアップの日時・完全性、OS全体のバックアップは調査していない。

## 結論と先に確認すべき点

1. MyMusic外部backupは選定ファイルsnapshot。HomeStereoは新JSON v2でSQLite全体・特徴量・原本・選定設定のsnapshotを保持し次回起動で復元する。旧JSON v1は従来の選定データmerge。
2. MyMusicの履歴復元には重大な起動経路の不整合がある。バックアップ対象に履歴DBはあるが移行状態sidecarはない。復元時にApplication Support/MyMusic全体を交換するため、既存のsidecarも残らない。起動後のPersistence初期化はsidecarがverifiedでない場合に移行処理へ進み、旧JSONもなければDBを空で再作成する。現行生成バックアップは旧JSONも含めないため、復元DBを失う経路がコード上成立する。本番Service群を直接compileした隔離実行で再現した。DB直読では履歴Modelが一致し、復元後のPlaybackHistoryPersistenceService.loadで空になる。Track ID/Calendarの補助定義のみをfixtureで代替した。実端末での復元はしていない。ユーザー指定により修正は保留。
3. HomeStereo旧JSON v1は詳細Events/評価/link/tags/featuresを含まない。新v2は既存SQLiteと特徴量JSONをそのまま保存して不足を補った。ただし音源/Analyzer資産/全設定のbackupではない。
4. 音源そのものとAnalyzerの資産は両アプリのバックアップから独立している。

## 曲を結ぶ識別子

MyMusicの曲別ユーザーデータは原則Track UUIDを参照する。`TrackIdentityService.Record`はUUIDとrelativePath、resourceIdentifier、audioFingerprint、fileSize、modificationDate、duration、firstSeenAtを保持する。パス変更後のUUID維持には照合材料と曖昧性の確認が必要であり、再scanだけで必ず同じUUIDになるとは扱わない。

HomeStereoはローカルTrack UUIDを主キーに持ち、`mymusic_track_links`でMyMusic UUIDへ対応する。両IDを同じものと仮定しない。linkはlocal主キー／MyMusic ID一意で、relativePath・size・duration・fingerprint・照合方法・在籍状態等を含む。Library snapshotからの欠落はlinkの在籍外であり、履歴削除の指示ではない。

fingerprint、feature sourceのcontentHash、Import原本のSHA-256、Analyzer profile signatureは用途が異なる。原本hashを曲IDとして使わない。embeddingも曲UUIDの代用品ではない。

## MyMusicの保存と外部バックアップ

保存先の基準はApplication Support/MyMusic。表の「含む」は`ExternalBackupService.paths/settingsKeys`への登録を示す。対象が存在しない場合はコピーされない。全項目の意味・参照関係を復元試験済みという意味ではない。

| 対象 | 現行正本／保存 | 紐付けと内容 | 外部バックアップ |
| --- | --- | --- | --- |
| 音源 | 利用者のFiles/iCloud Drive等 | 実ファイル。フォルダアクセス権が必要 | 含まない |
| フォルダ登録 | UserDefaults `musicLibraryFolderBookmarks`（旧単数key互換） | security-scoped bookmark | 含まない。再選択が必要になる |
| Track Identity／fingerprint | `track-identities.json` | Track UUIDと上記Record。fingerprint生成と移動照合 | 含む |
| Library metadata | `library-index.json` cache v2 | folderごとのTrack。Album/Artist/Genre/Composer等は復元時に再構築 | 含まない。再scanとIdentity再接続の確認が必要 |
| Playlist | `playlists.json` | Playlist UUID、順序付きTrack UUID、日時、description、artworkIdentifier、searchDefinition、kind、tags | JSONは含む。artwork参照先の実体は別確認が必要 |
| 曲のお気に入り／Good・Bad | `track-preferences.json` schemaVersion 2 | Track UUID、favorite Bool、playbackPreference -10…10 | 含む |
| Album/Artistのお気に入り | `library-favorites.json` | Album/Artist UUID集合。曲Favoriteとは別 | 含む。再構築後の分類IDとの一致は未検証 |
| 再生履歴 | `playback-history.sqlite3` schema v4 | Track UUID、累計、日別、入口、実聴時間、skip等とString event IDの詳細Events | DBは含む。起動時正本判定に問題あり |
| 履歴移行状態／旧データ | `playback-history-migration-state.json`、旧`playback-history.json`、`Backups/Migration/…` | sidecarとDB内metadataのverifiedを確認して正本を選ぶ。旧JSON移行は全Model read-back比較 | 含まない |
| 内部履歴backup | `Backups`配下 | load時に日次JSON、7世代。migration原本は別保持 | 含まない。内部保存は端末故障対策とは別 |
| あとで聴く | `listen-later.json` | 曲参照と登録情報 | 含む |
| 特徴量／自動音量補正 | `track-features.json` version 1 | Track UUID、sourceIdentity、analysisVersion、日時、score、LUFS/True Peak/gain、Import report | 含む。embedding本体は含まれていない |
| 曲別調整 | `TrackPlaybackAdjustments/<shard>/<UUID>.json` | 位置、開始/終了位置、手動音量補正、updatedAt | フォルダを含む |
| Highlight | `highlights.json` | 保存された候補・選曲情報 | 含む。復元後参照の完全性は未検証 |
| Playback Events受信原本 | `PlaybackEventImportOriginals/<hash>.json` | 確定時に期間filter前の全bytesを保存。未照合／期間外も残る | 含まない |
| Playlist Import退避 | `PlaylistImportArchive/received-<hash>.json`、`before-<hash>.json` | 受信bytesと更新前全Playlist。対応関係を示す耐久recordはない | 含まない |
| EQ／表示／ジャンル設定等 | UserDefaultsの選定keys | 下記に列挙 | 選定keysのみ含む |

Good/Badは独立した押下回数や操作ログではなく、+1/-1して上限・下限に収める現在の評価値。旧PlaybackHistoryにもfavorite/preference fieldは残るが、TrackPreferenceStoreはv2ファイルを正本とし、欠落時だけ旧履歴から移行する。復元検証では旧fieldだけを比較しない。

バックアップされる設定keysは`equalizerSettings`、`customEqualizerPresets`、`playbackTransitionSettings`、`appearance.theme`、`appearance.visualWorldStyle`、`volumeNormalizationEnabled`、`sourceSampleRateMatchingEnabled`、`library.disabledGenreNames`、`library.genreDisplayPresets`、`library.songsDisplayMode`、`library.albumsDisplayMode`、`library.artistsDisplayMode`。UserDefaults全体ではない。ジャンル名は音源metadata／cache由来で、表示除外とプリセットは別設定である。

## HomeStereoの保存と旧JSON v1の範囲

`SQLiteLibraryRepository`の既定保存先はApplication Support/HomeStereo/Library.sqlite3、schema v14。特徴量は同rootの別JSON。実際のsandbox container／カスタム保存先の状態は未確認。

| 対象 | 現行保存 | 紐付けと内容 | JSONバックアップv1 |
| --- | --- | --- | --- |
| 音源／フォルダ／Library | `library_folders`、`tracks`、`library_metadata` | folder UUID、bookmark、local Track UUID、metadata、audio_fingerprint | 音源・登録・index・fingerprintは含まない。使用曲の照合用参照だけ含む |
| MyMusic ID対応 | `mymusic_track_links` | local UUIDとMyMusic UUIDの対応 | 含まない |
| Playlist | `playlists`、`playlist_items` | local Playlist UUID、mymusic_playlist_id、曲順、kind、tags | ID・名称・日時・kind・順序付き曲参照は含む。tags／mymusic_playlist_id／item IDは含まない |
| 曲Favorite | `favorites` | local Track UUID、addedAt | 含む |
| Good/Bad | `track_preferences` | local Track UUID、playback_preference、updatedAt | 含まない |
| 受信Preference／送信世代 | `mymusic_preferences`、`mymusic_preference_export_changes` | 受信値、MyMusic ID、exportedAt／change token | 含まない |
| 簡易再生履歴 | `playback_events` | UUID event ID、曲、startedAt、playedSeconds、outcome | 含む |
| 詳細再生履歴 | `mymusic_playback_events` | String event ID、local/MyMusic曲ID、実聴秒、duration、開始/終了、完走/skip、入口、platform等。受信とローカル詳細記録 | 含まない。簡易履歴と同じ表ではない |
| Library再生回数snapshot | `mymusic_library_play_counts` | MyMusic UUID、playCount、最終再生、importedAt | 含まない |
| 再生集計 | `playback_track_summaries`、`playback_daily_summaries`、`playback_source_summaries` | 曲／日／入口別集計 | 含まない。旧累計と詳細Eventsを単純加算しない |
| ジャンルプリセット | `genre_display_presets` | UUID、名称、対象ジャンル、順番、未分類設定 | 含まない |
| Queue | `playback_queue`、`queue_state` | 曲順、位置、repeat/shuffle | 含まない |
| 特徴量／自動音量補正 | `track-features.json` archive version 1 | Feature record UUID、optional MyMusic/local曲ID、sourceIdentity、解析version/profile/由来、score、音量 | 含まない。別の特徴量JSON Exportあり |
| 解析途中記録 | `AnalysisRuns/<UUID>/` | request/status/results、completed.jsonl。起動後の回収経路あり | 含まない |
| Playlist受信退避 | DB隣接`PlaylistImportArchive` | 原本と更新前snapshot | 含まない |
| アプリ設定 | UserDefaults等 | 自動更新、音量補正ON/OFF、表示等 | automaticLibraryUpdatesのみ含む |

`BackupStore.makeDocument`はListeningStoreの簡易eventsをExportする。`HomeStereoBackup`には詳細履歴・特徴量等のfieldがない。`BackupStore.resolve`はID→相対path→size/duration条件→metadataで照合し、未解決・曖昧は元IDの参照を残す。後日の再接続が自動完了するとは確認していない。

`mergeBackup`はtransactionでPlaylistを保存し、Favorite／簡易eventをINSERT OR IGNOREする。JSONにないデータの全削除はしないが、同一Playlist IDは更新対象になる。BackupPlaylist v1はtagsを持たない。2026-10-08にresolveで既存tags/連携IDを引き継ぐ修正を行い、回帰testを追加した。受信原本の退避を行うMyMusic Playlist Importとは別の経路である。

## Analyzerとembeddingの境界

MyMusicのSemantic CLIは指定cache directoryに`index.sqlite3`、`embedding-profile.json`、heads profile、`embeddings/<profile>/<shard>/<identity>.npz`等を保存する。SQLiteにrelative_path、identity、mtimeNS、profile、NPZ path/SHA、head結果を持ち、NPZとprofile・元音源の対応を確認する。アプリに渡す最終JSONは分類score等であり、embedding本体を含めない。

HomeStereoの現行Analyzer workerはsupport配下`analysis.sqlite3`にlocal Track ID＋音源path/size/mtime/profile由来signatureでsemantic／loudness結果と日時を保存する。embeddingは推論中に使用し、現行workerではNPZとして永続保存しない。MyMusic側の永続embedding cacheと同一仕様ではない。

両Analyzerのcache、profile、model/head資産、最終Export JSON、元音源はアプリbackupから独立した保全対象。指定先・実在資産・バックアップ運用は未調査。派生データでも「再生成可能」を「失ってよい」と同義にしない。再生成時間・モデル入手性・再現性を別に確認する。

## 交換JSONは完全backupではない

既存wireを維持する。Library v1は照合snapshot、Preferences schema v2は記載曲merge、Events schema v1はID単位append、Playlists v1は順序付き参照。Library Exportに再生回数があることは、全詳細履歴を戻せることを意味しない。

Playlist wireはMyMusicローカルdescription/searchDefinition/artwork等を運ばない。特徴量snapshotとAnalyzer入力形式もローカルarchiveとは別である。同一event ID異内容は現行では内容比較・双方の競合保管が未完成。再Import冪等性と競合保全を区別する。

## バックアップ処理の保証と限界

MyMusic: formatVersion 1／manifest schemaVersion 2、v1も読める。staging作成・DB backup APIによるWAL snapshot・hash/size/JSON/UUID/DB検証後、latest/previousの2世代へ回転する。UIはHistory、Preference、Playlist、ListenLater、Favoriteのpending saveを待つが、全Storeを同時点で凍結するtransactionではない。

復元はpendingへ準備し、次回起動時にroot交換。成功時に旧rootのrollback directoryを削除するため、backup非対象ファイルが旧rootから残る保証はない。DB以外のJSON検証はJSON構文・ID等であり、すべてのModelの意味と参照先を検証する処理ではない。起動時の復元エラーは`try?`で扱われる。履歴sidecar不足は前述の通り。

HomeStereo: v1は選定JSONのvalidation/merge、v2はDB全体と選定files/settingsのsnapshot復元である。v2も音源/Analyzer資産/すべての設定を単独で保全するものではない。

## 既存試験と次の検証

初回は静的調査のみ。2026-10-08の追加検証は末尾に記録する。

- MyMusic `ExternalBackupServiceTests`: manifest、checksum、v1互換、設定round-trip、2世代、WAL、event identity/platform、破損拒否等。event復元試験はSQLiteRepositoryを直接読み、PlaybackHistoryPersistenceServiceの起動移行経路を通さない。
- HomeStereo `BackupContractTests`: v1 fixture往復、kind互換、文書拒否、曲照合、merge非削除・rollback等。現行backup DTOにないデータの全復元は証明しない。
- MyMusic `TrackIdentityMoveTests`／`TrackFingerprintBuildTests`、Preference／Feature／Adjustment／Playlist tests、HomeStereo MyMusicPersistence／Feature／Playlist testsは個別経路の回帰資産。実端末間の完全復元の代用にはしない。

2026-10-08に(1) MyMusic外部backup→pending適用→本番Persistence初期化の欠陥再現、(2) HomeStereo v2復元とv1のtags/連携ID保持を隔離検証した。(3) 全資産の実端末/大容量復元と除外範囲の追加検証は残る。比較対象はID集合、Playlist曲順/tags/種別、Favorite/評価、event内容/累計、音量/feature source/profile、Identity/fingerprint/linkである。件数だけの一致は完了条件にしない。

## 根拠となるコード入口

MyMusic:

- `MyMusic/Services/ExternalBackupService.swift`、`MyMusic/Views/Settings/ExternalBackupView.swift`、`MyMusic/App/MyMusicApp.swift`
- `MyMusic/Services/PlaybackHistoryPersistenceService.swift`、`PlaybackHistoryMigrationService.swift`、`PlaybackHistorySQLiteRepository.swift`、`PlaybackHistoryBackupService.swift`
- `MyMusic/Services/TrackIdentityService.swift`、`FileImportService.swift`、`LibraryPersistenceService.swift`
- `MyMusic/Stores/TrackPreferenceStore.swift`、各PersistenceService、`MyMusic/Models/Playlist.swift`、`TrackFeature.swift`、`TrackPlaybackAdjustment.swift`
- `analyzer/mymusic_semantic/cache.py`、`cli.py`、`SEMANTIC_README.md`
- ADR-0003/0004/0005/0008。初期ADRより現行コードが拡張されている箇所はコードを確認した。

HomeStereo（別Git、初回はread-only、今回backup範囲を変更）:

- `Sources/HomeStereoAppCore/LibraryRepository.swift`、`BackupContract.swift`、`MyMusicPersistenceModels.swift`、`MyMusicPersistenceService.swift`、`TrackFeatures.swift`
- `Sources/HomeStereoDLNAAppCore/BackupStore.swift`、`ListeningStore.swift`、`TrackFeatureStore.swift`、`FeatureAnalysisService.swift`
- `analyzer/worker.py`、`inference.py`、`README.md`、`docs/json-backup.md`

全UserDefaults key、全Artwork実体、Watch設定、HiRes固有設定、Local/Static Analyticsの保存とexport、実端末の独自残存ファイルは追加棚卸しが必要。本資料を全保存資産の網羅保証とは扱わない。

## 2026-10-08の変更と隔離復元検証

HomeStereo JSON v2はLibrary.sqlite3の全テーブル、track-features.json、PlaylistImportArchive、AnalysisRuns、4種類の選定settingsをstate payloadへ保存する。DB schema v14とMyMusic wireは維持。各fileはbase64とSHA-256で保持し、DB integrity/schema/foreign keysとFeature modelを確認する。旧v1のfixture互換を維持し、旧形式の既存Playlist tags/連携ID消失を防いだ。

v2復元は確認後のpending準備と次回起動のroot交換。現在rootはHomeStereo-before-restore-UUIDへ退避して保持する。live DBへ取り込まずIDを再採番しない。新形式は旧アプリでは読めない。別Macのbookmark権限、音源再接続、大容量のメモリ/容量は未検証。詳細の正本はHomeStereo `docs/json-backup.md`。

StateBackupTestsはtemp保存先でJSON encode/decode、pending、startup apply、SQLite reopenを通した。代表10テーブルのfield一致、曲順/重複参照/item ID/tags、評価、詳細event、link、集計、fingerprint、特徴量/音量情報、原本bytes、settingsと旧root退避を確認した。corrupt DB/path traversal拒否も確認。これは全種類の実ユーザーデータfixtureを試したという意味ではない。

MyMusic semantic cacheには`python -m mymusic_semantic.backup create/restore`を追加。cache lock、SQLite backup、ZIP manifest/hash、ready embedding参照検証、新規workspaceだけへのrestoreを行う。NPZやアプリ特徴量の構造は変更しない。複数workspaceは各々明示backupする。cache外のmodels/音源は別対象。詳細はanalyzer/SEMANTIC_README.md。

MyMusic履歴復元の欠陥は隔離実行で再現済み。修正保留のため、MyMusic外部backupの履歴を本番起動まで戻せる保証は依然成立していない。Import原本包含・取り込み履歴・再適用UIのMyMusic側実装も今回は進めていない。

最終検証: HomeStereo `./scripts/verify.sh`でXCTest 139件（3 skip）、Swift Testing 85件、macOS Debug BUILD SUCCEEDED。MyMusic Analyzer unittest 40件成功。iOS/Simulator test・実端末デプロイは未実施。
