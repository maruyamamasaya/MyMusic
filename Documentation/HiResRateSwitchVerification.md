# Hi-Res Beta rate切替の実機確認

2026-10-07。対象は独立Audio Queueのrate準備／実曲開始のみ。通常backend、専用queueの選曲、履歴、Now Playing、EQ、normalizationの統合追加は行わない。

## 実装で確認する境界

旧実曲queueを同期stop／disposeし、キャンセルした準備taskの終了を待ってから次の準備を始める。無音queueが生きている間はstopからsessionをdeactivateしない。準備taskのキャンセル／失敗では無音queueをdeferで同期stop／disposeした後、sessionをdeactivateする。

各準備はdeactivate → 300ms（2回目160ms）待機 → category／preferred sample rate設定 → activate → 無音PCM queueをprime／start → 90ms後のhardware rate取得 → 同期stop／disposeを2回行う。最後のsessionはactiveのまま実曲queueを作成する。待機時間は従来値でありDACの完了保証ではない。無音PCMは16-bit stereoで、実曲のbit depth変更を意味しない。

## Vespera／Khadas Tea Pro

Bluetoothを無効にしUSB接続する。iOS／アプリrevision、接続条件、音源のcodec・rate・bit depthを記録する。

1. 初回接続から192kHz／24bit ALACを再生し、既存成功条件を再確認する。
2. 診断の手動準備で44.1 → 48 → 88.2 → 96 → 192kHz、その逆順を確認する。
3. 44.1 → 192 → 44.1 → 192kHzを確認する。続いて各rateの実音源を同じ順で再生し、実曲開始後の出力も確認する。手動準備だけで実曲成功とは扱わない。
4. 準備中に停止し、すぐ別rateを準備／再生する。古い要求が再開しないこと、エラーや音切れが残らないことを確認する。
5. 共有Hi-Resの準備中に通常曲の開始／再開を要求し、解放後に通常再生が継続することを確認する。Files診断の準備中に画面を閉じて通常曲を開始する場合も確認する。待機中に通常再生を停止した場合は、あとから再生が始まらないことを確認する。
6. USBを一度外して接続し直し、初回rateを44.1kHzにして両方向を再確認する。

各操作で以下を記録する。無音は短いためTea Pro表示を動画で記録すると比較しやすい。

| 観測 | 記録する値 |
| --- | --- |
| 音源／手動準備 | source／requested rate |
| Session | preferred rateと実sampleRate（希望と実測を区別） |
| 無音queue 1回目／2回目 | hardware rateと取得OSStatus |
| 実曲queue | 開始直後のhardware rate、画面の更新後のrate |
| DAC | Tea Pro本体表示と表示が変わった時刻 |
| Route | portName、portType（USB接続か） |

MacのConsoleで接続したVesperaを選び、subsystem `MyMusic`、category `HiResRateSwitch`を絞り込む。ログのtimestampと`request` IDで、`deactivated` → `activated` → hardware読取 → queue cleanup → `warm-up-1-disposed`、2回目、`prepared`または`real-queue-measured`を追う。cleanupのstop／disposeは0がnoErr。queue=0は未取得を意味し0Hzの実出力ではない。deactivate失敗、hardware読取失敗、停止／解放失敗も保存する。失敗時のcleanupは可能な範囲で実行し、ログだけで解放成功とは扱わない。

成功条件は実曲の音源rate、session実rate、実曲queueのhardware rate、Tea Pro表示の一致。warm-upの一致、build成功、Simulator test成功だけでは実機切替成功としない。rate一致もPCM sample値や24bitのbit-perfect保証ではない。

## 未検証

2段階warm-upが全rate／上下両方向でTea Proの再交渉を成立させるか、90msの観測でrateが安定するか、初回USB接続と長時間再生の挙動は実機確認が必要。
