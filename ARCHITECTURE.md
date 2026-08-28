---
status: active
updated: 2026-08-28
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

`MyMusicApp` が `AudioPlayerService` を一つ生成し、同じ instance を `PlayerStore`、`SettingsStore` に接続します。各 Store は SwiftUI environment に注入されます。`RootView` は Home / Library / Playlist / Search / Highlight の5 tab、mini player、通常 / 作業用 Now Playing sheet、root-level error alert、初期 load task を管理します。

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
  → AVAudioEngine → transition mixer → AVAudioUnitEQ → output
```

`PlayerStore` は `NowPlayingService` と `RemoteCommandService` を通じて MediaPlayer と同期し、`PlaybackHistoryStore` に再生実績を伝えます。`AudioPlayerService` が security-scoped file access、AVAudioSession、seek、fade、再生完了 event を所有します。Highlight は `HighlightPlayerStore` が候補・区間を調整しますが、実再生は同じ `PlayerStore` / `AudioPlayerService` を通ります。

### Music feature analysis / import

```text
local music files → Python Analyzer → schemaVersion 1 JSON
  → TrackFeatureImportService → safe matching against Track
  → TrackFeatureStore → TrackFeaturePersistenceService
  → AudioInformationView / TrackFeatureDetailView
```

Analyzer は librosa / Mutagen / SoundFile と SQLite cache を利用する逐次 CLI です。標準 contract は `Documentation/track-feature-schema-v1.json`。iPhone では音響解析や全曲 hash 計算をせず、特徴量は Track 本体と分離します。採用理由は [ADR-0003](decisions/ADR-0003-mac-feature-analyzer.md) を参照してください。

### Search, favorites, playlists, history

- `TrackSearchService` は text field / match mode / AND・OR / 属性条件を組み合わせ、保存検索 playlist の定義にも使われる。
- `FavoriteStore` と `PlaylistStore` は専用 persistence service を介し、Track ID で library の曲を参照する。Playlist は regular / work の種別互換性を持つ。
- `PlaybackHistoryStore` は再生回数、rating、event を保存する。`AnalyticsService` と `MusicHistory*Service` は現在 library と履歴から表示用 snapshot を導出する。
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
| EQ / transition / display preferences | `SettingsStore` 等 | UserDefaults |
| Analyzer progress | Python analyzer | `analyzer/cache/analysis.sqlite3`（Git ignore） |
| Analyzer export | Python analyzer | `analyzer/output/music_features.json`（Git ignore） |

永続化 model を変える場合は既存 decode compatibility と非破壊性を確認します。Track ID を参照するデータが多いため、identity 変更は横断的な migration なしに行いません。

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
