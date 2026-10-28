# ライブラリ画像の統一

- ユーザー依頼：年の砂時計画像と同じ雰囲気で曲・アルバム・アーティスト・ジャンル・作曲者の画像を更新。Context Guard MATCH、Git root確認済み。
- 年画像を参照し、濃紺背景・青紫のガラス・琥珀色の粒子・レコード素材を揃えた5枚を生成。音符、ジャケット、マイク、複数色のレコード、ペンと譜面で区別する。
- HomeTileImagesにlibrary-{songs,albums,artists,genres,composers}-v2.pngを配置。旧jpgと生成原本は保持。既存loaderはjpg優先のため、別ベース名で明示参照する。従来運用で画像はGit対象外。
- HomeCategoryの参照名、HomeCategoryTestsの期待値、画像README、CURRENTを更新。構造・データフロー変更なし。
- 検証：実際のHomeCategory.swiftをswiftcでコンパイルし、ライブラリ6タイルの参照名をpreconditionで確認、PASS。Swift構文parse・git diff --check成功。
- 今回build・XCTest・実機deployなし。実機タイルcropは未確認。test端末作成0／削除0、XCTestDevices容量未計測。署名・project設定・音源変更なし。
