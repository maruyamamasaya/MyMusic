---
status: active
updated: 2026-08-29
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

主な View 群は責務別に `Home`、`Library`、`Player`、`Playlist`、`Search`、`Settings`、`Highlight`、`Components` に分かれます。

## 主要データフロー

### Library import

```text
Library View → LibraryStore → FileImportService
                           → MusicLibraryService → MetadataService / ArtworkService
                           → LibraryPersistenceService / TrackIdentityService
```

ユーザーが Files / iCloud Drive の folder を選択し、security-scoped bookmark を保存します。scan は対応音声 extension を列挙して metadata と artwork を抽出し、安定 Track ID と folder ごとの library cache を構築します。

### Playback

```text
PlaybackControlsView / playable Views
  → PlayerStore (queue, repeat, shuffle, presentation state)
  → AudioPlayerService
  → AVAudioEngine → transition mixer → normalization gain → AVAudioUnitEQ → output
```

`PlayerStore` は `NowPlayingService` と `RemoteCommandService` を通じて MediaPlayer と同期し、`PlaybackHistoryStore` に再生実績を伝えます。`AudioPlayerService` が security-scoped file access、AVAudioSession、seek、fade、再生完了 event を所有します。Highlight は `HighlightPlayerStore` が候補・区間を調整しますが、実再生は同じ `PlayerStore` / `AudioPlayerService` を通ります。

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

- `TrackSearchService` は text field / match mode / AND・OR / 属性条件を組み合わせ、保存検索 playlist の定義にも使われる。Artist条件はTrack ArtistとAlbum Artistの両方を対象にする。検索画面は`TrackSearchStore`が225ms debounceとTask cancellationを管理し、専用actorで検索してMainActorには結果だけを反映する。保存検索playlistの明示同期も同じactorを使う。
- `FavoriteStore` と `PlaylistStore` は専用 persistence service を介し、Track ID で library の曲を参照する。Playlist は regular / work の種別互換性を持つ。
- `PlaybackHistoryStore` は再生回数、rating、event を保存する。分析画面から1曲の履歴をリセットする場合は、対象Trackの再生回数・event・最終再生日時だけを消去し、お気に入り、rating、飽き度は保持する。`AnalyticsService` と `MusicHistory*Service` は現在 library と履歴から表示用 snapshot を導出する。
- `MusicDataImportService` / `MusicDataExportService` は playlist、library、history の JSON / Markdown 等の入出力境界を担う。

## 永続化

server / database migration はありません。端末内の file と UserDefaults が保存境界です。

| データ | 主な所有者 | 保存形態 / 場所 |
| --- | --- | --- |
| Library folder access | `FileImportService` | UserDefaults の security-scoped bookmark |
| Folder scan cache | `LibraryPersistenceService` | Application Support 内 JSON |
| Stable Track identity | `TrackIdentityService` | Application Support 内 JSON |
| Artwork / highlight | `ArtworkService` / `HighlightRepository` | Caches 内 file / JSON |
| Favorites / playlists / playback history | 各 PersistenceService | Application Support 内 JSON |
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
