# Local Web Analytics: Music History / Rankings

## 作業

- LISTENING OVERVIEWは維持し、独立したMusic HistoryとRankingsをサイドバーへ追加した。
- Music HistoryはPlayback EventをJSTの月ごとに集計し、再生回数、詳細期間の再生時間、代表曲、代表Artistをタイムライン表示する。
- Rankingsは今日／7日／30日／全期間／任意期間と、曲／Artist／Album／Genre、再生回数／再生時間を切り替える。表示は上位50件。
- 旧履歴は従来どおり再生回数に含め、再生時間は2026-09-01以降の詳細イベントだけを使う。

## 検証

- `python -m unittest discover -s analytics/tests -v`: 25件成功。
- 実データを使うローカルブラウザでOverview、Music History、Rankingsの表示と、Artist／再生時間への切り替えを確認した。更新済みページで新規コンソールエラーはない。

## 制約

- 音楽史は現在のImport済みPlayback Eventの範囲で構成される。Libraryの追加日や音源の発売年を時系列化するものではない。
