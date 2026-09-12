# Pulse Neonのライティング強化

- Context Guard MATCH、MyMusic Git root確認済み。Pulse以外のテーマの描画値は変更なし。
- Pulse専用PulseNeonLightingを追加。非対称のシアン／青レール、白い芯、発光点、重ねstrokeのhaloで黒との明暗差を強調。背景光0.38、青#4263FF、面の縁の反射もPulseだけ強化。
- 静的描画を維持し、透明度低減／increased contrast時は装飾を外す。音源素材は加工しない。
- Documentation/Themes.mdに形状・光量・幅を記録、CURRENTを更新。共有Environment／保存境界に変更なし。
- 既存iPhone 17一台でbuildを含むAppThemeTests 2件成功（TEST SUCCEEDED）。生成した通常サイズの選択一覧を目視し、Pulseのレールと文字、他テーマの維持を確認。git diff --check成功。
- XCTestDevicesは開始時UUID folderなし・12KB。テスト端末作成0／削除0。実機での見え方は未検証。
