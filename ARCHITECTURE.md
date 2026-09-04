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

### Local Web Analytics

```text
MyMusic / future data sources
  → Playback Events / Library / Preferences / Features / Volume / Playlists / Settings JSON
  → analytics/importer (contract detection, validation, deduplication / upsert)
  → analytics/data/analytics.sqlite3 (events + catalog + preferences + source records + import history)
  → analytics/app (FastAPI + on-demand aggregation)
  → analytics/web (local browser dashboard)
```

`analytics/`はiOSアプリとは別プロセス・別依存・別SQLiteで動作する。iOSのApplication Support、PlaybackHistory Store／Repository、`analyzer/`のcacheを参照せず、Analyticsからそれらへ書き戻さない。統合境界はversioned JSON contractだけとする。Playback Eventはevent IDでappend／重複排除し、Library snapshotとPlayback Preferences snapshotはTrack IDでupsertする。FeaturesとVolumeはTrack ID、Playlistは内包曲のTrack IDでLibraryへ照合する。EQとジャンルプリセットは曲非依存の設定スナップショットとして扱う。完全なsnapshotから外れた項目は現行表示から外すが、受理した原本JSONは保持する。将来のAndroid／Analyzer由来ImporterもSwift modelへ依存せず追加できる。v0の契約、データ配置、起動方法は`analytics/README.md`を参照する。

Web UIはOverview、Music History、Insights、Rankings、Tracks、Data Sources、Importを独立ページとして持つ。Insightsの品質フィルターは期間条件と独立して日時だけで判定する。特徴量分析は`source_records`の最新analysisVersionだけを対象に、許可リスト化した特徴量をSQLite `json_extract`／`json_each`で検証・抽出してPlayback EventへTrack ID結合する。最近の変化は選択期間と直前の同日数（allは30日ずつ）を比較し、曲、特徴、Artist／Album／Genreを共通閾値で抽出する。時間帯分析はJSTの朝／昼／夜／深夜、Listening Profileは完走率−Skip率−Early Skip率×0.5の説明可能なscoreを使う。推薦はProfile・Preference・Favorite・完走実績を加点し、Skip・Early Skip・選択期間の再生過多を減点するread-only派生値で、未再生曲の行動値は推測しない。詳細イベントとEarly Skipの判定条件はQueries層の共通predicateへ集約し、Raw JSONやLibraryを更新しない。

### Library import

```text
Library View → LibraryStore → FileImportService
                           → LibrarySyncService → MusicLibraryService → MetadataService / ArtworkService
                           → LibraryPersistenceService / TrackIdentityService
```

`LibraryStore`は表示対象ライブラリを反映するとき、`WorkLibraryCatalogService`で20分以上または「作業用BGM」の曲だけを抽出し、作業用のAlbum / Artist / Album Artist集合を`WorkLibraryCatalog`として同時に更新する。`WorkLibraryView`はこの派生catalogだけを読み、通常曲を専用一覧へ混在させない。

ユーザーが Files / iCloud Drive の folder を選択し、security-scoped bookmark を保存します。scan は対応音声 extension を列挙して metadata と artwork を抽出し、安定 Track ID と folder ごとの library cache を構築します。

`LibrarySyncService` actorはscanを1件ずつ直列化し、Track Identityのscan sessionとLibrary cache更新の競合を防ぐ。ファイル走査、差分判定、metadata／Identity照合、cache保存、複数folderの重複排除と`MusicLibrary`派生モデル構築はMainActor外で行う。`LibraryStore`は同期状態と完成snapshotの反映だけをMainActorで行い、曲単位ではObservable stateを更新しない。同期中は現在の表示libraryを保持するため、既存Track IDを参照する再生・履歴・Preference・Playlistは同期処理から独立して継続する。

Track Fingerprintの一括作成は通常scanから分離する。`TrackFingerprintBuildView` → `TrackFingerprintBuildStore` → `TrackIdentityService`のforeground専用経路で、未作成曲を件数上限なく逐次処理する。各曲の音声を8 kHz mono PCMで最大2 MB読み、durationを含むSHA-256を既存`track-identities.json`のoptional `audioFingerprint`へ1曲ごとにatomic保存する。画面離脱、scene非active、再生／Library load開始時はTaskをcancelする。既定では未downloadのiCloud itemをskipし、明示toggle時だけ取得を許可する。処理済みの正本はidentity registryとする。

ジャンル表示設定の適用時は、`LibraryStore`が全曲と無効ジャンルのsnapshotを`GenreLibraryFilterService` actorへ渡す。actorが表示曲の抽出とAlbum / Artist / Genre / Composerの再構築をutility priorityで実行し、`LibraryStore`は完了した最新requestの結果だけをMainActor上の表示stateへ反映する。初期loadや再scanも同じ非同期経路を使い、一貫した完成snapshotだけを公開する。

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
- `PlaybackHistoryStore` は再生回数、正式なPlayback Event、初回／最終再生日時、総再生時間、スキップ／完走、連続再生、リピート再生、manual / automatic、入口別、日別集計を保存する。曲Favoriteと`playbackPreference`の正本は`TrackPreferenceStore`であり、Historyの旧fieldはmigration互換用に限る。分析画面から1曲の履歴をリセットしてもPreferenceは変更しない。
- `LibraryCleanupCandidateService` は通常曲と履歴snapshotを読み、終了理由を持つ直近20件までのPlayback Eventを評価する。最低5件、`user_skipped`率50%以上、平均completion ratio 10%以下をすべて満たす曲だけを候補にする。既存`playCount`、直接選択、Good / Badは判定に使わず、終了理由のない旧eventも誤分類防止のため除外する。途中スキップ率降順、次に平均再生率昇順、同数時は最終再生の新しい順に並べ、履歴・評価・飽き度・shuffle非表示を変更しない。
- `PlaybackPreferenceWeightPolicy` はGood / Bad（-10〜+10）を正の選曲重みへ写像し、`PlaybackSelectionPolicy`はOverplayによるshuffle（最大50%）／Station（最大20%）の一時的な減衰を一元管理する。`PlaybackBehaviorAnalyzer`はlibraryと保存済み日別集計のsnapshotから`OverplayScoring`（直近7日／その前56日）と`PreferenceDriftScoring`（直近30日／それ以前、historical最低8件）を呼び、分析結果と候補を純粋に導出する。通常shuffle、Quick Play、Selective Randomの候補と選択後queue、PlayerStoreの自動shuffle orderは1選曲単位のOverplay snapshotを使う。未再生Discoveryと作業用再生は目的を維持するためPreferenceだけを使う。Stationは純粋なMood scoreでthreshold判定した後にだけOverplay factorをrankingへ掛け、既存artist減点を続ける。Preference Driftは候補表示専用のままである。派生score／weightはSQLiteへ保存せず、手動選択、Good / Bad、飽き度、恒久非表示を変更しない。
- 永続化は`PlaybackHistoryPersistenceService` actorから`PlaybackHistorySQLiteRepository`を呼び、`Application Support/MyMusic/playback-history.sqlite3`を正本とする。schema version 2ではevent IDと完走flag、version 3では終了理由`natural / user_skipped / other`を追加する。通常変更は1曲snapshotを1 transactionで渡し、`playback_events`はevent IDによる`INSERT OR IGNORE`でappendし、track／日別／入口別はupsertする。空event snapshotだけが曲別resetの削除境界となる。初回は`PlaybackHistoryMigrationService`が旧JSONを上書きなしの永久backupへcopyし、transaction import後の全Model一致でのみDB metadataとDB外stateを`verified`にする。`PlaybackHistoryBackupService`は起動load時に24時間条件の日次JSON snapshot（7世代）を作る。
- `AnalyticsService` のCSV exportは、運用上の共通契約としてヘッダを `種類,日時,曲名,アーティスト,再生回数,値,詳細` とし、分析データを以下の行種別で出力する。
- `楽曲別再生回数`, `楽曲別再生行動`, `楽曲別再生入口`, `再生傾向評価` はそれぞれTrack別に追加行する。
- `再生履歴` は再生イベントの時系列（日別にグループ化済み）を出力し、`集計` は全体件数（総再生、手動、自動、お気に入り、プレイリスト）を追加する。
- `楽曲別再生行動` は `manual:<数>, automatic:<数>, 7日:<数>, 30日:<数>, 初回:<日時>, 最終:<日時>` を `詳細` 列へ格納し、`楽曲別再生入口` は `入口:回数` をスペース区切りで `詳細` 列へ格納する。
- CSVインポート経路は現時点で未実装のため、上記CSVが現行正規フォーマットとする。
- `MusicDataImportService` / `MusicDataExportService` は playlist、library、history、解析snapshot、設定の JSON / Markdown 等の入出力境界を担う。Preference Importは専用`TrackPreferenceImportService`で外部schema v2を厳格検証してから`TrackPreferenceStore`へ渡す。Playlist tagはversion 1文書の後方互換な追加fieldとして扱い、field欠落時は空tagとする。
- `TrackFeatureStore`は保存済み特徴量をTrack ID順のsnapshotとして提供し、`MusicDataExportService`が全特徴量JSONと、完全なLUFS / True Peak / gainを持つ曲だけの音量ノーマライズJSONへ変換する。これは音源を含まない確認・退避用出力であり、Analyzer schema v1の再Import contractではない。
- `TrackPreferencePersistenceService`は`Application Support/MyMusic/track-preferences.json`を曲Preferenceの正本とする。schema v2 fileがない初回だけ旧Playback HistoryのFavorite／評価を移し、atomic write後のread-back一致を確認する。History読込失敗時は空migrationを確定しない。
- `MusicDataExportService`はTrack ID、`playbackPreference`、`favorite`を安定順でschema v2の`MyMusic-Playback-Preferences.json`へ出力する。Library／History JSONのFavorite fieldは互換目的で新Preference値をミラーするが正本ではない。
- Preference Importは外部JSONを直接永続化せず、`TrackPreferenceImportService`が未知fieldを含む構造、schema、日時、UUID、重複、値範囲、BoolをStore変更前に全件検証する。`TrackPreferenceStore`は現在LibraryのTrack IDだけを既存snapshotへmergeし、`TrackPreferencePersistenceService`のatomic保存成功後にのみmemory stateへ反映する。未収録Trackは作成せず、JSONにない既存Preferenceは維持する。
- Library JSONはidentity registryに保存済みのFingerprintだけをoptional `audioFingerprint`として出力し、Export操作自体では音声を読まない。Analyticsは64文字のlowercase SHA-256として検証・保存するが、v0では別Track IDの自動統合は行わない。
- AnalyticsのLibrary tableは後方互換なoptional列として`relative_path`／`file_size`を持つ。Track Featuresの`sourceIdentity`は既存どおり`source_records.raw_json`を正とし、Analytics内の`TrackFeatureResolver`がLibrary／Features Import後にTrack ID完全一致を優先して再解決する。救済は本体と同じpath優先、file size完全一致、duration差0.5秒以内、fallback metadata一致かつ一意候補に限定し、fingerprintは必須にしない。
- 同Serviceの`MyMusic-Playback-Events.json`は保存済みPlayback EventをAnalytics schema v1へ写し、Libraryから曲名、Artist、Album、曲長を補完する。イベントID、再生日時、実聴秒数、完走／Skip、入口、選択種別は保存値を使用し、保存していないsession IDは出力しない。現在のLibraryでTrack IDを解決できないeventは必須metadataを安全に補えないため出力対象外とする。
- EQ文書は現在の`EqualizerSettings`とcustom preset、ジャンル文書は順序付き`GenreDisplayPreset`を、それぞれ`kind`とversionを持つ別JSONとして扱う。`MusicSettingsImportService`が種類、version、有限値、EQの範囲・バンド数、重複名／IDをStore変更前に検証する。Storeは同名presetを更新し新規presetを追加してUserDefaultsへ保存するため、対象外の既存presetは削除しない。

## 永続化

server / database migration はありません。端末内の file と UserDefaults が保存境界です。

| データ | 主な所有者 | 保存形態 / 場所 |
| --- | --- | --- |
| Library folder access | `FileImportService` | UserDefaults の security-scoped bookmark |
| Folder scan cache | `LibraryPersistenceService` | Application Support 内 JSON |
| Stable Track identity | `TrackIdentityService` | Application Support 内 JSON |
| Artwork / highlight | `ArtworkService` / `HighlightRepository` | Caches 内 file / JSON |
| Track preferences / playlists / playback history | 各 PersistenceService | `track-preferences.json` / JSON / `playback-history.sqlite3` |
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
