# Analytics navigation tabs

## 作業

- Analytics v0の既存サイドバー画面をURL fragmentへ対応させた。
- 長いInsightsを「おすすめ」「最近の変化」「再生行動」の3タブへ分割した。
- ブラウザの戻る／進むと再読み込みで、選択中の画面とInsightsタブを復元するようにした。
- 期間、データ品質、特徴量の各フィルターとAPI契約は変更していない。

## 検証

- HTML構造とJavaScript構文を静的検証した。
- Analytics unittest 30件が成功した。
- 実ブラウザで3タブの表示切替、URL更新、戻る／進むによる復元、コンソールエラーなしを確認した。
- 狭い画面で期間ボタンを横スクロール可能にし、InsightsとData Sourcesのサイドバーアイコンを補完した。

## 未解決事項

- なし。
