# Analytics Track Feature table

## 作業

- Data Sources > 音楽特徴量の列を固定3項目から、Import済み`track_features`全件の`features` key集合を使う動的構成へ変更した。
- 既知15項目を基本音響、Semantic／音楽特徴、音量の順に並べ、未知keyは末尾へ安定順で残した。
- TEMPOと音量値へ単位を付け、スコアを小数2桁へ統一し、曲単位の欠損を`—`表示にした。
- 動的な既知／未知列も全件対象でソートできるようにした。Track Feature Resolver、Import merge、ページングは変更していない。

## 検証

- `PYTHONPATH=analytics analytics/.venv/bin/python -m unittest discover -s analytics/tests -v`: 43 tests passed。
- DSP v1相当とSemantic v2相当の混在、欠損TEMPO、音量特徴、未知key、動的列ソートのtestを追加した。

## 未解決事項

- なし。
