# Xcode ストレージ管理ルール

## 作業

- `AGENTS.md` に、iOS / macOS プロジェクト検証時のストレージ管理ルールを追加した。
- buildだけで十分な場合はtestを省略し、testが必要な場合は既存Simulator 1台・並列test無効で実行する方針を明記した。
- `XCTestDevices` の事前記録、今回のtaskで新規作成されたUUID folderだけを対象とする事後削除、process実行中の削除禁止、最終容量報告を明記した。
- DerivedDataなど、その他のXcode dataの削除には事前確認が必要であることを明記した。

## 検証

- 文書差分を確認した。
- ソースコードとproject設定は変更していないため、Xcode build / testは実行していない。

## 未解決事項

- なし。
