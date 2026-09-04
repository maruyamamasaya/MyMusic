# Analytics Track Feature救済照合

## 作業

- Track Featuresの`sourceIdentity`が`source_records.raw_json`に保存済みであることを確認した。
- 現行Library JSON／raw JSONには`relativePath`と`fileSize`が無いことを確認し、Analytics入力schemaとSQLiteへ後方互換なoptional field／columnを追加した。
- 独立した`TrackFeatureResolver`を追加し、Track ID完全一致を最優先に、本体同等のpathおよびsize + duration + metadata照合を実装した。
- Library／Track Features Import後に既存recordも再解決し、Data Sourcesと特徴量集計の結合先を更新するようにした。
- path／file size indexを一度構築し、各曲でLibrary全件を走査しないようにした。

## 検証

- `analytics`のunittest全39件成功。
- 完全一致優先、path救済、metadata fallback、曖昧拒否、identity不足拒否、Library後Importでの再解決を追加テストで確認した。
- 旧Library schemaへ照合用列を追加してからINDEXを作成するmigrationを2回実行し、冪等性と既存行の保持を確認した。
- `git diff --check`成功（既存ファイルのCRLF警告のみ）。

## 制約

- iOS本体の現行Library Exportは`relativePath`／`fileSize`を含めない。このため従来形式だけのLibraryでは安全条件の材料が足りず、救済せず未紐付けを維持する。iOS本体・Analyzer・Playbackは変更していない。
