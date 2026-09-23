# 2026-09-23 Hi-Res direct output probe

## 背景

- VesperaとKhadas Tea ProをUSB接続し、192kHz／24bit ALACを現行MyMusicで再生すると実出力は44.1kHzだった。
- 同じ端末、DAC、ケーブル、音源をOnkyo HF Playerで再生するとTea Pro本体は192kHzを表示した。iOSやTea Proの一律制約ではなく、MyMusicのAVAudioEngine経路に起因すると切り分けた。
- 現行再生基盤への影響を避け、失敗時にbranchごと撤退できる独立PoCとした。

## 作業

- `codex/hires-direct-output-beta` branchにAudio Queue Servicesを使う単曲再生診断を追加した。
- Filesから選んだ音源をAudio File Servicesで開き、magic cookieとpacket descriptionを保持したままAudio Queueへ供給する。
- 音源sample rateをAVAudioSessionへ希望値として設定し、音源rate、session実rate、Audio Queue hardware rate、route名と接続種別を診断画面へ表示する。
- 設定のBeta機能から診断画面へ遷移できるようにした。
- `PlayerStore`／`AudioPlayerService`、通常queue、履歴、Now Playing、EQ、normalization、fade、Visualizer、background再生には接続していない。

## 検証

- generic iOS Simulator Debug build: `BUILD SUCCEEDED`。
- hardware依存の仮説検証が目的で、音源fixtureもないためXCTestは実行していない。
- Vespera（iPhone 17e、UDID `00008150-000C54280E33401C`）向けDebug実機build、install、launch成功。project `MyMusic.xcodeproj`、scheme／product `MyMusic`、Bundle ID `maruyama.MyMusic`、Development Team `U29GY347DY`。

## 次の判定

1. 初回はTea ProへBluetooth A2DPで接続され、音源192kHzに対してAVAudioSessionとAudio Queueはいずれも44.1kHzだった。ケーブル接続中でもrouteの`portType`が`BluetoothA2DPOutput`だったため、有線試験としては無効と判定した。
2. Bluetoothを無効にしてTea Proを有線接続し直すと、routeの`portType`は`Headphones`、route名は`Tea Pro`となった。同じ192kHz／24bit ALACで音源、AVAudioSession、Audio Queue、Tea Pro本体表示がすべて192kHzで一致し、再生音も正常だった。
3. Audio Queue経路でネイティブsample rate出力が成立する仮説は実機で確認できた。音質向上の印象は、Bluetooth codecと44.1kHzへのsample-rate conversionの両方を除いた結果である可能性があり、客観的な聴感比較ではない。
4. 次段階では通常再生を置換せず、停止、route変更、44.1／48／88.2／96／192kHz切替を先に確認し、その後に製品用backendの範囲を設計する。

## レート切替の追試

- 同じ有線接続中に44.1→192kHz、192→44.1kHzの順で診断音源を替えると、Audio SessionとAudio Queueが最初のhardware rateを維持する問題を確認した。音源rateと出力rateが不一致になるため、機器を傷める問題ではないがnative-rate出力にはならない。
- 通常プレイヤーの一時停止は`AVAudioPlayerNode`だけを止め、`AVAudioEngine`自体は動作を続ける。これが共有AVAudioSessionの前回hardware rateを保持する可能性があるため、診断開始時に`PlayerStore.stop()`で通常engineを完全停止するようにした。
- 診断Serviceが従来無視していた`AVAudioSession.setActive(false)`の失敗を呼び出し元へ返すようにした。Audio Queueを破棄し、session非アクティブ化、希望rate設定、再アクティブ化、新Audio Queue作成の順序を検証可能にした。
- 修正版はgeneric iOS Simulator Debug buildで`BUILD SUCCEEDED`。XCTestは実行していない。Vespera向けDebug実機build、install、launchも成功。44.1↔192kHzのrate切替再確認は未実施。

### 途中選曲を含む再追試

- 通常AVAudioEngineを完全停止する修正版でも、再生途中に別rateの音源を選ぶと最初のhardware rateが維持された。Audio Queueの即時停止・破棄とAudio Sessionの再アクティブ化を同じ同期処理内で連続実行するだけでは、USB hardware側のstream解放完了を待てていないと判断した。
- `play`をasync化し、旧queue破棄とsession非アクティブ化後に300msのcancel可能な待機を追加した。途中でさらに音源を選んだ場合は先行requestをcancelし、AudioFileとsecurity scopeのcleanup完了後に最新requestだけを開始する。
- 切替待ち中は「出力レートを切替中」と表示し、停止操作で待機もcancelする。generic iOS Simulator Debug buildは`BUILD SUCCEEDED`。XCTestは実行していない。Vespera向けDebug実機build、install、launchも成功。実機rate切替確認は未実施。

### 手動切替への変更

- 300msの非同期解放待ちを含む版でも、曲の途中に次の異なるrateを選ぶ自動切替は成立しなかった。ユーザー判断により再生中のrate切替機能は撤回し、停止を明示的な出力session境界とする。
- 再生中、切替準備中、file読込完了後は「音源を選んで再生」を無効化する。「停止」はAudio Queueを即時停止・破棄し、security scopeを閉じ、AVAudioSessionを非アクティブ化したまま維持する。次回の音源選択時に新しい希望rateでsessionとqueueを作る。
- generic iOS Simulator Debug buildは`BUILD SUCCEEDED`。XCTestは実行していない。手動方式のVespera向けDebug実機build、install、launchも成功。手動rate切替の実機確認は未実施。

### 内蔵PCM準備と専用ライブラリ

- Tea ProはApp再起動後にrateが変わり、初回streamが不安定、192kHzを採用した後に44.1／48kHzへ戻らないという追加実測があった。
- 音源fixtureへ依存せず再交渉できるよう、44.1／48／88.2／96／192kHzの16-bit stereo無音PCMをメモリ生成し、実曲前に最大2回だけ短いAudio Queueで流すrate準備を追加した。設定診断と専用画面から手動準備もできる。
- Metadata scanをstream-level形式取得へ更新し、ALAC／AACをcontainer拡張子ではなくformat IDで識別し、sample rate、bit depth、channel、bit rateをTrack cacheへ保存する。metadata revision 2により旧cacheは次回scanで再抽出する。
- ジャンル項目「ハイレゾ」または既存JEITA基準を満たすロスレス音源を通常ライブラリから分離し、ホームへ専用タイル、曲名／アルバム／アーティスト一覧、独立Audio Queue再生を追加した。作業用BGMとの重複は作業用を優先する。
- generic iOS Simulator Debug build成功。iPhone 17e / iOS 26.5 Simulatorで分類と通常ライブラリ分離のXCTest 4件成功。XCTestDevicesは開始前後ともUUID folder 0件、合計12KBで、新規test端末の作成・削除なし。
- Vespera（iPhone 17e、UDID `00008150-000C54280E33401C`）向けDebug実機build、install、launch成功。project `MyMusic.xcodeproj`、scheme／product `MyMusic`、Bundle ID `maruyama.MyMusic`、Development Team `U29GY347DY`。
- Tea Proでの初回接続と44.1／48／88.2／96／192kHz上下切替、専用一覧からの実音源再生は未検証。

### 専用再生のPlayback History連携

- 専用ライブラリからAudio Queueで再生した実績を、既存の`PlaybackHistoryStore`／SQLiteへ開始元`hi_res_library`として記録するようにした。設定のFiles診断はTrack Identityがないため履歴対象外のままとした。
- Audio Queueの実開始通知後にだけ履歴sessionを開始し、停止・曲置換・自然終了・失敗で`PlaybackEvent`を確定する。自然終了または30秒と曲長50%の短い方以上を再生回数へ加算し、実聴時間と完走／skipも既存Analyticsへ渡す。
- ハイレゾ曲は通常ライブラリから分離したまま維持し、Station、行動分析による選曲、整理候補、shuffle、音響特徴量へは組み込まない。
- generic iOS Simulator Debug buildは`BUILD SUCCEEDED`。iPhone 17e / iOS 26.5 Simulatorで手動停止と自然終了のPlayback History XCTest 2件が成功した。
- XCTestDevicesは開始前後ともUUID folder 0件、合計12KBで、新規test端末の作成・削除はなかった。
- Audio Queueが通知できない強制終了時の途中履歴flushと、専用再生のbackground制御はこのBetaの対象外。実機デプロイと実音源でのAnalytics表示確認は未実施。

### 利用者向け名称と設定導線

- 実機で内蔵無音PCMによるrate準備が成立したため、利用者向け名称を「Hi-Res直接出力 Beta／診断」から「USB DAC 出力レート」へ変更した。
- 設定の「Beta機能」から「オーディオ」へ移し、44.1／48／88.2／96／192kHzの無音PCM準備、Files音源の直接再生、実出力rate確認を同じ画面で利用できるようにした。
- 内部type名と独立Audio Queue backendは維持し、通常AVAudioEngineの再生経路は変更していない。
- generic iOS Simulator Debug buildは`BUILD SUCCEEDED`。名称・設定導線変更のためXCTestは追加実行していない。
- Vespera（iPhone 17e、UDID `00008150-000C54280E33401C`）向けDebug実機build、install、launch成功。project `MyMusic.xcodeproj`、scheme／product `MyMusic`、Bundle ID `maruyama.MyMusic`、Development Team `U29GY347DY`。

### ハイレゾ専用Now Playing

- 専用ライブラリから曲を選ぶと「ハイレゾ再生中」を表示し、通常Now Playingに近いアートワーク、曲情報、お気に入り、あとで聴く、進捗、再生／一時停止、15秒移動、前後曲を提供する。
- Audio Queueへpause／resume／seek／再生時刻取得／終了検知を追加し、選択した一覧を専用queueとして保持する。自然終了時は次曲へ進み、一時停止中の時間はPlayback Historyの実聴時間へ加算しない。
- アートワークのタップで音源形式、sample rate、bit depth、実出力先、Audio Session rate、Audio Queue hardware rate、native／変換あり、曲metadataを表示する。
- 既存EQは通常AVAudioEngineの`AVAudioUnitEQ`でありAudio Queue直接出力には作用しない。専用画面では非適用を明示し、通常再生用EQ設定への導線だけを置いた。
- generic iOS Simulator Debug buildは`BUILD SUCCEEDED`。iPhone 17e / iOS 26.5 SimulatorでPlayback History、pause中の時間除外、専用queueの次曲移動を含むXCTest 4件が成功した。
- XCTestDevicesは開始前後ともUUID folder 0件、合計12KBで、新規test端末の作成・削除はなかった。実機デプロイとTea Proでの操作確認は未実施。

### シーク位置が先頭へ戻る問題

- ALACなど`mFramesPerPacket == 0`になり得る可変packet音源では、従来の時刻からpacket番号への単純計算が成立せず、シーク先をpacket 0へ戻していた。
- Audio File Servicesの`kAudioFilePropertyFrameToPacket`でframeからpacketへ変換し、変換不能時だけ固定frames-per-packet計算、推定duration比率の順でfallbackするようにした。
- generic iOS Simulator Debug buildは`BUILD SUCCEEDED`。hardwareと実音源に依存するためXCTestは追加していない。Tea ProとALAC実音源で、途中位置へのシークが先頭へ戻らず継続することは未検証。
