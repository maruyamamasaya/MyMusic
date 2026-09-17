# 薄明の夜空と外周光子

- 薄明の地平線を画面高さ約79%へ下げ、上側を青い夜空へ変更。雲を青寄りに調整した。
- Blue Cosmosの星生成を共有し、薄明では約7〜8割の密度と低輝度・青寄りの色で描く。Canvasも同じ方針で200候補から約25%を間引く。
- Photon Sphereの外周光子と衛星球を点に近い大きさへ縮小。曲ごとのseedと複数の周期を重ね、滑らかで不規則な経路と独立した明滅を与える。
- 再生、解析、保存設定、操作UIは変更しない。実機での見え方と熱・電力は手動確認対象。
- `generic/platform=iOS`のDebug buildと`git diff --check`が成功。Mac上でCanvas fallbackを390×844へ描画し、薄明の青い空・低い地平線・星と縮小した外周光子を目視確認。描画のみの変更のためXCTestは実行しない。
- ユーザーの明示依頼を受け、`./scripts/check-iphone.sh`成功後に`./scripts/deploy-iphone.sh`を実行。`MyMusic.xcodeproj`／`MyMusic`、product `MyMusic`、Bundle ID `maruyama.MyMusic`、Vespera（iPhone 17e、UDID `00008150-000C54280E33401C`）でDebug実機build、install、launchがすべて成功。既存の未コミット変更は保持した。実機での見た目は手動確認対象。
