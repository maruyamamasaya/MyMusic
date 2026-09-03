# Analytics Insights

## 作業

- サイドバーと既存ページ切替方式にInsightsを追加した。
- `play_source`別、`selection_type`別、組み合わせ別の行動指標をQueries層で集計する`/api/insights`を追加した。
- today／7d／30d／all／customの期間指定とJST境界を既存共通処理で適用した。
- 詳細イベントとEarly SkipのSQL predicateを共通化した。
- 入口・選択種別は固定enumにせず、Import済みイベントの値をそのまま表示する。

## 検証

- Analytics unittest: 27件成功。
- 未知の入口・選択種別、組み合わせ、信頼開始日前の除外、Early Skip、任意期間、不正期間を検証した。
- JavaScript構文と`git diff --check`を確認した。

## 未解決事項

- なし。
