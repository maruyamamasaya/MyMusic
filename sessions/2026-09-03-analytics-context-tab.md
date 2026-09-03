# Analytics Contextタブ分離

## 作業

- Insightsの`CONTEXT & PROFILE`を「最近の変化」から独立した「時間帯・好み」タブへ移動した。
- 時間帯×音楽特徴、Artist / Album / Genreの変化、Listening Profileの行形式一覧に共通の段階表示を適用した。初期30件、「続きを見る」でインクリメント30件、全件表示後は「閉じる」で30件へ戻る。
- 期間またはデータ品質を切り替えた際は、表示件数を初期値へ戻す。
- `data-sortable`を持つ表へ共通のクライアントソートを適用し、Insights内の4表で全列の昇順／降順切り替えを有効にした。
- 「再生行動」内の4表を「再生入口」「選択種別」「組み合わせ」「音楽特徴」サブタブへ分離した。
- 全ページの一覧と表を再点検し、Overview、Music History、Rankings、Insights候補、Import履歴も共通の30件段階表示へ統一した。
- TracksとData Sourcesは大量データ用のサーバーページングを保ちつつ1ページ30件にし、表示中のページだけでなく全件を対象に全列をソートできるようにした。Import履歴にも共通のクライアント列ソートを適用した。
- Rankingsの曲／Artist／Album／Genre切り替えを廃止し、期間と指標を共通条件に4ランキングを同時取得・4列表示するよう変更した。狭い画面で2列、1列へ折り返す。
- Music Historyの月カードを1件だけインライン展開し、「日ごと」の日別グラフ／日付別再生曲とTracks導線、「ランキング」の4列月間上位、「振り返り」の月間指標／前月比を表示するBeta詳細を追加した。

## 検証

- `node --check analytics/web/app.js`: 成功。
- `PYTHONPATH=analytics analytics/.venv/bin/python -m unittest discover -s analytics/tests -q`: 31件成功。
- ローカルサーバーの`/api/health`、TracksのFavorite降順、Track FeaturesのTempo降順を確認し、後二者が`pageSize: 30`で30件返すことを確認した。
- ブラウザ自動検証用の`agent-browser`は実行環境に存在せず、実画面操作は未実施。
- Music History詳細が利用するindex、月間集計、期間Dashboard、日付別Tracksの関連4テストとJavaScript構文チェックは成功。
- Rankings 4列化後、HTML構成・Music History / Rankings API・JST期間の対象3テストとJavaScript構文チェックが成功。

## 未解決

- 自動ブラウザによる視覚確認は環境制約により未実施。
