# MyMusic Source Index

> **AI 向け:** 実装や調査を始める前にこのファイルを確認し、まず対象機能に関連する範囲だけを調査する。不明な場合にのみリポジトリ全体検索を行う。

この文書は、機能変更時の調査開始地点を示すソースコード管理用インデックスです。プロジェクト概要と起動方法は [`README.md`](README.md)、設計思想と全体の依存方向は [`ARCHITECTURE.md`](ARCHITECTURE.md)、現在の実装状況と既知問題は [`CURRENT.md`](CURRENT.md) を参照してください。

パスはリポジトリルート基準です。端末内の相対保存先は、特記がなければ `Application Support/MyMusic/` 配下です。

## Playback / 再生

- **責務:** 通常／作業用の再生、pause、seek、前後移動、repeat、EQ、曲間トランジション、音量ノーマライズ、Now Playing／remote command、再生セッション確定。
- **主な関連ファイル:** `MyMusic/Stores/PlayerStore.swift`（queue と再生状態の中心）、`MyMusic/Services/AudioPlayerService.swift`（AVAudioEngine、音源アクセス、seek、完了通知）、`MyMusic/Services/PlaybackTransitionService.swift`、`MyMusic/Services/NowPlayingService.swift`、`MyMusic/Services/RemoteCommandService.swift`、`MyMusic/Stores/SettingsStore.swift`、`MyMusic/Views/Player/NowPlayingView.swift`、`MyMusic/Views/Player/PlaybackControlsView.swift`、`MyMusic/Views/Player/WorkSizeNowPlayingView.swift`、`MyMusic/App/MyMusicApp.swift`、`MyMusic/App/RootView.swift`。
- **関連データ / DB / JSON:** 再生中の queue／session はメモリ上。EQ、音量ノーマライズ ON/OFF、トランジション設定は `UserDefaults`。曲別開始・終了・前回位置・gain は `MyMusic/Models/TrackPlaybackAdjustment.swift` と `Application Support/MyMusic/TrackPlaybackAdjustments/<shard>/<track-id>.json`。
- **関連機能・依存:** `PlaybackHistoryStore` へ実績を通知し、`TrackFeatureStore` の normalization 値と `TrackPlaybackAdjustmentStore` の手動調整を使う。Highlight も実再生は同じ `PlayerStore` / `AudioPlayerService` を通る。Watch、lock screen、Control Center は `PlayerStore` の状態に従う。
- **変更時の入口:** AVFoundation、file access、fade、seek は `AudioPlayerService.swift`。queue／repeat／曲終了時の遷移／履歴確定は `PlayerStore.swift`。画面だけなら `Views/Player/`。曲別調整は `TrackPlaybackAdjustmentStore.swift` と同 Persistence Service。回帰確認は `MyMusicTests/TrackPlaybackAdjustmentTests.swift`、`MyMusicTests/VolumeNormalizationTests.swift`。

## Queue / Shuffle / Highlight

- **責務:** queue の構築・並べ替え、通常 shuffle、Preference／Overplay による自動選曲補正、Highlight の候補区間・先読み・4モード・bounded ranking。
- **主な関連ファイル:** `MyMusic/Stores/PlayerStore.swift`、`MyMusic/Models/PlaybackSelectionPolicy.swift`、`MyMusic/Models/PlaybackPreferenceWeightPolicy.swift`、`MyMusic/Views/Player/QueueView.swift`、`MyMusic/Stores/HighlightPlayerStore.swift`、`MyMusic/Models/HighlightCandidate.swift`、`MyMusic/Models/HighlightSelectionPolicy.swift`、`MyMusic/Services/HighlightAnalysisService.swift`、`MyMusic/Services/HighlightRepository.swift`、`MyMusic/Views/Highlight/HighlightPlayerView.swift`、`Documentation/HighlightSelectionPolicy.md`。
- **関連データ / DB / JSON:** queue は永続化しない再生開始時 snapshot。Highlight 解析結果は `Application Support/MyMusic/highlights.json`。重み付け入力は `track-preferences.json`、Playback History SQLite の日別集計、`track-features.json`。
- **関連機能・依存:** `PlaybackBehaviorAnalyzer` が Overplay を導出し、通常 shuffle と Mood Station に適用する。作業用曲、shuffle 永久非表示、Discovery などは経路ごとに適用条件が異なる。Highlight の playback event は短時間離脱に専用 skip 条件を持つ。
- **変更時の入口:** 通常 shuffle の重みは `PlaybackSelectionPolicy.swift`、Good／Bad の表は `PlaybackPreferenceWeightPolicy.swift`。Highlight の順位、多様性、pool／queue 上限は `HighlightSelectionPolicy.swift`、再生区間は `HighlightAnalysisService.swift`、操作と非同期 generation 管理は `HighlightPlayerStore.swift`。テストは `MyMusicTests/PlaybackSelectionPolicyTests.swift` と `MyMusicTests/HighlightSelectionPolicyTests.swift`。

## Playback History

- **責務:** 曲単位集計、Playback Event、入口／選択種別、日別集計、skip／完走／early skip、連続・repeat、1曲リセット、分析・Music History 用の読取モデルを管理する。
- **主な関連ファイル:** `MyMusic/Models/PlaybackHistory.swift`（契約）、`MyMusic/Stores/PlaybackHistoryStore.swift`（UI向け状態と更新API）、`MyMusic/Services/PlaybackHistoryPersistenceService.swift`、`MyMusic/Services/PlaybackHistorySQLiteRepository.swift`、`MyMusic/Services/PlaybackHistoryBackupService.swift`、`MyMusic/Services/AnalyticsService.swift`、`MyMusic/Services/MusicHistoryService.swift`、`MyMusic/Services/MusicHistoryDiscoveryService.swift`、`MyMusic/Services/MusicHistoryMemoryService.swift`、`MyMusic/Views/Settings/AnalyticsView.swift`、`MyMusic/Views/Settings/MusicHistoryView.swift`。
- **関連データ / DB / JSON:** 正本は `Application Support/MyMusic/playback-history.sqlite3`。旧 `playback-history.json` は migration 入力として保持。日次 snapshot は `Backups/Daily/playback-history-*.json`、最終 backup 日は `Backups/last-daily-backup.txt`。Analytics 向け event export 契約は `analytics/playback-export-v1.schema.json` と同 example。
- **関連機能・依存:** `PlayerStore` が session 終了時に event を確定する。Overplay、Preference Drift、整理候補、Music History、Analytics export が履歴を読む。曲 Favorite／Good・Bad の正本は History ではなく `TrackPreferenceStore`。
- **変更時の入口:** event の field／集計規則は `PlaybackHistory.swift` と `PlaybackHistoryStore.swift`、再生中の計測・終了理由は `PlayerStore.swift`、SQL read/write は `PlaybackHistorySQLiteRepository.swift`、表示集計は各 Music History Service。テストは `MyMusicTests/PlaybackHistoryBehaviorTests.swift`、`MyMusicTests/PlaybackHistoryResetTests.swift`、`MyMusicTests/PlaybackHistorySQLitePersistenceTests.swift`。

## SQLite / Migration

- **責務:** iOS 再生履歴の schema 作成・version 更新・transaction 保存、旧JSONからの一回限りの検証付き移行、backup を担う。ローカルWeb Analytics は別SQLiteを所有する。
- **主な関連ファイル:** `MyMusic/Services/PlaybackHistorySQLiteRepository.swift`、`MyMusic/Services/PlaybackHistoryMigrationService.swift`、`MyMusic/Services/PlaybackHistoryPersistenceService.swift`、`MyMusic/Services/PlaybackHistoryBackupService.swift`、`decisions/ADR-0005-sqlite-playback-history.md`。Analytics 側は `analytics/app/database.py`。
- **関連データ / DB / JSON:** iOS DB は `playback-history.sqlite3`（WAL/SHMを含む）。migration 状態は `playback-history-migration-state.json`、移行前 atomic copy は `Backups/Migration/playback-history-pre-sqlite.json`。Analytics DB はリポジトリ内の `analytics/data/analytics.sqlite3` で、`import_runs`、`playback_events`、`library_tracks`、`playback_preferences`、`source_records` を持つ。
- **関連機能・依存:** iOS DB と Analytics DB は共有されず、versioned JSON だけで連携する。旧History内Preferenceから `track-preferences.json` への移行は `TrackPreferenceStore.swift` / `TrackPreferencePersistenceService.swift` 側も確認する。
- **変更時の入口:** iOS schema／SQL／transaction は `PlaybackHistorySQLiteRepository.swift`、旧JSON移行順序とread-back検証は `PlaybackHistoryMigrationService.swift`。Analytics schema／ALTER互換処理は `analytics/app/database.py`、取込upsertは `analytics/importer/service.py`。双方のDBを同一契約とみなさない。

## Apple Watch / WatchConnectivity

- **責務:** WatchをiPhone再生のリモコンとして接続し、状態表示と play／pause／toggle／next／previous command を同期する。Watchは音源・queue・再生ロジックを持たない。
- **主な関連ファイル:** 共有契約 `MyMusic/WatchConnectivity/WatchPlaybackMessage.swift`、iPhone側 `MyMusic/Services/WatchConnectivityService.swift` と `MyMusic/Stores/PlayerStore.swift`、Watch側 `MyMusicWatch/WatchSessionManager.swift`、`MyMusicWatch/NowPlayingView.swift`、`MyMusicWatch/MyMusicWatchApp.swift`、target設定 `MyMusic.xcodeproj/project.pbxproj`。
- **関連データ / DB / JSON:** 永続DBなし。version 1 の `[String: Any]` message／application context に Track ID、title、artist、isPlaying、position、duration を載せる。
- **関連機能・依存:** iPhoneの `PlayerStore` が唯一の再生状態の正本。到達時は即時message、非到達時もapplication contextへ最新状態を保存する。Artwork転送は現状対象外。
- **変更時の入口:** wire field／version／decode は `WatchPlaybackMessage.swift` を両側契約として変更する。送信条件・command dispatch は `WatchConnectivityService.swift`、Watch lifecycle／受信は `WatchSessionManager.swift`。契約テストは `MyMusicTests/WatchPlaybackMessageTests.swift`。

## Music Analysis / Semantic Analyzer

- **責務:** Macで音源を逐次解析し、iPhone import用のversioned特徴量JSONを生成する。Semantic v2は音源embeddingとhead推論を差分更新し、複数music rootの出力を統合する。
- **主な関連ファイル:** 通常Analyzer入口 `analyzer/analyze.py`、管理入口 `analyzer/manage.py`、CLI `analyzer/mymusic_analyzer/cli.py`、音響解析 `audio.py`、metadata `metadata.py`、cache `cache.py`、catalog `catalog.py`、schema `schema.py`。Semantic入口 `analyzer/semantic.py`、実装 `analyzer/mymusic_semantic/cli.py`、`scope.py`、`cache.py`、`models.py`、`reuse.py`、`exporter.py`、`safety.py`。運用は `analyzer/README.md` と `analyzer/SEMANTIC_README.md`、判断は `decisions/ADR-0003-mac-feature-analyzer.md`。
- **関連データ / DB / JSON:** 通常cacheは既存の `analyzer/cache/` 内に `analysis.sqlite3`、出力は `analyzer/output/` に生成する。Semantic cacheは `analyzer/semantic_cache/`、別rootは `analyzer/semantic_workspaces/` 内のlibrary別directoryを使う。統合時は `analyzer/output/` に `music_features_semantic_v2_merged.json` と同名のsources sidecarを生成する（これらの生成物自体はGit管理対象外）。契約は `Documentation/track-feature-schema-v1.json`。
- **関連機能・依存:** 通常DSP／loudnessとSemanticはcacheを書き分けるが、最終的にschemaVersion 1 Track Features JSONとしてiOSへ入る。Analyticsも同JSONを独立importできる。
- **変更時の入口:** DSP式は `audio.py`、loudnessは `normalization.py`、JSON field／検証は `schema.py`。Semanticのscan差分は `scope.py`、model/headは `models.py`、atomic統合は `exporter.py`。回帰は `analyzer/tests/test_analyzer.py` と `analyzer/tests/test_semantic.py`。

## 音楽特徴量

- **責務:** Analyzer JSONをTrack Identityで安全に照合し、端末保存、表示、Mood／Highlight選曲、音量ノーマライズへ供給する。
- **主な関連ファイル:** `MyMusic/Models/TrackFeature.swift`、`MyMusic/Services/TrackFeatureImportService.swift`、`MyMusic/Services/TrackFeaturePersistenceService.swift`、`MyMusic/Stores/TrackFeatureStore.swift`、`MyMusic/Utilities/TrackFeaturePresentation.swift`、`MyMusic/Utilities/VolumeNormalizationGain.swift`、`MyMusic/Views/Settings/TrackFeatureSettingsView.swift`、`MyMusic/Views/Player/TrackFeatureDetailView.swift`、`MyMusic/Views/Components/TrackFeatureBadgeView.swift`。
- **関連データ / DB / JSON:** 端末正本は `Application Support/MyMusic/track-features.json`。import契約とexampleは `Documentation/track-feature-schema-v1.json`、`Documentation/track-feature-v1.example.json`。照合対象はLibraryのStable Track ID、relative path、file size、duration、metadata、optional content hash。
- **関連機能・依存:** `StationStore`／`MoodStationService`、`HighlightSelectionPolicy`、`PlayerStore`のnormalization、Analytics Insightsが読む。Track本体へ特徴値は埋め込まない。
- **変更時の入口:** contractは `TrackFeature.swift` とschema JSONを対で確認。照合・merge・analysisVersionは `TrackFeatureImportService.swift`、保存はPersistence、表示名・単位・カテゴリは `TrackFeaturePresentation.swift`。テストは `MyMusicTests/TrackFeatureTests.swift` と `MyMusicTests/TrackFeatureDisplayIntegrationTests.swift`。

## Insights / Overplay / Preference 関連

- **責務:** Good／Bad（-10...+10）とFavoriteの保存、履歴からOverplay／Preference Driftを導出し、候補表示および自動選曲へ一時補正する。スコア自体は保存しない。
- **主な関連ファイル:** `MyMusic/Models/TrackPreference.swift`、`MyMusic/Stores/TrackPreferenceStore.swift`、`MyMusic/Services/TrackPreferencePersistenceService.swift`、`MyMusic/Services/TrackPreferenceImportService.swift`、`MyMusic/Models/PlaybackBehaviorScoring.swift`、`MyMusic/Services/PlaybackBehaviorAnalyzer.swift`、`MyMusic/Models/PlaybackPreferenceWeightPolicy.swift`、`MyMusic/Models/PlaybackSelectionPolicy.swift`、`MyMusic/Views/Settings/PlaybackBehaviorView.swift`、`MyMusic/Views/Components/PlaybackPreferenceButton.swift`、`MyMusic/Views/Components/TrackFavoriteButton.swift`。
- **関連データ / DB / JSON:** Preference/Favorite正本は schema v2 `Application Support/MyMusic/track-preferences.json`。export/import名は `MyMusic-Playback-Preferences.json`。Overplay／Drift入力は `playback-history.sqlite3` の日別・event集計。History内の旧Preference/Favorite列は移行互換用。
- **関連機能・依存:** 通常shuffle、Highlight、Mood StationがPreference／Overplayを使う。手動選択、Discovery、作業用など除外経路がある。Analytics Webの推薦・Listening ProfileはiOSとは別に `analytics/app/queries.py` でread-only導出する。
- **変更時の入口:** 値の更新・移行は `TrackPreferenceStore.swift`、JSON検証はImport Service、重み表は `PlaybackPreferenceWeightPolicy.swift`、Overplay／Drift式は `PlaybackBehaviorScoring.swift`、履歴window集計は `PlaybackBehaviorAnalyzer.swift`、適用先は各Selection Policy。テストは `MyMusicTests/TrackPreferencePersistenceTests.swift` と `MyMusicTests/PlaybackBehaviorScoringTests.swift`。

## Analytics Web

- **責務:** iOS等から手動exportしたJSONを独自SQLiteへ取り込み、Overview、Music History、Insights、Rankings、Tracks、Data Sources、Import UIをローカルブラウザで提供する。
- **主な関連ファイル:** 起動・契約 `analytics/README.md`、設定 `analytics/app/config.py`、DB `analytics/app/database.py`、route `analytics/app/main.py`、集計SQL `analytics/app/queries.py`、入力model `analytics/importer/schema.py`、import `analytics/importer/service.py`、特徴照合 `analytics/importer/track_feature_resolver.py`、UI `analytics/web/index.html`、`app.js`、`controls.js`、各CSS、起動 `analytics/start.sh` / `analytics/start.ps1`。
- **関連データ / DB / JSON:** `analytics/data/analytics.sqlite3`、受理原本 `analytics/imports/`。Playback Events、Library、Preferences、Track Features、Volume Normalization、Playlists、Equalizer、Genre Display Presetsの8種JSON。Playback契約は `analytics/playback-export-v1.schema.json`。
- **関連機能・依存:** iOS／Analyzerとはプロセス・DB・依存を共有しない。Track ID（特徴量は安全なidentity fallbackあり）でデータを結合し、Preferenceだけschema v2 JSONとして書き戻し用exportが可能。期間集計はJST、保存event日時はUTC。
- **変更時の入口:** API追加は `main.py`、SQL・指標定義・推薦は `queries.py`、schema／判別は `importer/schema.py` と `service.py`、table変更と後方互換ALTERは `database.py`、画面状態は `web/app.js`、候補・paging共通操作は `web/controls.js`。テストは `analytics/tests/test_analytics.py`、UIは `controls.test.cjs` と `browser_ux.cjs`。

## Settings / Library 管理

- **責務:** Files/iCloudフォルダ登録、security-scoped bookmark、scan・metadata・Stable Track Identity・cache、ジャンル表示、データimport/export、EQ／トランジション等の設定画面を管理する。
- **主な関連ファイル:** `MyMusic/Stores/LibraryStore.swift`、`MyMusic/Services/FileImportService.swift`、`MyMusic/Services/LibrarySyncService.swift`、`MyMusic/Services/MusicLibraryService.swift`、`MyMusic/Services/MetadataService.swift`、`MyMusic/Services/LibraryPersistenceService.swift`、`MyMusic/Services/TrackIdentityService.swift`、`MyMusic/Models/Track.swift`、`MyMusic/Stores/SettingsStore.swift`、`MyMusic/Views/Library/LibraryFoldersView.swift`、`MyMusic/Views/Library/GenreDisplaySettingsView.swift`、`MyMusic/Views/Settings/SettingsView.swift`、`MyMusic/Views/Settings/DataManagementView.swift`、`MyMusic/Services/MusicDataExportService.swift`、`MyMusic/Services/MusicDataImportService.swift`、`MyMusic/Services/MusicSettingsImportService.swift`。
- **関連データ / DB / JSON:** bookmarkは `UserDefaults` の `musicLibraryFolderBookmarks`（旧単数keyも読取）。cacheは `Application Support/MyMusic/library-index.json`、identity registryは `track-identities.json`、artworkは `Artwork/`。無効ジャンル／プリセットと基本再生設定は `UserDefaults`。データ管理はLibrary、Playback Events、Preferences、Features、Volume、Playlists、EQ、Genre PresetsのJSON／ZIPを扱う。
- **関連機能・依存:** `LibrarySyncService` actorがscanを直列化し、metadata、identity、cache、派生Libraryを構築する。Track IDはPlaylist、History、Preference、Features、Analytics exportの結合キー。作業用catalogは `WorkLibraryCatalogService.swift`、検索は `TrackSearchStore.swift` / `TrackSearchService.swift`。
- **変更時の入口:** フォルダ権限は `FileImportService.swift`、scan順序／並行性は `LibrarySyncService.swift`、列挙と差分は `MusicLibraryService.swift`、tag読取は `MetadataService.swift`、ID照合／fingerprintは `TrackIdentityService.swift`、cache互換は `LibraryPersistenceService.swift`。設定UIは `Views/Settings/`、転送契約は各Import/Export Service。テストは `MyMusicTests/LibrarySyncServiceTests.swift`、`LibrarySearchTests.swift`、`TrackIdentityMoveTests.swift`、`DataTransferTests.swift`。

## 周辺領域の入口

- **Playlist / Favorite:** `MyMusic/Stores/PlaylistStore.swift`、`FavoriteStore.swift`、`MyMusic/Services/PlaylistPersistenceService.swift`、`FavoritePersistenceService.swift`、`MyMusic/Models/Playlist.swift`。保存先は `playlists.json`、`library-favorites.json`（Track Favoriteの正本は上記Preference）。
- **Search:** `MyMusic/Stores/TrackSearchStore.swift`、`MyMusic/Services/TrackSearchService.swift`、`MyMusic/Views/Search/SearchView.swift`。保存検索Playlistも同じ検索Serviceを使う。
- **Mood Station:** `MyMusic/Stores/StationStore.swift`、`MyMusic/Services/MoodStationService.swift`、`MyMusic/Models/MoodStation.swift`、`MyMusic/Views/Station/`。Features、Preference、Overplay、年metadataに依存する。
- **Library cleanup:** `MyMusic/Services/LibraryCleanupCandidateService.swift`、`MyMusic/Views/Settings/LibraryCleanupCandidatesView.swift`。Playback Eventを読むだけで履歴・評価を自動変更しない。
- **Composition / navigation:** Store生成と依存注入は `MyMusic/App/MyMusicApp.swift`、tab・sheet・lifecycleは `MyMusic/App/RootView.swift`。

## 索引の更新ルール

ファイルの追加・移動、永続化先、JSON契約、主要な呼び出し経路が変わったときに更新します。機能の完成状況は `CURRENT.md`、設計判断や式の正本は `ARCHITECTURE.md` / `decisions/`、詳細な利用手順は各READMEへ記録し、このファイルには「調査をどこから始めるか」だけを残します。
