# 発掘する音楽①・②

- Context Guard MATCH、MyMusic Git root一致。既存の他作業の未コミット変更は保持。
- 既存タイルを①に改名し②を隣接追加。①は24時間、②は168時間。どちらも生成時刻から遡る絶対秒数で日付単位ではない。
- 共用Store処理へ除外期間を渡し既存クイック選曲へ委譲、最大60曲を維持。snapshotの代表曲とArtworkも同じ期間で抽出し、開始時再選曲後の代表曲再挿入で除外を破らない。空状態説明も期間別。
- HomeCategoryTestsの順序期待値を更新し、RediscoveryWindowTestsに期間差・境界・未再生を追加。今回は実行していない。
- git diff --check成功。build・test・deploy未実施、型検証・実画面未確認。テスト端末作成／削除0台、XCTestDevices変更なし。

## 実機デプロイ

- 後続の明示依頼でgit status確認後check-iphone.sh実行。最初の一覧取得は15秒timeout、単独再試行成功後deploy-iphone.sh成功。
- Vespera（実際のmodel iPhone 17e）、UDID 00008150-000C54280E33401C、paired／Developer Mode enabled／connected。
- MyMusic.xcodeproj、scheme／product MyMusic、Debug、Bundle Identifier maruyama.MyMusic。BUILD SUCCEEDED（Watch含む）、Install succeeded、Launch succeeded。署名・Team・Deployment Target変更なし。
- build log: /tmp/MyMusic-iPhone-DerivedData/build.log。既存未コミット変更は保持。実機表示・24／168時間除外の動作は未確認。今回XCTest未実行、テスト端末作成／削除0台、XCTestDevices変更なし。
