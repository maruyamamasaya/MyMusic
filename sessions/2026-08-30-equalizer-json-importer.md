# EQ JSON Importer 修正

## 症状と原因

- データ管理で「イコライザーを読み込む」を選んでも、JSONのファイル選択が正しく機能しないことがあった。
- 同じViewへプレイリスト、EQ、ジャンル設定の`.fileImporter`を3つ重ねており、同種のpresentation modifierが競合し得る構成だった。

## 変更

- `DataManagementView`のファイル読み込みを単一の`.fileImporter`へ統合した。
- ボタン操作時に読み込み対象と許可するファイル形式を切り替え、選択完了後は対象に応じた既存の解析・適用処理へ分岐する。
- JSON schema、設定の検証、EQの音声適用処理は変更していない。

## 検証

- iOS Simulator Debug build: `BUILD SUCCEEDED`。
- `git diff --check`: 問題なし。
- 既存のSwift 6移行警告とApp Intents metadata警告は残るが、今回の変更箇所に新しいwarningは確認されなかった。
- 実機のFiles UIによる選択操作は未確認。
