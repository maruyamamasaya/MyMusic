# 現行データ保全の調査

- 要求: 保存構造を変える前にMyMusic／HomeStereoの現行仕様・紐付け・backup範囲を精緻に確認する。Context Guard MATCH、両Git rootを確認。
- 両契約revision 3の本文がcmpで一致。HomeStereoはread-only、実データ／DBは開いていない。
- `Documentation/CurrentDataPreservationMap.md`を追加。保存形式、ID、正本と派生、backup対象、交換JSONとの差、既存testの限界を記録した。
- 重要発見: MyMusic外部backupは履歴移行sidecar／旧JSONを含まない。root交換後の本番Persistence初期化で空DB再作成へ進むコード経路あり。復元DB直読の既存testでは覆えない。実行再現・修正はまだ行っていない。
- HomeStereo JSON backupは全DB復元ではなく、詳細Events・評価・link・tags・feature等が対象外。Playlist tagsのmerge時消失も次の隔離検証対象。
- Good/Badは現在の評価値、embeddingはAnalyzer資産。MyMusic semanticはNPZ保存、HomeStereo workerは永続embeddingを保存しない。
- アプリコード・schema・データ構造・共通契約に変更なし。CURRENT/ARCHITECTUREには開始前から変更があり、触れていない。
- 検証: コード／test／関連履歴の静的調査、契約cmp、diff/status確認。build/testなし、test端末作成・削除とも0。実端末のbackup完全性は未確認。
- 次: 隔離保存先で本番起動経路を含めた復元検証。全settings／Artwork／Watch／HiRes／Analyticsと実在解析資産の追加棚卸しは未完了。
