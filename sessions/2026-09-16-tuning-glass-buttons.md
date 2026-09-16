# チューニングボタンのガラス表現

- ホームのチューニングカプセルに薄いmaterialと既存色の80%不透明gradientを重ね、細い反射縁を追加した。
- 選択中だけ、そのプリセット色を使ったぼかし影で柔らかい光を表示する。描画は全テーマ共通で、色の定義や選択動作は変更しない。
- `xcrun swiftc -frontend -parse MyMusic/Views/Home/HomeView.swift`、`git diff --check`、`xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO -disableAutomaticPackageResolution build` が成功した。
- Simulator実画面での見た目は未確認。XCTestは実行せず、test端末の作成・削除は0台。

## 追加調整

- ボタン本体の透け感を強めるためmaterialの下地を外し、既存色のgradientを60%不透明にした。
- 選択中のぼかし影を削除し、選択表示は既存のチェックと輪郭線に戻した。
