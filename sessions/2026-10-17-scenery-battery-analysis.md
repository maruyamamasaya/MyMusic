# 車窓モードの短時間電力比較・分析結果 — 2026-10-17

## 結論

今回取得した短時間データでは、車窓モードは通常再生よりMyMusicのCPU Power Impactが高い。温度状態の悪化は観測されなかった。ただしUSB充電中のため端末全体の消費率が0と記録され、実際のバッテリー消費増加量は判定できない。電池への影響なし・軽微とは結論しない。計測データの分析は完了し、非充電での再測定は残る検証とする。

## 測定条件と結果

- Vespera（iPhone 17e）、iOS 26.6.2、現在のDebug版MyMusic。Power Profilerを実行中のMyMusicへattach。
- ユーザーに各モードの再生中状態を確認。車窓→通常の順で各30秒の記録を要求。
- USB充電接続を維持。画面輝度26%。音量・輝度は変更しないよう依頼。
- 各条件1回のみ。素材の解像度・codec・durationと曲の同一性は個別記録していない。

| 指標 | 通常再生 | 車窓モード |
| --- | --- | --- |
| trace実時間 | 31.33秒 | 31.49秒 |
| CPU Power Impact | 約0.10 | 約0.35 |
| Display Power Impact | 2.0 | 2.0 |
| thermal state | 全期間Fair | 全期間Fair |
| System Power Usage | 全31sampleで0%/hr | 全31sampleで0%/hr |

CPUの値は電力影響の相対スコアで、WやCPU使用率やバッテリー消費率ではない。約0.25のスコア増加を電池消費3.5倍と解釈しない。Display Power Impactが同値でも、8%の黒overlayの節電効果を検証したことにはならない。暗幕の有無を比較する試験はしていない。FairはInstrumentsで観測したラベルであり、表面温度の実測ではない。

最初の通常再生traceはUSB抜き差しに伴う充電接続の変化があったため除外した。安定記録のCPU値はProcessSubsystemPowerImpactの有効CPU sampleをdurationで加重平均した。

## Offlineの切り分けと復旧

CoreDevice／devicectlとXcodeのDevicesはVesperaを認識したが、InstrumentsのMobileDevice session開始は`kAMDNotConnectedError`（0xe800000b）で失敗した。Instrumentsの初回What's New完了、XcodeのDevices表示後にxctraceでもOnlineへ復旧し、ユーザーもUSBを再接続した。失敗箇所は特定したが、どの操作が単独で復旧したかと根本原因は断定していない。pairing削除・署名変更・セキュリティ緩和はしていない。

## 根拠と再確認

- 通常: `/tmp/mymusic-power-normal-stable.trace`、`/tmp/mymusic-power-normal-stable-data.xml`
- 車窓: `/tmp/mymusic-power-scenery-stable.trace`、`/tmp/mymusic-power-scenery-data.xml`
- 元trace／XMLは一時領域のみで、Gitには含めない。長期保存された生データではないため、再現時は再採取が必要。
- [Apple Power Profiler](https://developer.apple.com/documentation/xcode/measuring-your-app-s-power-use-with-power-profiler)と[WWDC25](https://developer.apple.com/videos/play/wwdc2025/226/)のSystem Power Usage／アプリ別impact scoreの区別に沿って解釈した。

非充電・同じ動画区間／音楽／輝度で比較する検証と、長時間の発熱・電池消費は未実施。今回の依頼の区切りでは、取得済みデータの分析と未判定範囲を記録してコミットする。
