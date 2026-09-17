# Photon Sphere衛星とPlasma Spark

- Photon Sphere外周に種を固定した光子16個と小さな衛星球3個を追加。速度・方向・位相・揺れを個別に変え、軌道線は描かない。低品質Metalでは9光子・2衛星へ減らす。
- ユーザー提供画像を確認し、Plasma Sparkを暗い空間の虹色の角張った線と短い光片で構成。初案の中央発光核から伸びる放電は参照と違うため採用しなかった。
- アート画面下部の曲名・アーティスト・Artworkと5操作を一つのコンパクトなバーへ統合。
- 設定とアート画面のメニューへPlasma Sparkを追加し、既存のVisual World保存キーを使用。Metal／Canvas両方へ実装。
- 実機での見え方、フレーム落ち、熱・電力は手動確認対象。
- 最終変更後のiPhone向けDebug buildと`git diff --check`が成功。既存iPhone 17e SimulatorでVisual World設定・旧Aurora移行の2 testが成功。Mac上でCanvas fallbackを390×844へ描画し、球体の外周とPlasma Sparkの線・光片を目視確認。XCTestDevicesの新規作成・削除は0台、残容量は12KB。実機Metalの目視確認は未実施。
- 明示依頼により`./scripts/check-iphone.sh`の成功後に`./scripts/deploy-iphone.sh`を実行。`MyMusic.xcodeproj`／`MyMusic`、product `MyMusic`、Bundle ID `maruyama.MyMusic`、Vespera（iPhone 17e、UDID `00008150-000C54280E33401C`）でDebug実機build、install、launchがすべて成功。未コミット変更は保持。今回のデプロイではtestは再実行せず、XCTestDevicesの新規作成・削除は0台、残容量は12KB。実機画面の手動確認は未実施。
