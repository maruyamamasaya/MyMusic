# 出力先を常時表示へ（2026-10-29）

- Context Guard MATCH、Git root一致。CURRENT／ARCHITECTUREと既存表示を確認。
- PlaybackOutputLabelからButton・popover・表示Stateを撤去し、接続方式と機器名を常時表示。機器名は最大2行、幅140→160pt。無制限の長さの全文表示は保証しない。VoiceOverでは全文を読む。
- 通常・作業用・HiResの対象ToolbarItemにsharedBackgroundVisibility(.hidden)を指定し、ボタンに見えるglass背景を撤去。
- Service・Store・再生操作の変更なし。既存の他作業を保持。実機未反映、外観未確認。
- 表示のみのためtest未実行。test端末作成0・削除0、XCTestDevices操作なし。
- 指定iPhone 17e Simulator向けDebug build: BUILD SUCCEEDED。git diff --check成功。
