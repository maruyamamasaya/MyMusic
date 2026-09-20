# 再生中のビジュアルの現行状態整理 — 2026-09-20

- `Documentation/NowPlayingVisualWorld.md`の冒頭に、作業ツリー上の6種類、直近のPlasma Spark／Visualizer変更、検証済み範囲、未確認範囲、VesperaとCometへの導入結果を集約した。
- `CURRENT.md`から現行仕様への導線を追加し、文書の日付を更新した。作品レビューの日付も現行状態へ合わせた。
- Visualizerの設定画面の説明に残っていた「スペクトラム」を、現在の一本の波形・光子・波紋へ修正した。
- 既存の未コミット変更は保持した。今回は描画アルゴリズムと音声解析を変更していない。
- iOS Simulator向け`xcodebuild build`成功、`git diff --check`成功。`xcodebuild test`は実行せず、XCTestDevicesの新規作成・削除は0件、残量12KB。
