---
status: active
updated: 2026-09-01
---

# MyMusic Architecture

## システム境界と技術スタック

MyMusic は Swift / SwiftUI / Observation で構築した iPhone 中心の単一アプリです。音声には AVFoundation、lock screen と remote control には MediaPlayer、Files 選択には UniformTypeIdentifiers を含む Apple 標準 framework を使います。外部 Swift package は確認できません。

Mac 側の補助的な Python Analyzer は音源をオフライン解析し、versioned JSON を生成します。iPhone アプリとは network / server ではなく、Files 経由の JSON import で接続します。

## レイヤーと依存方向

```text
SwiftUI View
    ↓ user intent / observed state
@Observable Store (@MainActor)
    ↓ operation / state coordination
Service (actor, class, or value service)
    ↓
Model / AVFoundation / MediaPlayer / FileManager / UserDefaults
```

- **View (`MyMusic/Views`)**: 表示、navigation、sheet、ユーザー入力。Service や AVFoundation を直接操作しない。
- **Store (`MyMusic/Stores`)**: UI state と lifecycle、Service 呼び出し、Model の集合を調整する。App root から SwiftUI environment へ注入する。
- **Service (`MyMusic/Services`)**: playback、scan / metadata、検索、永続化、import / export、analytics 等の処理を担う。
- **Model (`MyMusic/Models`)**: Track、Album、Playlist、PlaybackHistory、TrackFeature 等の data contract。UI logic を持たない。

この境界を採用する判断は [ADR-0001](decisions/ADR-0001-view-store-service-boundaries.md) を参照してください。

## Composition と画面構成

`MyMusicApp` が `AudioPlayerService` を一つ生成し、同じ instance を `PlayerStore`、`SettingsStore` に接続します。`TrackPlaybackAdjustmentStore`もPlayerStoreとSwiftUI environmentで共有します。各 Store は SwiftUI environment に注入されます。`RootView` は Home / Library / Playlist / Search / Highlight の5 tab、mini player、通常 / 作業用 Now Playing sheet、root-level error alert、初期 load task、background移行時の再生位置flushを管理します。

ファイル共有は各画面の`ShareLink`へ委ねず、共通の`ActivityShareSheet`が一時ファイル作成と`UIActivityViewController` presentationを担当する。共有シートは画面rootの安定したpresentation stateから開き、`popoverPresentationController`が存在する場合は生成時・更新時ともsource view / rectを設定するため、iPhoneのsheet適応とiPadのPopover適応を同じ経路で扱う。

主な View 群は責務別に `Home`、`Library`、`Player`、`Playlist`、`Search`、`Settings`、`Highlight`、`Components` に分かれます。

Homeのライブラリ／アクティビティタイルは、`MyMusic/Resources/HomeTileImages/`に所定のベース名で置かれたローカル画像をbuild resourceとして任意に読み込む。対象画像がない、またはdecodeできない場合は、`HomeItemTile`が従来のdestination別グラデーションをそのまま表示する。ローカル画像は永続化データではなく、build時だけアプリbundleへ取り込まれる任意assetである。

HomeとPlaylistで共有するステーション入口カードは、`MyMusic/Resources/HomeTileImages/station-background.*`を同じく任意のbuild resourceとして読み込む。画像がない、またはdecodeできない場合は、`StationEntryView`が従来のグラデーションを表示する。

Homeの「作業用サイズ再生」は即時再生ではなく、作業用対象を曲名、アルバム、アーティスト、アルバムアーティスト、プレイリスト別に閲覧する入口とする。各一覧は対象内検索を持ち、曲の再生は`PlayerStore`へ`.workSize` presentationを指定して専用playerへ接続する。

## 主要データフロー

### Library import

```text
Library View → LibraryStore → FileImportService
                           → MusicLibraryService → MetadataService / ArtworkService
                           → LibraryPersistenceService / TrackIdentityService
```

`LibraryStore`は表示対象ライブラリを反映するとき、`WorkLibraryCatalogService`で20分以上または「作業用BGM」の曲だけを抽出し、作業用のAlbum / Artist / Album Artist集合を`WorkLibraryCatalog`として同時に更新する。`WorkLibraryView`はこの派生catalogだけを読み、通常曲を専用一覧へ混在させない。

ユーザーが Files / iCloud Drive の folder を選択し、security-scoped bookmark を保存します。scan は対応音声 extension を列挙して metadata と artwork を抽出し、安定 Track ID と folder ごとの library cache を構築します。

ジャンル表示設定の適用時は、`LibraryStore`が全曲と無効ジャンルのsnapshotを`GenreLibraryFilterService` actorへ渡す。actorが表示曲の抽出とAlbum / Artist / Genre / Composerの再構築をutility priorityで実行し、`LibraryStore`は完了した最新requestの結果だけをMainActor上の表示stateへ反映する。初期loadや再scanは従来どおり同期的に一貫したlibrary snapshotを確定してから公開する。

「作業用BGM」は通常曲と作業用再生を分離する分類マーカーでもあるため、ライブラリに存在する場合はジャンル表示フィルターの固定ON項目とする。`LibraryStore`が保存済み設定、個別変更、全解除、プリセット適用の各入口で無効化を拒否し、UIは存在を示したまま解除操作を無効にする。

### Playback

```text
PlaybackControlsView / playable Views
  → PlayerStore (queue, repeat, shuffle, presentation state)
  → AudioPlayerService
  → AVAudioEngine → transition mixer → normalization gain → AVAudioUnitEQ → output
```

`PlayerStore` は `NowPlayingService` と `RemoteCommandService` を通じて MediaPlayer と同期し、`PlaybackHistoryStore` に再生実績を伝えます。再生セッション中の総再生時間、開始日時、開始文脈はPlayerStore内の軽量な一時状態として保持し、曲変更・停止・自然終了時に実聴秒数、完走率、skip／完走を単一の`PlaybackEvent`へ確定します。同じセッションの終了通知は一度だけ確定し、lifecycle境界は途中時間をflushするだけです。`AudioPlayerService` が security-scoped file access、AVAudioSession、seek、fade、再生完了 event を所有します。Highlight は `HighlightPlayerStore` が候補・区間を調整しますが、実再生は同じ `PlayerStore` / `AudioPlayerService` を通ります。

通常再生開始前にPlayerStoreはStable Track IDで`TrackPlaybackAdjustmentStore`を遅延loadし、有効な`customStartPosition`を開始時刻へ反映する。`AudioPlayerService`から0.5秒間隔で届く再生時刻eventを利用し、7秒間隔とpause／曲変更／backgroundで前回位置を保存する。有効な`customEndPosition`到達時は音声を停止して既存の曲終了・repeat・次曲経路へ合流する。Highlight区間には曲別の開始／終了位置を適用しない。

音量ノーマライズはTrack IDで`TrackFeatureStore`の固定dB値と曲別の手動微調整を解決し、合計を±4 dBへ制限した後、True Peakが-1 dBTPを超えない上限を適用する。曲切替の旧render pathを消音後、専用`AVAudioUnitEQ.globalGain`段へ1曲につき一度適用する。OFFまたは0 dB時はこの段をbypassし、fade mixerとユーザーEQから分離する。

### Music feature analysis / import

```text
local music files → Python Analyzer → schemaVersion 1 JSON
  → TrackFeatureImportService → safe matching against Track
  → TrackFeatureStore → TrackFeaturePersistenceService
  → AudioInformationView / TrackFeatureDetailView
```

Analyzer は librosa / Mutagen / SoundFile と SQLite cache を利用する逐次 CLI です。標準 contract は `Documentation/track-feature-schema-v1.json`。iPhone では音響解析や全曲 hash 計算をせず、特徴量は Track 本体と分離します。採用理由は [ADR-0003](decisions/ADR-0003-mac-feature-analyzer.md) を参照してください。

音量解析は同じCLIからFFmpeg `loudnorm`を音声出力なしで全曲に実行し、`integratedLUFS`、`truePeakDBTP`、`normalizationGainDB`を任意fieldとして既存JSONへ追加する。ラウドネスcacheはDSP cache signatureと分離し、旧DSP cacheへ音量値だけを追解析できる。iPhone importは3項目欠落を0 dBとして扱い、analysisVersionの異なるSemantic特徴量と音量項目を相互に失わないようマージする。

Semantic v2はproduction DSP Analyzerと書込先を分離する。

```text
music root recursive scan
  → NFC relativePath + fileSize + mtimeNS reconciliation
  → changed tracks only: audio decode → Discogs EffNet embedding
  → all current embeddings: versioned semantic heads
  → schemaVersion 1 / analysisVersion 2 JSON (atomic replace)
```

`analyzer/semantic.py --update`はRootを毎回再帰走査し、既存Embeddingをchecksum付きで再利用する。新規・更新Trackだけが音源を読み、削除TrackはSQLiteの`present=0`として履歴とNPZを保持しながらexport対象から外す。Track identityは曲名やfuzzy matchingではなくNFC正規化した`relativePath`を主キーとする。Embedding profileとhead profileを独立versioningするため、head変更時は音源を読まず全曲を再評価できる。1曲ごとのNPZ、shard配置、逐次処理、checkpointにより20,000曲規模とCtrl+C後の再開を想定する。

通常cacheは`analyzer/semantic_cache`、別Rootの独立解析はRoot identityごとの`analyzer/semantic_workspaces/library-<ID>`を使う。いずれも本番`analyzer/cache/analysis.sqlite3`、本番`music_features.json`、PoC dataへ書き込まない。詳細とFIX済みhead仕様は[Semantic運用](analyzer/SEMANTIC_README.md)と[最終特徴量評価](analyzer/SEMANTIC_CALIBRATION_REPORT.md)を参照する。

アプリ利用時は解析cacheを統合せず、`semantic.py --export-all`が各workspaceの完了済みschema v1 JSONだけを読み、`analyzer/output/music_features_semantic_v2_merged.json`へatomic exportする。異なるmusic-rootはrootから導出した`libraryId`で内部的に分離し、同じrelativePathも別entryとして保持する。MyMusic schemaは追加fieldを許可しないため、libraryIdとoutput indexの対応はimport対象外の`.sources.json` sidecarへ保存する。broken sourceがあればfail closedし、空／未完了workspaceだけを理由付きでskipする。解析成功と全library exportの失敗範囲を分離するため、`--update`から自動実行しない。

### Search, favorites, playlists, history

- `TrackSearchService` は text field / match mode / AND・OR / 属性条件を組み合わせ、保存検索 playlist の定義にも使われる。Artist条件はTrack ArtistとAlbum Artistの両方を対象にし、Album Artistと年はTrackの各metadataを直接対象にする専用の検索field / 条件も持つ。検索画面は`TrackSearchStore`が225ms debounceとTask cancellationを管理し、専用actorで検索してMainActorには結果だけを反映する。保存検索playlistの明示同期も同じactorを使う。
- `StationStore` は通常再生対象かつ特徴量を持つTrackから`StationCandidate`を構成する。`MoodStationService`は気分・音の特徴量scoreに加え、任意指定された10年単位の年代で候補を先に絞り、近さとartist分散から一時queueを生成する。年代候補は対象Trackの有効な年metadataから降順で導出し、候補がなければ年代質問を省略する。年代無指定では年の有無にかかわらず従来どおり選曲する。
- `FavoriteStore` と `PlaylistStore` は専用 persistence service を介し、Track ID で library の曲を参照する。Playlist は regular / work の種別互換性と、正規化・重複排除された複数の表示用tagを持つ。tag編集はTrack ID配列に触れず、再生開始時にPlayerStoreへ渡されたqueue snapshotから独立する。Playlist保存Taskは先行保存の完了後に次のsnapshotを保存し、高速な連続更新でも古いsnapshotが後勝ちしない。
- `PlaybackHistoryStore` は再生回数、rating、正式なPlayback Event、初回／最終再生日時、総再生時間、スキップ／完走、連続再生、リピート再生、manual / automatic、入口別、日別集計を保存する。Playback EventはTrack ID、開始／終了日時、実聴秒数、完走率、skip／完走、開始種別／入口を持ち、early skipは`wasSkipped && listenedSeconds <= 30`である。日別集計にも完走、skip、early skip件数を保持する。分析画面から1曲の履歴をリセットする場合はeventと日別集計を含む対象Trackの再生事実だけを消去し、お気に入り、rating、飽き度は保持する。`AnalyticsService` と `MusicHistory*Service` は現在 library と履歴から表示用 snapshot を導出する。
- 永続化は`PlaybackHistoryPersistenceService` actorから`PlaybackHistorySQLiteRepository`を呼び、`Application Support/MyMusic/playback-history.sqlite3`を正本とする。schema version 2では予約済みevent列を正式利用しevent IDと完走flagを追加する。通常変更は1曲snapshotを1 transactionで渡し、`playback_events`はevent IDによる`INSERT OR IGNORE`でappendし、track／日別／入口別はupsertする。空event snapshotだけが曲別resetの削除境界となる。初回は`PlaybackHistoryMigrationService`が旧JSONを上書きなしの永久backupへcopyし、transaction import後の全Model一致でのみDB metadataとDB外stateを`verified`にする。`PlaybackHistoryBackupService`は起動load時に24時間条件の日次JSON snapshot（7世代）を作る。
- `AnalyticsService` のCSV exportは、運用上の共通契約としてヘッダを `種類,日時,曲名,アーティスト,再生回数,値,詳細` とし、分析データを以下の行種別で出力する。
- `楽曲別再生回数`, `楽曲別再生行動`, `楽曲別再生入口`, `再生傾向評価` はそれぞれTrack別に追加行する。
- `再生履歴` は再生イベントの時系列（日別にグループ化済み）を出力し、`集計` は全体件数（総再生、手動、自動、お気に入り、プレイリスト）を追加する。
- `楽曲別再生行動` は `manual:<数>, automatic:<数>, 7日:<数>, 30日:<数>, 初回:<日時>, 最終:<日時>` を `詳細` 列へ格納し、`楽曲別再生入口` は `入口:回数` をスペース区切りで `詳細` 列へ格納する。
- CSVインポート経路は現時点で未実装のため、上記CSVが現行正規フォーマットとする。
- `MusicDataImportService` / `MusicDataExportService` は playlist、library、history、解析snapshot、設定の JSON / Markdown 等の入出力境界を担う。Playlist tagはversion 1文書の後方互換な追加fieldとして扱い、field欠落時は空tagとする。
- `TrackFeatureStore`は保存済み特徴量をTrack ID順のsnapshotとして提供し、`MusicDataExportService`が全特徴量JSONと、完全なLUFS / True Peak / gainを持つ曲だけの音量ノーマライズJSONへ変換する。これは音源を含まない確認・退避用出力であり、Analyzer schema v1の再Import contractではない。
- EQ文書は現在の`EqualizerSettings`とcustom preset、ジャンル文書は順序付き`GenreDisplayPreset`を、それぞれ`kind`とversionを持つ別JSONとして扱う。`MusicSettingsImportService`が種類、version、有限値、EQの範囲・バンド数、重複名／IDをStore変更前に検証する。Storeは同名presetを更新し新規presetを追加してUserDefaultsへ保存するため、対象外の既存presetは削除しない。

## 永続化

server / database migration はありません。端末内の file と UserDefaults が保存境界です。

| データ | 主な所有者 | 保存形態 / 場所 |
| --- | --- | --- |
| Library folder access | `FileImportService` | UserDefaults の security-scoped bookmark |
| Folder scan cache | `LibraryPersistenceService` | Application Support 内 JSON |
| Stable Track identity | `TrackIdentityService` | Application Support 内 JSON |
| Artwork / highlight | `ArtworkService` / `HighlightRepository` | Caches 内 file / JSON |
| Favorites / playlists / playback history | 各 PersistenceService | JSON / Application Support `MyMusic/playback-history.sqlite3` |
| Track features | `TrackFeaturePersistenceService` | Application Support `MyMusic/track-features.json` |
| Track playback adjustments | `TrackPlaybackAdjustmentPersistenceService` | Application Support `MyMusic/TrackPlaybackAdjustments/<ID先頭2文字>/<Stable Track ID>.json` |
| EQ / transition / volume normalization / display preferences | `SettingsStore` 等 | UserDefaults |
| Analyzer progress | Python analyzer | `analyzer/cache/analysis.sqlite3`（DSP + 独立loudness table、Git ignore） |
| Analyzer export | Python analyzer | `analyzer/output/music_features.json`（Git ignore） |
| Semantic v2 progress / embeddings | Python semantic analyzer | `analyzer/semantic_cache/index.sqlite3` / sharded NPZ（Git ignore） |
| Semantic v2 isolated workspaces | Python semantic analyzer | `analyzer/semantic_workspaces/library-<ID>`（Git ignore） |
| Semantic v2 export | Python semantic analyzer | cache内 `output/music_features_semantic_v2.json`（Git ignore） |
| Semantic v2 merged app export | Python semantic exporter | `analyzer/output/music_features_semantic_v2_merged.json` + source sidecar（Git ignore） |

永続化 model を変える場合は既存 decode compatibility と非破壊性を確認します。Track ID を参照するデータが多いため、identity 変更は横断的な migration なしに行いません。

TrackのAlbum Artistはoptionalで、旧cacheのdecodeを維持する。metadata revisionがない旧Trackは次回の手動再スキャン時に一度だけAVFoundation metadataを再抽出する。アルバムは`albumTitle + (albumArtistName ?? artistName)`で導出し、Artist一覧自体はTrack Artistから導出する。

曲別調整は解析JSONへ書き戻さず、端末ユーザー固有データとしてStable Track ID単位のsharded JSONへ保存する。全曲DictionaryをUserDefaultsへ載せず、アクセスした曲だけを遅延loadし、頻繁な位置更新でも他曲の設定ファイルを書き直さない。field欠落は`TrackPlaybackAdjustment`の安全な初期値でdecodeする。

## Build, tests, delivery

- Xcode project / scheme: `MyMusic.xcodeproj` / `MyMusic`
- App と `MyMusicTests` は Xcode File System Synchronized Groups を使用。
- iOS Simulator Debug build は `xcodebuild ... CODE_SIGNING_ALLOWED=NO build`。
- Swift test は `MyMusicTests`、Analyzer test は Python `unittest`。
- CI/CD、専用 lint、API、認証、network infrastructure、DB schema / migration は現時点で存在しない。
- 物理端末への build / install / launch は `scripts/check-iphone.sh` と `scripts/deploy-iphone.sh` を明示依頼時だけ使用する。

## 詳細資料

- 利用者向け概要と Beta: [README.md](README.md)
- Track Feature import contract: [Documentation/TrackFeatureBeta1.md](Documentation/TrackFeatureBeta1.md)
- Track Feature 表示と検証: [Documentation/TrackFeatureBeta3.md](Documentation/TrackFeatureBeta3.md)
- JSON Schema / example: [`Documentation/track-feature-schema-v1.json`](Documentation/track-feature-schema-v1.json), [`Documentation/track-feature-v1.example.json`](Documentation/track-feature-v1.example.json)
- Analyzer 運用: [analyzer/README.md](analyzer/README.md)
- Semantic v2 運用・評価: [analyzer/SEMANTIC_README.md](analyzer/SEMANTIC_README.md), [analyzer/SEMANTIC_CALIBRATION_REPORT.md](analyzer/SEMANTIC_CALIBRATION_REPORT.md)
