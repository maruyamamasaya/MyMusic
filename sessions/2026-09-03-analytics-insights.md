# Analytics Insights

## 作業

- サイドバーと既存ページ切替方式にInsightsを追加した。
- `play_source`別、`selection_type`別、組み合わせ別の行動指標をQueries層で集計する`/api/insights`を追加した。
- today／7d／30d／all／customの期間指定とJST境界を既存共通処理で適用した。
- 詳細イベントとEarly SkipのSQL predicateを共通化した。
- 入口・選択種別は固定enumにせず、Import済みイベントの値をそのまま表示する。
- 日時だけで判定する品質フィルターを追加し、既定の`analyzable`と全再生回数を含む`all`を期間指定と併用可能にした。
- `all`で詳細イベントがない行は、Early Skip回数を含む詳細指標を`null`で返す。
- Track Featuresの9特徴量を最新analysisVersionに限定し、SQLite JSON関数とTrack ID結合で5スコア帯へ集計する分析を追加した。
- UIは特徴量切替と、完走・Skip・Early Skip率を横棒付きで比較できる表を表示する。
- 最近ハマった曲、飽き、特徴の新傾向、再発見を直近・過去の説明可能な比較ルールで追加した。
- JST時間帯×特徴、Artist／Album／Genreの変化、Listening Profileを追加した。
- Profile・評価・Favorite・完走実績・Skip・Overplayを使うread-only推薦、再発見推薦、未再生／低再生発見、自動Insightカードを追加した。

## 検証

- Analytics unittest: 27件成功。
- 未知の入口・選択種別、組み合わせ、信頼開始日前の除外、Early Skip、任意期間、不正期間を検証した。
- 正当な`unknown`の包含、品質フィルターの既定値・切替、旧イベントのみの行の`null`表示を検証した。
- 特徴量の全境界値、欠損・不正値、Track ID結合、Version混在、旧詳細除外、custom期間、品質フィルター、イベントなしのrate nullを検証した。
- 各変化候補、時間帯特徴、属性変化、Profile、推薦順位、Overplay減点、未再生値の非推測、弱いInsightの除外を統合fixtureで検証した。
- JavaScript構文と`git diff --check`を確認した。

## 未解決事項

- なし。
