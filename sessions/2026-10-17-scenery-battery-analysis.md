# 車窓モードの短時間電力比較・分析結果 — 2026-10-17

## 結論

非充電で追加計測できた。輝度25%・各30秒の記録のうち5〜30秒で、端末全体の推定消費率は通常約7.5%/hr／車窓約9.9%/hr。車窓で約2.3ポイント/時高かった。CPU Power Impactも通常約0.03／車窓0.10へ増加したが、thermalは両方Fair、アプリの通信量カウンターは0だった。

通常再生は、この短時間観測ではCPUの大きな持続負荷・thermal悪化・アプリ通信量の増加を観測しなかった。アプリ全機能や長時間の電池持ちが良好だと保証する検証ではない。端末全体消費は背景処理も含み、各条件1回の短いDebug計測なので差の再現性・長期平均は未確認。以下のUSB測定に加え、末尾に非充電の最終結果を記録する。

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

USB計測時点では非充電比較は未実施だったが、後述の追加計測で実施できた。同じ動画区間／音楽への固定と長時間の発熱・電池消費の検証は引き続き未実施。


## 非充電・無線での最終比較 — 2026-10-17

コミット・デプロイ完了後にユーザーからUSB取り外しと通常再生の返信が届いたため、同じデプロイ済みコードのまま検証を継続した。通常再生そのものの負荷確認も依頼された。通常→車窓の各状態をユーザーに確認し、無線Power Profilerを各30秒実行。車窓の名前指定attachは失敗したが、動作中の実PIDへ指定し直して成功した。

| 指標 | 通常再生 | 車窓モード |
| --- | --- | --- |
| trace実時間 | 31.85秒 | 31.73秒 |
| 比較区間 | 開始後5〜30秒 | 開始後5〜30秒 |
| System Power Usageの区間平均 | 約7.52%/hr | 約9.85%/hr |
| CPU Power Impactの区間平均 | 約0.029 | 0.100 |
| CPU Power Impact最大（全期間） | 1.0 | 0.1 |
| Display Brightness | 25% | 25% |
| Charger Connectedの記録行 | 0 | 0 |
| thermal state | 全期間Fair | 全期間Fair |
| process bytesカウンター4列の合計 | すべて0 | すべて0 |

計測開始直後を避け、同じ5〜30秒の区間を切り出した。XMLのid/refを解決し、各rowの開始・durationで区間を積分して時間加重平均した。重複区間は後から始まった値を優先する。両方とも比較対象区間は約25秒分得られた。全有効区間での平均も通常7.94%/hr・車窓10.03%/hrで、増加方向は同じ。

推定消費率の差は約2.34ポイント/時。ただし30秒記録からのrateで、1時間実際に再生して7.52%／9.85%減ったという結果ではない。動画区間・曲を同一に固定した測定ではなく、OSの背景処理、無線プロファイル、Debug版の影響も含む。通常再生の最大CPU score 1.0は平均0.029に対して一時的で、持続的な高負荷は今回観測されなかった。通信量0はこのtraceのMyMusic用カウンター上の結果であり、端末全体の通信なしを意味しない。

8%暗幕の節電効果は、暗幕有無の比較をしていないため不明。長時間の温度・電池持ちと異なる素材での再現性は未確認。

生データ（Git対象外）:
- /tmp/mymusic-power-normal-unplugged.trace、/tmp/mymusic-power-normal-unplugged-data.xml
- /tmp/mymusic-power-scenery-unplugged-pid.trace、/tmp/mymusic-power-scenery-unplugged-data.xml
- 集計手順: /tmp/mymusic-power-unplugged-summary.py、結果: /tmp/mymusic-power-unplugged-summary.json

追加作業はCURRENTと本記録の更新のみ。アプリコードは変更せず、同じコードのデプロイは繰り返さない。build／XCTest追加実行なし、test端末作成0／削除0、Xcode data削除なし。git diff --checkで確認し、前のコミット依頼の続きとして検証記録をコミット・pushする。
