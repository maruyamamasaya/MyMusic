# クイック再生の再生回数補正

- お気に入りとその他の1:1構成を維持しつつ、お気に入りを直近から必要数の最大3倍まで抽選候補に広げた。
- 再生回数0〜2回は1.0、3〜5回は0.7、6〜9回は0.4、10回以上は0.1の重みをQuick Playだけに適用。既存の短期Overplayとは小さい方を採用し、二重に掛けない。
- 保存形式、Preference、他のshuffle入口は変更しない。
- 検証: iPhone 17 Pro / iOS 26.5 Simulatorを明示した`xcodebuild build`成功。関連8テスト成功、`git diff --check`成功。
- 標準の`-sdk iphonesimulator` buildはWatch AppIconをiPhone SDKで処理して失敗したため、Simulator destinationを明示した。`XCTestDevices`は新規0件、削除0件、終了時12K。
