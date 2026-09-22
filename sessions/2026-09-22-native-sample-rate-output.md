# 2026-09-22 USB DAC native sample rate output

## 作業

- 再生中のオーディオ情報面を音源／出力へ分割し、実出力先名、PCM rate、native一致／sample-rate conversionありを表示した。
- JEITAのCD相当超過例を純粋な判定関数として実装し、lossless音源へ独自テキストのHi-Res／Lossless badgeを追加した。日本オーディオ協会の公式ロゴは使用していない。
- 設定「音源レート優先」を既定ONで追加し、USB Audio routeで音源のprocessing sample rateをAVAudioSessionへ要求するようにした。resumeとroute changeでも再適用し、実際に採用されたsession sample rateをPlayerStoreへ通知する。
- ALACのASBDでbitsPerChannelが0の場合、Apple Lossless format flagから16／20／24／32bitを復元するようにした。
- 設定をUserDefaultsとApp外backup対象へ追加した。

## 検証

- generic iOS Debug build: `BUILD SUCCEEDED`。
- Simulator selected tests: 4件成功。Hi-Res境界、native／converted判定、設定の既定値と永続化、Khadas Tea Pro／96kHzを含む360ptカード描画を確認した。
- Vespera（iPhone 17e）向けDebug実機build、install、launch成功。project `MyMusic.xcodeproj`、scheme／product `MyMusic`、Bundle ID `maruyama.MyMusic`、UDID `00008150-000C54280E33401C`。
- 初回のiPhone Simulator buildは既存Watch AppのAppIcon資産がSimulator向けに適用できず失敗。generic iOS buildでは今回のSwift変更を含め成功した。
- XCTestDevicesは開始前／終了後とも新規UUID folderなし、合計12K。

## 未確認

- Khadas Tea Pro実機での44.1／48／88.2／96／192kHz採用結果。今回Vesperaへの導入までは完了したが、DACと音源を操作する手動確認は未実施。
- 再生中のDAC接続、取り外し、再接続、background復帰、異なるrateの連続曲切替での音切れ・pop・停止状態。
- EQ／normalization／fadeを使うためbit-perfectは保証しない。目標は音源rateを維持したPCM出力である。
