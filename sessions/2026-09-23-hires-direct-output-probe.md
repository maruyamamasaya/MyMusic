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
