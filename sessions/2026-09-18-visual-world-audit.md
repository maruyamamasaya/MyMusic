# 再生中のビジュアルの仕様・実装棚卸

- 現行の6種類、操作、保存・解析・描画・休止条件を`Documentation/NowPlayingVisualWorld.md`へ集約。従来の同名Beta 2文書は`NowPlayingVisualWorld-Beta2.md`へ移し、Beta 3案も履歴であると明記した。`CURRENT.md`から現行と矛盾する古い操作・描画説明を除き、`Themes.md`の5種類表記と重複を修正。`ARCHITECTURE.md`の参照先も現行仕様へ変更。
- ソースの参照先を調査し、旧描画の`VisualWorldDynamics`に残っていた左右幅・バランス・`impulse`計算は前の作業中に除去済み。今回はshaderが参照しない変位・開口の積分、関連する未使用引数、使われていない`layout`の3成分の生成・補間を除去した。音域、励起、残光、波形、24帯域、再生操作と保存IDは維持。
- `VisualWorldSpectrumAnalyzer`の音程感confidenceは解析結果として生成されるが、現行shaderでは音程位置だけを参照する。解析契約とテストが利用するため今回は保持した。Metal uniformの未使用成分はSwift/Metal間の16-byte配置を保つ空きとして残す。
- `./scripts/check-visual-world.sh`は11件すべて成功。Visualizer追加後にスクリプトの期待件数だけ10件で止まっていたため11件へ更新し再実行。`xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO -quiet build`成功。`git diff --check`成功。専用lintなし。
- iOSの`xcodebuild test`は実行していない。`XCTestDevices`に今回作成・削除した端末は0台。実機での6種類の連続表示・熱・電力・アクセシビリティは未確認。
