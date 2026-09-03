# Analyzer複数Root既存結果救済

- 既存SQLiteとJSONを読み取り専用で棚卸しし、音源・cache・旧JSONは変更／削除しなかった。
- cache 8,041行（成功8,035、失敗6）を確認。Unicode合成形違いの120重複を除く成功identityは7,915。
- 現在の4 RootをGit対象外の`analyzer/libraries.local.json`へ記録した。
- 初回auditで7,886曲をcacheからmaster化可能。artists-2026は未解析32、変更27、前回失敗6、cacheにあるがdiskにない2。
- `analyzer/manage.py`で状態を分類し、安全なmasterとsource reportを新規生成可能にした。
- 通常AnalyzerでUnicode合成形違いの旧cacheを再利用可能にした。
- AnalyticsのTrack Featuresを置換からTrack ID単位mergeへ変更し、部分Import回帰testを追加した。
- Analyzer unittest 38件、Analytics unittest 33件が成功した。Swift変更がないためXcode buildは省略した。
