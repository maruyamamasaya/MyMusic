# データ管理の解析・設定JSON

## 作業

- データ管理へ、音量ノーマライズ解析値と音楽特徴量のJSON書き出しを追加した。
- ノーマライズ出力はIntegrated LUFS、True Peak、固定ゲインが揃った曲だけを含め、現在の機能ON/OFFも記録する。
- 特徴量出力はTrack ID、表示名、照合元情報、analysisVersion、解析／Import日時、保存済み全特徴量を含む。
- 現在のEQとオリジナルEQプリセット、ジャンル表示プリセットを、種類識別子とversionを持つ別JSONとして書き出せるようにした。
- EQ／ジャンルプリセットJSONの読み込みを追加した。同名presetは既存IDを保って更新し、それ以外は追加する。既存の非対象presetは削除しない。
- 設定の適用前に文書種類／version、名称／ID重複、EQバンド数、有限値、ゲイン範囲を検証する。

## データ境界

- 解析JSONは確認・退避用のアプリsnapshotで、Mac Analyzerのschema v1 import形式ではない。今回、解析snapshotの再Importは追加していない。
- 音源ファイルとStable Track IDごとの曲別手動調整値は含めない。
- EQを読み込むと現在値は切り替わり、音声controllerへ即時適用してUserDefaultsへ保存する。
- ジャンルpresetを読み込んでも現在のジャンル表示設定は自動適用しない。

## 検証

- 解析JSONの全特徴量／ノーマライズ済み曲の抽出、EQとジャンルpresetのround-trip・同名merge・永続化、不正EQ preset拒否をXCTestへ追加した。
- iPhone 17 / iOS 26.5 Simulator: 全XCTest 74件成功、失敗0、skip 0。
- iOS Simulator Debug test build: `TEST BUILD SUCCEEDED`。
- `git diff --check`: 問題なし。
- 既存のSwift 6移行警告とAsset Catalog警告は残るが、今回の変更由来のbuild warningは確認されなかった。
- Analyzer変更はないためPython unittestは対象外。専用lintはリポジトリに存在しないため未実行。

## 未検証

- Files／共有シートを使った実機での大容量特徴量JSON書き出し時間とメモリ使用量。
- 実機でのEQ JSON読み込み直後の聴感、およびVoiceOver／Dynamic Typeでのデータ管理画面操作。
