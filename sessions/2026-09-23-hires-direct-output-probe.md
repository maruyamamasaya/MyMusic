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
