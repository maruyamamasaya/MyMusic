# 2026-09-22 USB DAC native sample rate output

## 作業

- 再生中のオーディオ情報面を音源／出力へ分割し、実出力先名、PCM rate、native一致／sample-rate conversionありを表示した。
- JEITAのCD相当超過例を純粋な判定関数として実装し、lossless音源へ独自テキストのHi-Res／Lossless badgeを追加した。日本オーディオ協会の公式ロゴは使用していない。
- 設定「音源レート優先」を既定ONで追加し、USB Audio routeで音源のprocessing sample rateをAVAudioSessionへ要求するようにした。resumeとroute changeでも再適用し、実際に採用されたsession sample rateをPlayerStoreへ通知する。
- ALACのASBDでbitsPerChannelが0の場合、Apple Lossless format flagから16／20／24／32bitを復元するようにした。
- 設定をUserDefaultsとApp外backup対象へ追加した。
- Tea ProをUSB接続して192kHz音源を再生しても実出力が44.1kHzだったため、session非アクティブ化とAVAudioEngine graph再構築を試した。しかし実機出力は44.1kHzのままで効果がなく、既存再生基盤への影響を避けるため実装を撤回した。

## 検証

- generic iOS Debug build: `BUILD SUCCEEDED`。
- Simulator selected tests: 4件成功。Hi-Res境界、native／converted判定、設定の既定値と永続化、Khadas Tea Pro／96kHzを含む360ptカード描画を確認した。
- Vespera（iPhone 17e）向けDebug実機build、install、launch成功。project `MyMusic.xcodeproj`、scheme／product `MyMusic`、Bundle ID `maruyama.MyMusic`、UDID `00008150-000C54280E33401C`。
- 初回のiPhone Simulator buildは既存Watch AppのAppIcon資産がSimulator向けに適用できず失敗。generic iOS buildでは今回のSwift変更を含め成功した。
- XCTestDevicesは開始前／終了後とも新規UUID folderなし、合計12K。
- 上記の再交渉修正後、generic iOS Simulator Debug buildは`BUILD SUCCEEDED`。hardware依存のため追加XCTestは実行していない。
- 再交渉修正版をVespera（iPhone 17e、UDID `00008150-000C54280E33401C`）へDebug実機build・install・launchし、すべて成功した。project `MyMusic.xcodeproj`、scheme／product `MyMusic`、Bundle ID `maruyama.MyMusic`。事前確認はCoreDeviceService初期化timeoutで一度失敗したが、再確認では端末を正常認識した。
- 同じVespera、Tea Pro、USB接続、192kHz音源をOnkyo HF Playerで再生すると、Tea Pro本体は192kHzを表示した。端末、DAC、ケーブル、音源ではなく、MyMusicの現行AVAudioEngine経路に原因があると切り分けた。
- 効果のなかった再交渉コードを撤回し、既存再生基盤へ戻した基準状態でgeneric iOS Simulator Debug buildが`BUILD SUCCEEDED`。追加XCTestは実行していない。

## 未確認

- 分離した直接PCM出力backendで、Khadas Tea Proが44.1／48／88.2／96／192kHzを音源に追従できるか。現行AVAudioEngine backendは192kHz音源を44.1kHzで出力する。
- 再生中のDAC接続、取り外し、再接続、background復帰、異なるrateの連続曲切替での音切れ・pop・停止状態。
- EQ／normalization／fadeを使うためbit-perfectは保証しない。目標は音源rateを維持したPCM出力である。
