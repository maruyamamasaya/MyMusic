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
- 実機へのbuild、install、launchはこの作業時点では実行していない。

## 次の判定

1. Vesperaへ明示的にdeployする。
2. 通常再生を停止し、Tea ProをUSB接続して同じ192kHz／24bit ALACを診断画面から再生する。
3. 画面のAudio Queue rateとTea Pro本体表示がともに192kHzなら、停止、route変更、rate切替を確認してから製品用backendの設計へ進む。
4. 44.1kHzのまま、再生不能、または不安定なら、このbranchを破棄して通常再生基盤を維持する。
