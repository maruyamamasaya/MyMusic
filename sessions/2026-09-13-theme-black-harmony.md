# 黒背景素材との調和とシンプルダーク

- Context Guard: MATCH。MyMusic Git rootを確認し既存変更を保持。
- シンプルダーク（simple-dark）を選択肢の先頭へ追加。純黒、標準AccentColor、ニュートラルな面を使用し、背景装飾と面の光る縁は描かない。既存の保存済みテーマ／fallbackを変更しない。
- ３テーマもbaseを純黒へそろえ、面の彩度・明度を抑えた。拡散光を左上と右下に局在化し中央に黒を残す。星と信号線も減光。素材画像そのものと再生処理は変更しない。
- ThemePalette／ThemeBackgroundにパラメータを集約したまま、Documentation/Themes.mdとCURRENTを更新。構造変更なし。
- AppThemeTestsは先頭順、４テーマの保存復元、未知ID fallbackと通常／accessibility3の描画を対象。既存iPhone 17を１台使用、並列テストなし。
- 最終検証: buildを含むAppThemeTests 2件成功、TEST SUCCEEDED。４テーマの通常／拡大文字画像を生成し、通常サイズの選択一覧を目視確認。git diff --check成功。
- XCTestDevicesは開始時・終了時ともUUID folderなし、合計12KB。テスト端末の作成0／削除0。実機・実素材を含むホーム全体の追加目視確認は未実施。
