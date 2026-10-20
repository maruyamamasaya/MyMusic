# 通常ミニプレイヤーのガラスデザイン

- Context Guard: MATCH。Git root確認済み。開始時の作業ツリーはclean。
- 車窓HUDを通常ミニへ共用し、ドット文字、金属枠、反射、評価、再生／次曲、進捗を反映。文字とArtworkは従来のonOpenへ接続し、ハイライト復帰も既存経路を維持。
- ミニでは時計／電池を表示せず電池監視も開始しない。背景opacity係数0.65、実opacity約0.59〜0.62。Reduce Transparencyは不透明を維持。ハイレゾ専用ミニは対象外。
- 変更: MiniPlayerView.swift、SceneryBGMOverlay.swift、SceneryPlayerAppearance.swift。CURRENT／ARCHITECTURE更新。
- 検証: 変更Swift 3ファイルのswiftc frontend parse成功、git diff --check成功。
- 標準generic iOS Simulator buildは初回sandboxのSourcePackages書込制限、権限付き再試行は「watchOS 26.5 must be installed」で停止。SDK一覧にwatchOSはあるがdestination解決が失敗。platformのdownloadやproject設定変更は行わない。型検証と実画面（tab accessory内の高さ・狭幅・Dynamic Type・長い曲名）は未確認。
- XCTestは実行せず、test端末の作成・削除0台。XCTestDevices容量計測対象のtest実行なし。デプロイ未実施。
