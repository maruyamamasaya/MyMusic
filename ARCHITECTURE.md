---
status: active
updated: 2026-09-18
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

音楽史トップの「今日の音楽史」は`MusicHistoryView`から読み込み時に`MusicHistoryCardService`を呼び、`MusicHistoryCardCandidate`を表示する。Serviceは現在LibraryのTrackとPlayback Eventを日・月・曲・Artist単位に一度索引化し、12種の独立した候補生成関数へ渡す。カード集計は`Task.detached`でMainActor外へ送り、キャンセル済みの結果は表示へ適用しない。候補は成立条件、優先度、score、主役Trackの重複で選択し、同じ入力と日付では順序が安定する。Candidateは表示用Trackと再生候補の順序付きTrack IDを分けて持つ。カードタップ時は`MusicHistoryCardPlaybackService`が現在Libraryとファイルの可読性で再解決・重複排除し、最大10曲をPlayerStoreの通常Queueへ手動／History入口で渡す。曲が残らなければ再生状態は変更しない。既存の`MusicHistoryService`、`MusicHistoryDiscoveryService`、`MusicHistoryMemoryService`は従来の年表示と記憶の構築を継続する。追加の永続化はない。

`MyMusicApp` が `AudioPlayerService` を一つ生成し、同じ instance を `PlayerStore`、`SettingsStore` に接続します。`TrackPlaybackAdjustmentStore`もPlayerStoreとSwiftUI environmentで共有します。各 Store は SwiftUI environment に注入されます。`RootView` は Home / Library / Playlist / Search / Settings の5 tab、mini player、通常 / 作業用 Now Playing sheet、root-level error alert、初期 load task、background移行時の再生位置flushを管理します。HighlightはHomeの「マイミュージック」タイル列左端から同じHome NavigationStack内へ遷移する。

「あとで聴く」は通常Playlistから独立した一時リストとする。`NowPlayingView` → `ListenLaterStore` → `ListenLaterPersistenceService`で追加時のTrack ID・再生回数・追加日時を保存する。`RootView`は`PlaybackHistoryStore.homePresentationRevision`の更新を受け、現在の再生回数が追加時より大きい項目を`ListenLaterStore`で削除する。判定は既存`PlayerStore`の再生カウント条件（実聴30秒または曲長50%）を正とし、別の完走判定を増やさない。一覧から作った再生queueは開始時snapshotのため、その後リストから自動削除されても再生中queueを変更しない。

ファイル共有は各画面の`ShareLink`へ委ねず、共通の`ActivityShareSheet`が一時ファイル作成と`UIActivityViewController` presentationを担当する。共有シートは画面rootの安定したpresentation stateから開き、`popoverPresentationController`が存在する場合は生成時・更新時ともsource view / rectを設定するため、iPhoneのsheet適応とiPadのPopover適応を同じ経路で扱う。

主な View 群は責務別に `Home`、`Library`、`Player`、`Playlist`、`Search`、`Settings`、`Highlight`、`Components` に分かれます。

Homeの「マイミュージック」左端にあるHighlightタイルとライブラリ／アクティビティタイルは、`MyMusic/Resources/HomeTileImages/`に所定のベース名で置かれたローカル画像をbuild resourceとして任意に読み込む。Highlight画像がない場合は通常再生対象からランダムに選んだArtworkを装飾として表示し、再生queueや先頭曲には接続しない。ライブラリ／アクティビティ画像がない、またはdecodeできない場合は、`HomeItemTile`が従来のdestination別グラデーションをそのまま表示する。ローカル画像は永続化データではなく、build時だけアプリbundleへ取り込まれる任意assetである。

Homeのタイトル行右側は`TodayPlaybackSummaryService`がロード済み`PlaybackHistoryStore.entries`からローカル日付の`dailySummaries.playCount`と同日開始の終了済み`playbackEvents.listenedSeconds`を集計したsnapshotを表示する。開始時の`homePresentationRevision`、終了時の`todayPlaybackRevision`、日付変更時に更新し、Viewに履歴集計ロジックを置かない。

HomeとPlaylistで共有するステーション入口カードは、`MyMusic/Resources/HomeTileImages/station-background.*`を同じく任意のbuild resourceとして読み込む。画像がない、またはdecodeできない場合は、`StationEntryView`が従来のグラデーションを表示する。

Homeの「作業用BGM再生」は即時再生ではなく、ジャンルで「作業用BGM」と明示した対象を曲名、アルバム、アーティスト、アルバムアーティスト、プレイリスト別に閲覧する入口とする。各一覧は対象内検索を持ち、曲の再生は`PlayerStore`へ`.workSize` presentationを指定して専用playerへ接続する。

## テーマの表示境界

`SettingsStore.theme` → `MyMusicApp`のEnvironment／tint → `ThemePalette`／`ThemeBackground`／各画面の`themeScreen()`。保存IDは`AppTheme`、視覚パラメータはViews/Themeへ分離する。設定はUserDefaultsの`appearance.theme`に保存し、App外バックアップの許可キーへ含める。再生StoreとWatch通信には接続しない。詳細は[Themes](Documentation/Themes.md)。

### 再生中のアート画面

Visual Worldの描画種類は`SettingsStore.visualWorldStyle`が所有し、`appearance.visualWorldStyle`へ保存する。旧設定でキーがない場合は`appearance.theme`に対応する種類を初期値として採用する。旧`living-aurora`はPhoton Sphereへ読み替え、保存値を`simple-dark`へ正規化する。選択後はアプリのテーマと独立し、App外バックアップにも含める。

`NowPlayingView` → `NowPlayingVisualWorldView` → `VisualWorldSimulation` → `VisualWorldMetalView`／`VisualWorldInstallation.metal`。既存の`AudioPlayerService`出力tapを共有し、追加のPCM copyは事前確保した`VisualWorldAudioMailbox`へ渡す。atomicな単一slotが満杯なら追加sampleをdropし、音声callbackを待たせない。`VisualWorldAudioAnalysisService`のserial queueが最大20Hzで`VisualWorldSpectrumAnalyzer`（Accelerate FFT／調波salience）を実行し、`PlayerStore.visualAudioFrame`へ返す。seek／曲切り替え／route変更はgenerationを更新し古い結果を拒否する。既存`spectrumLevels`と`spatialSnapshot`の契約は維持する。

`PlayerStore`は表示用解析の有効／無効と再生sessionのseedを所有する。Viewは前面・scene・accessibility・再生状態に応じて解析購読を切り替える。Simulationは音域、短期の励起、残光と余韻を表示状態だけへ積分する。Blue Cosmosでは最大3層の星空と低周波の星雲へ分岐する。薄明は同じ星の生成方式を低密度・低輝度で共有し、青い夜空を約8割、暖色の地平線を下側へ限定する。Pulse Neonは最大10本分のゲート（低品質6）の発光チューブと透視投影へ分岐する。ゲートは5形から曲のseedと周回数で選び、遠端で消えている時だけ形を更新する。Photon SphereのMetalは固定サイズの単一球体の交差と内部の有界volume sampling（通常18／低品質10 step）、発光粒子・陰影・halo・bloom、および種を固定した最大16光子と3微小衛星球を描く。外周光子は複数の周期を重ねた連続軌道で動かす。Plasma SparkはSimulationのピーク時刻・低中高域強度・発生回数から24個の固定テンプレートを巡回し、端から端へ届く一本の経路と最大2本の画面端まで届く枝をMetal／Canvasで共有する。細い白熱放電とPhoton Sphereに近い微小光子・飛散粒子を有界の計算で描く。静かな間は暗い背景だけとなる。Visualizerは同じ解析frame内でPCMを48区間の符号付きピークへ要約してWaveformとする。MetalとCanvasは中央の一本の白い芯と淡い色の光を持つ波形を描き、低中高域それぞれ異なる周期と振幅で揺らす。微小光子はPhoton Sphereと同じ描画を共有し、beat時は一つの短い円形波紋だけを描く。GPUの未完了frameは最大2とする。フレーム間隔と解像度を低電力・thermal状態で下げる。Metal初期化不能時は`VisualWorldScene` Canvasを使う。

`TrackVisualProfile`は`TrackFeatureValues`を描画向けに正規化し、`NowPlayingVisualWorldView`で曲変更時に更新・時間補間する。描画はこのProfileと`VisualWorldSimulation`の平滑化済みリアルタイム音響値を組み合わせる。曲ID由来の`TrackVisualSeed`は再生ごとに同じ配置を与える。

`VisualWorldPaletteService` actorは縮小Artworkから主色／副色／accentと占有率を取得し、無彩色画像も扱う。曲切り替えの姿勢・色はRendererで補間する。`VisualWorldController`は曲名・アーティスト・小さなArtworkと操作を一つのバーにまとめ、前へ・再生／一時停止・次へを`PlayerStore`、いいね・グッドを`TrackPreferenceStore`へ接続する。アート画面のボタン以外の全域は排他的な1回／2回タップで再生／一時停止といいねを実行する。詳細パネルは表示せず、通常画面への切り替えを使う。非表示／sheet／scene非activeでは描画と追加解析を休止、一時停止時は約10秒以内の有限の慣性を残す。現行仕様は[再生中のビジュアル](Documentation/NowPlayingVisualWorld.md)、描画分離の採用理由は[ADR-0006](decisions/ADR-0006-visual-world-rendering.md)。

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

### Static Web Analytics

```text
MyMusic JSON files
  → Browser File API
  → analytics/web-static/core.js adapter
  → in-memory normalized tracks / playEvents / features / preferences
  → client-side aggregation
  → analytics/web-static/app.js UI
```

`analytics/web-static/`はLocal版のFastAPI UIである`analytics/web/`とは別アプリである。静的配信だけを必要とし、JSON、音源、Artwork、SQLiteをserverへ送らない。入力と集計結果はJavaScript heapにだけ保持し、永続Web Storageや外部DBを使わない。CSPの`connect-src 'none'`を追加の通信防止境界とする。既存のPlayback Events v1、Library v1、Preferences v1/v2、Track Features v1をadapterでNormalized Dataへ変換し、Local版と同じTrack ID結合、2026-09-01以降の詳細指標、30秒以下のEarly Skip定義を用いる。Local版のSQL集計を壊す共通化は行わず、将来はversioned contract、normalized model、指標fixtureを共通化境界とする。

静的Web版はSitesへ一般公開する。ホスティングは静的ファイルの配信境界に限定し、runtime binding、server-side database、認証、upload APIを持たない。Sitesのproject IDと静的出力設定は`analytics/web-static/.openai/hosting.json`で管理する。

Web UIはOverview、Music History、Insights、Rankings、Tracks、Data Sources、Importを独立ページとして持つ。Insightsの品質フィルターは期間条件と独立して日時だけで判定する。特徴量分析は`source_records`の最新analysisVersionだけを対象に、許可リスト化した特徴量をSQLite `json_extract`／`json_each`で検証・抽出してPlayback EventへTrack ID結合する。最近の変化は選択期間と直前の同日数（allは30日ずつ）を比較し、曲、特徴、Artist／Album／Genreを共通閾値で抽出する。時間帯分析はJSTの朝／昼／夜／深夜、Listening Profileは完走率−Skip率−Early Skip率×0.5の説明可能なscoreを使う。推薦はProfile・Preference・Favorite・完走実績を加点し、Skip・Early Skip・選択期間の再生過多を減点するread-only派生値で、未再生曲の行動値は推測しない。詳細イベントとEarly Skipの判定条件はQueries層の共通predicateへ集約し、Raw JSONやLibraryを更新しない。

Webの大量候補検索は`analytics/web/controls.js`の`SearchPicker`に分離し、候補文字列の正規化検索と最大30件のDOM表示を担当する。`app.js`は画面ごとのAbortControllerで古い読込を中断し、表示中の条件と結果の一致、読み込み状態、エラー時の再試行を管理する。`experience.css`は共通操作部品とレスポンシブ表示を担当する。Tracks／Data Sourcesはページ本体だけを縦スクロール境界とし、表のoverflowは横方向の列閲覧だけに使う。Data Sourcesの`search`はQueries層で名称／補足情報（Artist等）を検索し、検索後の件数・紐付け件数と同じ条件でSQLページングする。検索文字はバインドし、LIKEの特殊文字はエスケープする。永続化境界やschemaは変更しない。

### Library import

```text
Library View → LibraryStore → FileImportService
                           → LibrarySyncService → MusicLibraryService → MetadataService / ArtworkService
                           → LibraryPersistenceService / TrackIdentityService
```

`LibraryStore`は表示対象ライブラリを反映するとき、ジャンルに「作業用BGM」が指定された曲と、ハイレゾ対象曲を通常のTrack / Album / Artist集合から除外する。同時に`WorkLibraryCatalogService`と`HiResLibraryCatalogService`で専用catalogを更新する。分類優先順位は作業用BGM、ハイレゾ、通常の順で、ハイレゾはジャンル項目「ハイレゾ」またはTrackへ保存したstream-level形式が既存JEITA基準を満たすロスレス音源を対象とする。`WorkLibraryView`と`HiResLibraryView`は各派生catalogを読み、通常側と専用側を相互に混在させない。

`SongsView`の検索・filter・sortはTrack、Track Preference、Playback HistoryのMainActor上snapshotを取得し、`Task.detached`内のpureな`arrange`で一括処理する。requestには各Storeのrevisionを含め、処理中に条件や正本が変わった古い結果は反映しない。UIへは先頭100曲から段階表示し、一覧scrollで全件Viewを同時生成しない。filter／sortは表示と、その表示から開始するqueueだけへ適用し、Library、履歴、Preferenceの正本を変更しない。

`LibraryStore`は完成した表示snapshotの反映時に、Track ID→Track、Album ID→Album、Artist ID→Artist、Track ID→Album／Artist IDのlookup indexも同時に再構築する。Album／Artist詳細や再生中画面の参照解決はこのindexを使い、呼び出しごとに全Track辞書を再生成したり全Album／Artistを走査したりしない。indexと専用catalogは派生memory stateであり永続化契約を増やさない。

ユーザーが Files / iCloud Drive の folder を選択し、security-scoped bookmark を保存します。scan は対応音声 extension を列挙して metadata と artwork を抽出し、安定 Track ID と folder ごとの library cache を構築します。

`LibrarySyncService` actorはscanを1件ずつ直列化し、Track Identityのscan sessionとLibrary cache更新の競合を防ぐ。ファイル走査、差分判定、metadata／Identity照合、cache保存、複数folderの重複排除と`MusicLibrary`派生モデル構築はMainActor外で行う。`LibraryStore`は同期状態と完成snapshotの反映だけをMainActorで行い、曲単位ではObservable stateを更新しない。同期中は現在の表示libraryを保持するため、既存Track IDを参照する再生・履歴・Preference・Playlistは同期処理から独立して継続する。

手動同期は`LibraryScanDepth.quick`と`complete`の2段階を持つ。quickはfile sizeと更新日時が一致するTrackをcacheから再利用し、completeは全ての取得可能な音源を`MetadataService`へ渡してタグとArtworkを再抽出する。どちらも`TrackIdentityService`のpath／resource identifier／fingerprint照合を経るため、metadataの再構築をTrack UUIDの再生成とは分離する。Artworkは`Track UUID + image content hash`をidentifierとし、同一Trackの埋め込み画像が変わった場合だけ表示identifierも変えてViewの画像再loadを発火する。

complete同期は`LibraryScanCheckpointService`へ取得済み`Track`と取得日時をfolder別にbatch保存する。再実行時は10分以内かつrelative path・file size・更新日時が一致するentryだけを候補とし、`TrackIdentityService.resolveIdentity`の結果も同じUUIDの場合だけmetadata読取をskipする。元fileが更新された場合やIdentityが一致しない場合は必ず再取得する。scan完了だけではcheckpointを消さず、`LibraryPersistenceService`への完成library保存後にだけ削除するため、scan後の保存失敗からも再開できる。checkpointは同期最適化であり、書込失敗はlibrary同期自体を失敗させない。

`MusicLibraryService`は曲数ベースの`LibraryScanProgress`を`LibrarySyncService`経由で`LibraryStore`へ返す。directory列挙前は総数不明、列挙後はfolder単位の総数／完了数／残数をMainActor stateへ反映する。iCloud未download、directory enumerator、resource values、AVFoundation metadataの失敗は`LibraryScanNotice`として収集する。成功したTrackのlibrary更新は従来どおり継続し、noticeはfolder別に集約してLibrary alertへ表示するため、診断追加によってscanの成否規則は変えない。

Track Fingerprintの一括作成は通常scanから分離する。`TrackFingerprintBuildView` → `TrackFingerprintBuildStore` → `TrackIdentityService`のforeground専用経路で、未作成曲を件数上限なく逐次処理する。各曲の音声を8 kHz mono PCMで最大2 MB読み、durationを含むSHA-256を既存`track-identities.json`のoptional `audioFingerprint`へ1曲ごとにatomic保存する。画面離脱、scene非active、再生／Library load開始時はTaskをcancelする。既定では未downloadのiCloud itemをskipし、明示toggle時だけ取得を許可する。処理済みの正本はidentity registryとする。

ジャンル表示設定の適用時は、`LibraryStore`が全曲と無効ジャンルのsnapshotを`GenreLibraryFilterService` actorへ渡す。actorは作業用BGMとハイレゾ対象を除く通常曲にジャンル設定を適用してAlbum / Artist / Genre / Composerを再構築し、全曲から作業用catalogとハイレゾcatalogも構築する。`LibraryStore`は完了した最新requestの結果だけをMainActor上の表示stateへ反映する。初期loadや再scanも同じ非同期経路を使い、一貫した完成snapshotだけを公開する。

「作業用BGM」と「ハイレゾ」は専用再生を分離する分類マーカーであり、通常ライブラリのジャンル表示フィルターには選択肢として出さない。各専用catalogは通常側の無効ジャンルやプリセットとは独立して維持する。

### Playback

```text
PlaybackControlsView / playable Views
  → PlayerStore (queue, repeat, shuffle, presentation state)
  → AudioPlayerService
  → AVAudioEngine → transition mixer → normalization gain → AVAudioUnitEQ → output
```

`PlayerStore` は `NowPlayingService` と `RemoteCommandService` を通じて MediaPlayer と同期し、`PlaybackHistoryStore` に再生実績を伝えます。再生回数の確定時だけ`PlaybackHistoryCoordinator`を同期経由し、他の履歴記録・選曲判断・Playback Contextは引き続きPlayerStoreが扱います。再生セッション中の総再生時間、開始日時、開始文脈はPlayerStore内の軽量な一時状態として保持し、曲変更・停止・自然終了時に実聴秒数、完走率、skip／完走を単一の`PlaybackEvent`へ確定します。同じセッションの終了通知は一度だけ確定し、lifecycle境界は途中時間をflushするだけです。`AudioPlayerService` が security-scoped file access、AVAudioSession、seek、fade、再生完了 event を所有します。Highlight は `HighlightPlayerStore` が候補・区間を調整しますが、実再生は同じ `PlayerStore` / `AudioPlayerService` を通ります。

再生queueの正本は従来どおり`queue`と`playbackOrder`だが、`PlayerStore`はplayback order変更時にqueue index→order positionの派生indexを再構築する。0.5秒間隔の再生位置更新で評価される`hasNext`／`hasPrevious`はこのindexを使い、長いqueueを毎回線形走査しない。PCM tapはVisual World用mailboxへは従来どおりbounded copyを試みる一方、旧波形／空間メーターの計算とMainActor通知は`AudioInformationView`がactive、またはVisual World解析が有効な場合だけ行う。通常画面・backgroundではatomic gate後にreturnし、音声render経路を待たせない。

USB Audio routeでは`AudioPlayerService`が音源のdecoded processing sample rateをAVAudioSessionの希望値として要求し、activation後の実`sampleRate`とroute名を`PlayerStore.audioInformation`へ返す。`AudioInformationView`は音源と出力を分離し、rate一致時はnative、不一致時はsample-rate conversionありと表示する。希望値はhardwareへのhintであり採用を保証しない。Tea Pro実機では192kHz音源に対して現行AVAudioEngine経路が44.1kHzを採用し、Onkyo HF Playerでは同じ接続と音源で192kHzを採用した。直接PCM出力を試す場合も現行再生基盤を置換せず、独立backendとして検証する。設定は既定ONでApp外backup対象とし、設計理由は[ADR-0007](decisions/ADR-0007-native-sample-rate-output.md)を参照する。

通常再生のアートワーク2面目`AudioInformationView`、3面目`TrackAdjustmentsView`、Highlightの曲情報sheetは、`TrackDetailPresentation`で既存Track metadata、AudioFormat、file identity、TrackFeatureを表示用の項目へ変換する。共通の`TrackDetailGridView`は通常再生のコンパクトなカード内表示を担当し、Highlightは同じ項目をListへ配置する。再生履歴はHighlight sheetとTrack Adjustmentsが`PlaybackHistoryStore`から直接参照する。この表示拡張は新しい永続化、file I/O、音源scan、解析処理を開始せず、再生engineにも依存しない。

「USB DAC 出力レート」は通常再生から分離した次のAudio Queue経路だけを持つ。

```text
HiResDirectOutputProbeView / HiResLibraryView
  ├→ PlayerStore.stop（通常AVAudioEngineの完全停止だけ）
  → HiResDirectOutputProbeStore
  → HiResAudioQueueProbeService
  → Audio File Services → Audio Queue Services → USB DAC
```

設定のオーディオ項目から開く「USB DAC 出力レート」はFilesから選んだ1ファイル、専用ライブラリは登録folderのsecurity-scoped accessでTrackを開き、音源rateをAVAudioSessionへ要求してからAudio Queueへpacketを供給する。一時停止だけでは通常AVAudioEngineが前回rateのI/Oを保持し得るため、開始前に`PlayerStore.stop()`で通常再生を完全停止する。開始処理はsession非アクティブ化後に待機し、希望rateの16-bit stereo無音PCM Audio Queueを最大2回短時間開いてから実音源queueを作る。44.1／48／88.2／96／192kHzは同じ生成処理を音源なしの手動準備にも使う。音源rate、session実rate、`kAudioQueueDeviceProperty_SampleRate`、route名を表示する。

専用ライブラリからの再生はAudio Queueの実開始通知後にだけ履歴sessionを開き、開始元を`hi_res_library`として既存の`PlaybackHistoryStore`／SQLiteへ記録する。停止・曲置換・自然終了・失敗で1件の`PlaybackEvent`へ確定し、再生回数は通常PlayerStoreと同じ「自然終了、または30秒と曲長50%の短い方以上」の条件を使う。自然終了は曲長全体を実聴時間として扱う。これにより再生回数、総再生時間、最近の再生event、Analytics集計へ反映する一方、通常ライブラリの`tracks`を入力とするStation、行動分析による選曲、整理候補、shuffle、音響特徴量には流さない。Track Identityを持たない設定診断は履歴対象外である。通常queueの再生、Now Playing、remote command、EQ、normalization、fade、Visualizer、background制御とは統合しない。Tea Proでrateの上げ下げと初回接続を実機確認し、成立した場合に限り製品用backendへの拡張可否を別段階で検討する。

#### PlayerStoreの段階的な責務分離

Phase 1は完了。`WatchPlaybackCoordinator`はWatch固有の接続・command・状態通知を担当し、`PlaybackHistoryCoordinator`は再生回数の確定記録1件だけを同期委譲する境界である。Queue／Shuffle／Repeat、再生session、Playback Context、Now Playing／Remote Command、Audio Information、曲別Start／End、Normalization、Visualizer用Audio Frameは現在もPlayerStoreが調整する。再生エンジンとAVAudioSessionの実操作は引き続き`AudioPlayerService`が所有する。追加分離は今すぐのTODOとせず、必要になるまでこの構成を維持する。

PlayerStoreが再び肥大化した場合の候補は次の通り。

- `PlaybackHistoryCoordinator`の拡張: 再生開始、聴取時間の保存、終了結果の記録を候補とする。記録の要否・時点、Playback Context、Queue／Shuffleの選曲判断は安易に移さない。
- `VisualAudioBridge`: Audio FrameとVisualizer向けデータの受け渡しを分け、Visualizerの停止・失敗が再生へ影響しない境界を検討する。
- `PlaybackQueueController`: Queue、current index、Next／Previous、Shuffle、Repeatを対象とし、Smart QueueやAuto DJで曲順処理が増えた場合に検討する。既存アルゴリズムの書き換えとは分ける。
- `PlaybackSessionController`: play／pause／stop／seek、曲のload・終了、再生lifecycleとAudioPlayerServiceへのaudio session連携を候補とする。再生中核のため優先度は低く、十分なCharacterization Testを先に用意する。

Crossfade、Smart Queue、Auto DJ、Mood Station、AirPlay、Visualizer連動などの追加で責務が増えた場合、またはテスト可能性が下がり一つの修正が複数責務へ波及するようになった場合に再検討する。ファイルサイズだけを理由に分割しない。再開時は1責務ずつ小さく切り出し、Before／Afterで同じCharacterization Testを実行する。再生挙動の変更や新機能追加と同時に行わず、async／Task／Actor境界を不用意に変えない。Queue、Track End、Shuffle、Repeatは特に慎重に扱い、Build／TestがGreenでない限り次の段階へ進まない。

`HomeView` はホーム代表表示に必要な候補、選択済みTrack、単一artwork identifier、即時再生可否をDestination単位の一時snapshotへまとめます。snapshotはLibrary、Playback History、Track／Album／Artist Favoriteの軽量revision通知時と代表画像の定期更新時だけ再生成し、View再描画中にはLibrary全体を走査しません。同じ候補が有効な間は同じidentifierと同値snapshotを書き戻さず、Tileは候補配列を`task(id:)`で監視しません。表示中の代表Trackは即時再生queueの先頭へ置く契約を維持します。HighlightタイルのランダムArtwork identifierはこれらのDestination snapshotと分離し、表示だけに使う。`ArtworkService`は原Dataに加えてImageIOでdownsample／decodeした`UIImage`をmemory cacheし、画像decodeをMainActor外で行います。decode不能identifierは失敗もcacheし、View再生成時の再試行loopを防ぎます。

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

- ホームのMIXは`HomeView`がLibrary・Playback History・Track Preferenceのrevisionとローカル日付変更時に候補snapshotを作り、`MixSelectionService`がDaily／Rediscovery／My Favoritesの一時キューを構成する。順位計算は3種類で共有し、既存の自動選曲weightと通常シャッフル適格性を使う。Dailyは同じ順位で選ぶMy Favoritesの先頭25曲を後回しにして重複を抑え、他の候補が不足したときだけ補充する。Deep Diveはタイルを開くときに`DeepDiveSelectionService`が履歴の日別再生開始数とArtist／Album metadataから候補を作り、同じ適格性・weightの範囲で低再生曲を選ぶ。従来の3種は先頭Trackをタイルのアートワークと再生開始曲に共用する。キューは保存せず、PlayerStoreへ通常再生として渡す。
- `TrackSearchService` は text field / match mode / AND・OR / 属性条件を組み合わせ、保存検索 playlist の定義にも使われる。Artist条件はTrack ArtistとAlbum Artistの両方を対象にし、Album Artistと年はTrackの各metadataを直接対象にする専用の検索field / 条件も持つ。検索画面は`TrackSearchStore`が225ms debounceとTask cancellationを管理し、専用actorで検索してMainActorには結果だけを反映する。Library、Playback History、Track Preferenceの全配列／Dictionaryそのものではなく各Storeの軽量revisionを変更通知に使い、総再生時間だけの定期保存では再検索しない。保存検索playlistの明示同期も同じactorを使う。
- `StationStore` は通常再生対象かつ特徴量を持つTrackから`StationCandidate`を構成する。`MoodStationService`はSemantic v2のraw headを確率として扱わず、選曲時点の候補Libraryごとに同値をmid-rankで扱うpercentileへ変換し、気分profileと任意の音要素との近さを評価する。特徴値のrangeが小さすぎる軸はノイズを順位として増幅しないようscoreから外し、近さの基準を満たす曲がある気分だけを1問目へ表示する。vocal／instrumental／electronic／ambient／pianoは、対象曲の半数以上に値があり、2曲以上かつ軸ごとの最小rangeを満たすものだけを2問目へ表示し、音要素を指定した場合はその値がない曲を候補にしない。年代metadataはStation候補、質問、scoreへ使用しない。近さの基準を満たしたpoolにだけOverplay補正、小さなjitter、artist分散を適用して最大25曲の一時queueを生成する。
- Mood Mixは`StationStore`の同じ候補snapshotから`MoodStationService`がCalm／Energy／Ambient／Electronicの単一特徴を選ぶ。既存のLibrary内percentile、有効範囲、0.72閾値、Overplay補正、Artist分散を共有し、選んだ特徴のキューを一時的にPlayerStoreへ渡す。永続化契約は変更しない。
- `FavoriteStore` と `PlaylistStore` は専用 persistence service を介し、Track ID で library の曲を参照する。Playlist は regular / work の種別互換性と、正規化・重複排除された複数の表示用tagを持つ。専用tag管理画面の名称変更・削除は全Playlistをmemory上で一括更新して1 snapshotとして保存し、割り当ては既存`setTags`境界へ合流する。曲の追加先選択画面のtag filterはpresentation stateとしてUserDefaultsへregular／work別に保存し、存在しないtagになった場合は解除する。tag編集はTrack ID配列に触れず、再生開始時にPlayerStoreへ渡されたqueue snapshotから独立する。Playlist保存Taskは先行保存の完了後に次のsnapshotを保存し、高速な連続更新でも古いsnapshotが後勝ちしない。
- `PlaybackHistoryStore` は再生回数、正式なPlayback Event、初回／最終再生日時、総再生時間、スキップ／完走、連続再生、リピート再生、manual / automatic、入口別、日別集計を保存する。曲Favoriteと`playbackPreference`の正本は`TrackPreferenceStore`であり、Historyの旧fieldはmigration互換用に限る。分析画面から1曲の履歴をリセットしてもPreferenceは変更しない。
- `RecentMusicTrendsView` は`PlaybackHistoryStore`と`TrackFeatureStore`のロード済みsnapshotを`RecentMusicTrendsService`へ渡す。Serviceは直近1年の完了イベントと存在する0...1の特徴量だけで一時indexを作り、選択期間を6〜13個の時間bucketへ集計する。グラフに空のbucketを接続せず、3曲・5再生以上で表示する。前半・後半の比較は各5再生・3曲以上、説明に出す変化は平均差10ポイント以上とする。派生データは保存せず、期間切り替え時はindexのみをバックグラウンドで再集計する。
- `LibraryCleanupCandidateService` は通常曲と履歴snapshotを読み、終了理由を持つ直近20件までのPlayback Eventを評価する。最低5件、`user_skipped`率50%以上、平均completion ratio 10%以下をすべて満たす曲だけを候補にする。既存`playCount`、直接選択、Good / Badは判定に使わず、終了理由のない旧eventも誤分類防止のため除外する。途中スキップ率降順、次に平均再生率昇順、同数時は最終再生の新しい順に並べ、履歴・評価・飽き度・shuffle非表示を変更しない。
### 再生履歴行動スコアと自動選曲

- Overplayは好き嫌いの評価ではなく、同じ曲の短期的な聴きすぎを一時的に抑え、新しい曲・最近聴いていない曲・ライブラリ内の他の曲を循環させるための派生値である。`PlaybackBehaviorAnalyzer`は保存済み日別集計から、当日を含む直近7日の再生数 `recent` と、その前56日の再生数を8週換算した通常ペース `weeklyBaseline = baseline / 8` を選曲ごとに集計する。
- `OverplayScoring`は `burstRatio = (recent + 1) / (weeklyBaseline + 1)`、`relativeScore = clamp(log2(burstRatio) / 2)`、`volumeScore = clamp((recent - 4) / 8)`、`OverplayScore = clamp(0.6 × relativeScore + 0.4 × volumeScore)` を使う（`clamp`は0...1）。候補表示だけは直近5回以上かつScore 0.5以上を条件とするが、選曲補正には候補閾値を設けず連続値を使う。
- `PlaybackPreferenceWeightPolicy`はユーザーの長期的で明示的なGood / Bad（-10〜+10）を正の基本weight（0.01〜42）へ写像する。一方Overplayは時間で回復する短期補正であり、`multiplier = 1 - 0.875 × OverplayScore²` とする。最終shuffle weightは `Preference weight × multiplier` なので、Favoriteや高Preferenceにも補正が効く。Favorite自体はこのweightへ加点せず、入口や候補集合の構成に使われる。
- multiplierは1.0〜0.125で完全除外しない。軽度のOverplayはほぼ維持し、高い値ほど二次曲線で強く抑える。日別集計を再計算するため、再生が直近7日から外れ、さらに56日のbaseline期間を通過するとScoreが自然に低下し、補正なしの確率へ戻る。派生score／weightは永続化しない。
- Quick Playだけは累計`playCount`の0〜2回を1.0、3〜5回を0.7、6〜9回を0.4、10回以上を0.1とする。Preference weightに掛ける補正はこのcount factorとOverplay multiplierの小さい方を採用し、二重に掛けない。お気に入りとその他を1:1で交互に並べ、最近再生したお気に入りから必要数の最大3倍を候補poolとして重み付き抽選する。その他は全候補から同じ方式で選ぶ。どちらかの群がない場合は全候補から抽選する。再生回数補正は保存せず、他のshuffle入口には適用しない。
- 通常shuffle、Quick Play、Favorite系shuffle、Repeat、Selective Random候補、Genre Randomの選択曲より後、PlayerStoreの自動shuffle order、ハイライトの曲順は、`Track.isEligibleForRegularRandomPlayback`を共通の候補条件とし、30秒未満のベリーショート曲を除外する。30秒ちょうどを含むそれ以上の通常曲は候補とし、ライブラリ表示、検索、Playlist互換性、手動選択・順再生にはこの時間条件を適用しない。各経路は1選曲単位の同じOverplay snapshotを使う。ハイライトは`PlaybackHistoryStore`の通常shuffle eligibilityとPreference × Overplay基本weightだけを共有し、その後の順位付けを`HighlightSelectionPolicy`へ閉じる。アガる／穏やか／発掘は適合度を0.05幅のbandにして第一条件とする。同一bandは選択済み曲列に基づくArtist／Album反復段階、Preference × Overplay × Recent Highlight、直前曲との特徴類似0.97倍、±0.5% Randomの順で貪欲に配置する。多様性は絶対除外せず、異なるmode bandを逆転しない。シャッフルはmode bandと特徴類似を使わない。詳細パラメータと具体例は[Highlight Selection Policy](Documentation/HighlightSelectionPolicy.md)を正とする。未再生Discoveryと作業用再生は各入口の目的を維持するためPreferenceだけを使う。手動選択にも適用しない。
- Mood Stationは純粋なMood scoreでthresholdと候補poolを確定した後、同じOverplay multiplierをrankingにだけ掛け、既存artist減点を続ける。Mood StationはPreference／Favoriteをrankingへ使わない。Preference Driftは候補表示専用のままである。
- PC版Analyticsの「おすすめ」はiOS選曲とは独立したread-only分析である。選択期間内の分析可能な再生1回につき4点、最大24点を推薦scoreから減点し、iOSの7日対56日OverplayScore、二次multiplier、Preference weight表は使用しない。
- 永続化は`PlaybackHistoryPersistenceService` actorから`PlaybackHistorySQLiteRepository`を呼び、`Application Support/MyMusic/playback-history.sqlite3`を正本とする。schema version 2ではevent IDと完走flag、version 3では終了理由`natural / user_skipped / other`を追加する。通常変更は1曲snapshotを1 transactionで渡し、`playback_events`はevent IDによる`INSERT OR IGNORE`でappendし、track／日別／入口別はupsertする。空event snapshotだけが曲別resetの削除境界となる。初回は`PlaybackHistoryMigrationService`が旧JSONを上書きなしの永久backupへcopyし、transaction import後の全Model一致でのみDB metadataとDB外stateを`verified`にする。`PlaybackHistoryBackupService`は起動load時に24時間条件の日次JSON snapshot（7世代）を作る。
- `AnalyticsService` のCSV exportは、運用上の共通契約としてヘッダを `種類,日時,曲名,アーティスト,再生回数,値,詳細` とし、分析データを以下の行種別で出力する。
- `楽曲別再生回数`, `楽曲別再生行動`, `楽曲別再生入口`, `再生傾向評価` はそれぞれTrack別に追加行する。
- `再生履歴` は再生イベントの時系列（日別にグループ化済み）を出力し、`集計` は全体件数（総再生、手動、自動、お気に入り、プレイリスト）を追加する。
- `楽曲別再生行動` は `manual:<数>, automatic:<数>, 7日:<数>, 30日:<数>, 初回:<日時>, 最終:<日時>` を `詳細` 列へ格納し、`楽曲別再生入口` は `入口:回数` をスペース区切りで `詳細` 列へ格納する。
- CSVインポート経路は現時点で未実装のため、上記CSVが現行正規フォーマットとする。
- `MusicDataImportService` / `MusicDataExportService` は playlist、library、history、解析snapshot、設定の JSON / Markdown 等の入出力境界を担う。Preference Importは専用`TrackPreferenceImportService`で外部schema v2を厳格検証してから`TrackPreferenceStore`へ渡す。Playlist tagはversion 1文書の後方互換な追加fieldとして扱い、field欠落時は空tagとする。
- `AnalyticsArchiveExportService`は`MusicDataExportService`が生成したAnalytics対応8種類のJSONを一時directoryへ書き、ZIPFoundation 0.9.20のdeflateで日付付きZIPへまとめる。圧縮はMainActor外で実行し、生成元JSON契約と既存の個別共有経路は変更しない。
- `TrackFeatureStore`は保存済み特徴量をTrack ID順のsnapshotとして提供し、`MusicDataExportService`が全特徴量JSONと、完全なLUFS / True Peak / gainを持つ曲だけの音量ノーマライズJSONへ変換する。これは音源を含まない確認・退避用出力であり、Analyzer schema v1の再Import contractではない。
- `TrackPreferencePersistenceService`は`Application Support/MyMusic/track-preferences.json`を曲Preferenceの正本とする。schema v2 fileがない初回だけ旧Playback HistoryのFavorite／評価を移し、atomic write後のread-back一致を確認する。History読込失敗時は空migrationを確定しない。
- `MusicDataExportService`はTrack ID、`playbackPreference`、`favorite`を安定順でschema v2の`MyMusic-Playback-Preferences.json`へ出力する。Library／History JSONのFavorite fieldは互換目的で新Preference値をミラーするが正本ではない。
- Preference Importは外部JSONを直接永続化せず、`TrackPreferenceImportService`が未知fieldを含む構造、schema、日時、UUID、重複、値範囲、BoolをStore変更前に全件検証する。`TrackPreferenceStore`は現在LibraryのTrack IDだけを既存snapshotへmergeし、`TrackPreferencePersistenceService`のatomic保存成功後にのみmemory stateへ反映する。未収録Trackは作成せず、JSONにない既存Preferenceは維持する。
- Library JSONはidentity registryに保存済みのFingerprintだけをoptional `audioFingerprint`として出力し、Export操作自体では音声を読まない。Analyticsは64文字のlowercase SHA-256として検証・保存するが、v0では別Track IDの自動統合は行わない。
- AnalyticsのLibrary tableは後方互換なoptional列として`relative_path`／`file_size`を持つ。Track Featuresの`sourceIdentity`は既存どおり`source_records.raw_json`を正とし、Analytics内の`TrackFeatureResolver`がLibrary／Features Import後にTrack ID完全一致を優先して再解決する。救済は本体と同じpath優先、file size完全一致、duration差0.5秒以内、fallback metadata一致かつ一意候補に限定し、fingerprintは必須にしない。
- 同Serviceの`MyMusic-Playback-Events.json`は保存済みPlayback EventをAnalytics schema v1へ写し、Libraryから曲名、Artist、Album、曲長を補完する。イベントID、再生日時、実聴秒数、完走／Skip、入口、選択種別は保存値を使用し、保存していないsession IDは出力しない。現在のLibraryでTrack IDを解決できないeventは必須metadataを安全に補えないため出力対象外とする。
- EQ文書は現在の`EqualizerSettings`とcustom preset、ジャンル文書は順序付き`GenreDisplayPreset`を、それぞれ`kind`とversionを持つ別JSONとして扱う。`MusicSettingsImportService`が種類、version、有限値、EQの範囲・バンド数、重複名／IDをStore変更前に検証する。Storeは同名presetを更新し新規presetを追加してUserDefaultsへ保存するため、対象外の既存presetは削除しない。

## Apple Watch リモコン

`MyMusicWatch/NowPlayingView` → `WatchSessionManager` → WatchConnectivity → iPhoneの`WatchConnectivityService` → `WatchPlaybackCoordinator` → `PlayerStore` → `AudioPlayerService` の一方向の操作経路とする。WatchはPlayerStore、queue、再生処理を複製しない。Coordinatorは通信callback、Preference操作、Watch向け状態生成・通知を接続し、再生エンジンを所有しない。PlayerStoreへの操作callbackは弱参照で渡し、Watch Shuffleの選曲・再生処理は引き続きPlayerStoreに置く。

通信契約は`WatchPlaybackMessage`に集約し、commandとversion付きの再生状態をProperty List互換dictionaryへ変換する。iPhoneの`PlayerStore`と`TrackPreferenceStore`だけが状態の正本であり、Watchのボタン操作では楽観的に表示状態を変更しない。iPhoneは到達中の即時messageに加え、最新状態を`updateApplicationContext`へ保存するため、一時的な非到達から復帰したWatchも同期できる。version 1 stateへ追加したfavorite／preference／Artwork有無はoptional decodeとし、旧version 1 payloadを維持する。

Artwork本体はstateへ含めず、現在TrackのArtwork identifierだけを含める。WatchはTrack IDまたはidentifierが変わると保持画像を破棄して要求し、`WatchArtworkPreparationService` actorが既存`ArtworkService`のデータをアスペクト比を維持した最大512px・JPEG品質0.82へ変換する。元画像の最大辺が512px未満なら拡大しない。iPhoneの`WatchConnectivityService`は同じ画像の転送中要求をまとめ、一時fileを`transferFile`し、完了時に削除する。Track変更時は古い転送を取り消す。Watch側は30秒以内に画像を受け取れなければ最大3回まで再要求し、到達性復帰時も要求済み状態を解除する。送信管理keyとfile metadataはTrack IDとArtwork identifierを組み合わせ、古い画像を現在曲へ適用しない。Watchは現在Track分だけをmemoryに保持し、永続cacheを増やさない。Artwork失敗はstate／command経路へ影響させない。

Watchの音量操作は`CompanionVolumeControl`がWatchKit標準`WKInterfaceVolumeControl`の`.companion` sourceをSwiftUIへbridgeする。これはペアリング中iPhoneのシステム出力音量をDigital Crownで制御する経路であり、`PlayerStore`、`AudioPlayerService`の内部mixer gain、WatchConnectivity契約は変更しない。画面をscroll containerにせず、volume controlを明示選択した時だけCrown focusを得る。

`NowPlayingView`は背景と前景に別の`GeometryReader`を使う。背景側だけをSafe Area外へ拡張し、そのfull-screen sizeをArtworkとcontrast overlayの共通containerへ一度だけ指定する。前景側はwatchOSが提案するSafe Area内sizeだけで、右上の詳細／小型音量、曲名／Artist、Favorite／Good／Bad、1pt進捗、最下部の44〜52pt再生操作を配置する。右上のshuffleボタンは`WatchShuffleView`の3種類一覧を1アクションで開く。

Shuffleは`WatchShuffleKind`のversion 1 message（normal／favorites／unplayed）を即時送信する。`WatchConnectivityService.shuffleHandler` → `PlayerStore.startRemoteShuffle`で、Appから接続された最新Libraryと既存History／Preferenceを参照する。通常・お気に入りは`preferenceWeightedShuffle`、未発見再生は`discoveryPlayTracks`（最大30曲・Preferenceのみ）をそのまま呼ぶ。生成済み順序を再shuffleしないようqueue shuffleをOFFにして`playQueue`へ渡す。対象なし・読込未完了なら現queueを変更しない。既存playback taskの完了を待ち、request IDと再生状態を確認して、再生stateに`shuffleSucceeded`／`shuffleError`を添え返信する。Watchは返信成功時のみsheetを閉じる。通信不能時の遅延再生を避けるためcommandをapplication contextやuser infoへ蓄積しない。

## 永続化

server / database migration はありません。端末内の file と UserDefaults が保存境界です。

App外バックアップは`ExternalBackupView` → `ExternalBackupService`の経路に限定する。外部フォルダは正本ではなく2世代snapshotであり、manifest付きstagingを完全検証した場合だけrotationする。Restoreは実行中のStoreやWAL databaseを置換せず、Application Supportと同じvolumeのpending directoryへ準備し、次回`MyMusicApp.init`のStore生成前にatomic swapする。音楽フォルダbookmarkは権限再取得が必要なため対象外とし、復元したTrack Identityと再scanでTrack ID参照データを再接続する。

| データ | 主な所有者 | 保存形態 / 場所 |
| --- | --- | --- |
| Library folder access | `FileImportService` | UserDefaults の security-scoped bookmark |
| Folder scan cache | `LibraryPersistenceService` | Application Support 内 JSON |
| Stable Track identity | `TrackIdentityService` | Application Support 内 JSON |
| Artwork / highlight | `ArtworkService` / `HighlightRepository` | Caches 内 file / JSON |
| Track preferences / playlists / あとで聴く / playback history | 各 PersistenceService | `track-preferences.json` / `playlists.json` / `listen-later.json` / `playback-history.sqlite3` |
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

Trackの`firstSeenAt`はMyMusicが論理Trackを初めてscanで確認した絶対時刻である。1 scanで共通の基準時刻を新規Trackへ設定し、再scanやmetadata更新では維持する。旧cache／旧identity Recordは推測せず`nil`（不明）のままとする。Track IDを移動照合で復元した場合はidentity registryから同値も復元し、失敗・cancelしたscanのregistry変更はrollbackする。詳細は[Track firstSeenAt](Documentation/TrackFirstSeenAt.md)を参照する。

曲別調整は解析JSONへ書き戻さず、端末ユーザー固有データとしてStable Track ID単位のsharded JSONへ保存する。全曲DictionaryをUserDefaultsへ載せず、アクセスした曲だけを遅延loadし、頻繁な位置更新でも他曲の設定ファイルを書き直さない。field欠落は`TrackPlaybackAdjustment`の安全な初期値でdecodeする。

## Build, tests, delivery

PC版AnalyticsのDesktop Betaは`analytics/desktop.py`がOS別Application Data配下の`Settings`を生成し、空きloopback socket上で既存FastAPI appをbackground threadとして起動してpywebviewへ渡す。Desktop sessionだけは起動ごとのtoken cookieを必須とし、同一PC上の別processからの無認証API操作を拒否する。Window event loopの終了後はuvicornへ終了を通知してthreadをjoinする。Windows packageはPyInstaller、macOS packageはpy2appを使い、`analytics/web/`をread-only resourceとして同梱する。既存のbrowser起動版と静的Web版の保存境界・起動方法は変更しない。

Local／Desktop版の表示倍率は`analytics/web/zoom.js`だけが所有するpresentation stateである。許可した倍率をCSS `zoom`としてdocument rootへ適用し、local storageへ保存する。pywebviewは永続Web storageを有効にするが、FastAPI session tokenは起動ごとに再生成する。倍率変更はAPI request、SQLite、集計query、Import／Export contractへ影響させない。静的公開版はブラウザメモリ限定方針を維持するため、この永続設定を共有しない。

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
