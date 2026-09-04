# Analytics取込データクリア

## 作業

- Import画面に「取込データをクリア」ボタンと確認ダイアログを追加した。
- `DELETE /api/imports`で再生イベント、Preference、Data Source、Library、Import履歴を1 transactionで削除する。
- SQLite schemaと`imports/`内の原本JSONは保持し、Import IDを初期化して再Import可能にした。
- 完了後はImport履歴とOverviewを再読込する。

## 検証

- Analyticsのunittest全41件成功。
- 全対象tableのクリア、原本保持、schema維持、再Import、確認ダイアログ経由を確認した。

## 変更対象外

- MyMusic iOS本体、Analyzer、Playback処理は変更していない。
