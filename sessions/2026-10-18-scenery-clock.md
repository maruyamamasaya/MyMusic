# 車窓HUDの現在時刻 — 2026-10-18

## 変更
- 車窓HUD更新としてMATCH。Git root・CURRENT・ARCHITECTUREと既存表示実装を確認。
- ユーザー指定どおり電池残量の右に時刻を追加。展開／縮小で共通表示。
- SceneryClockを分離。白青いDotGothic16・24時間HH:mm、秒と点滅なし。端末timezoneを参照。
- TimelineView(.everyMinute)により分境界で更新。非active時は静止Text、HUD非表示時はviewを破棄する。
- NOW PLAYING／電池／時刻の上段だけ、幅不足時は70%の文字へ切り替える。パネル最大390／270pt、タイトル・Artist、評価・再生操作は維持。
- 設定、署名、音楽／動画再生と永続化は変更しない。

## 検証
- iPhone／埋め込みWatch generic Simulator Debug build成功: /tmp/mymusic-scenery-clock-build.log。
- 実HUD＋Clock＋BatteryIndicatorをmacOS ImageRendererで描画。Store／電池Service／Artworkは一時stub。100%・充電中・favorite true・評価15の展開／縮小で重なりなし。
- 描画画像: /tmp/mymusic-retro-check/clock-preview.png。scene inactiveの静止描画であり、実機の分更新確認ではない。
- 専用lintなし。git diff --check確認。XCTest未実行、test端末作成0／削除0。Xcode data削除なし。
- 実機の表示・分切替・background復帰はユーザー確認待ち。

## Vesperaデプロイ
- 明示依頼に基づき、git status確認後、check-iphone.sh成功→deploy-iphone.sh実行。
- MyMusic.xcodeproj／MyMusic scheme／MyMusic.app、Bundle ID maruyama.MyMusic。
- Vespera（iPhone 17e）、UDID 00008150-000C54280E33401C。
- Debug Build／Install／Launchすべて成功。ログ: /tmp/mymusic-scenery-clock-deploy.log。
- 実機確認はユーザー待ち。今回commit／pushは未実施。

## 実機確認とコロン点滅
- 2026-10-18、ユーザーが現在時刻・縮小中の表示・分切替更新を問題なしと実機確認。
- 追加依頼でコロンを1秒ごとに点灯／消灯。独立したTimelineViewを秒境界へ合わせ、opacity変更だけで位置を維持する。
- 数字は分ごとのTimelineViewを維持し、日付formatterを毎秒作り直さない。非active／HUD非表示で秒更新も止める。
- Reduce Motionでは点滅をせず常時点灯。VoiceOverは時刻全体を読み、コロンを個別に読まない。
- 点滅追加後のiPhone／Watch generic Simulator Debug build成功: /tmp/mymusic-scenery-clock-blink-build.log。
- コロン点滅・Reduce Motionの実機確認は未実施。以前の確認報告を追加版へ拡大解釈しない。
- XCTest未実行、test端末作成0／削除0。既存XCTestDevices合計12K、Xcode data削除なし。

## 点滅版のVesperaデプロイ
- ユーザーの追加依頼に基づき、git status→check-iphone.sh成功→deploy-iphone.sh実行。
- MyMusic.xcodeproj／MyMusic scheme／MyMusic.app／maruyama.MyMusic。
- Vespera（iPhone 17e）、UDID 00008150-000C54280E33401C。
- Debug Build／Install／Launchすべて成功。ログ: /tmp/mymusic-scenery-clock-blink-deploy.log。
- デプロイ記録と実機確認記録を現在時刻・コロン実装と合わせてコミットする。

## コロン実機確認と時計・電池の並び替え
- 2026-10-18、ユーザーがコロン点滅と縮小中の表示を問題なしと実機確認。
- 追加依頼でNOW PLAYING行の時計と電池を交換。展開・縮小とも時計→電池の順。幅、文字サイズ、更新方針、操作は維持。
- 今回確認済みなのは並び替え前のコロン・縮小表示。並び替え版の実機確認は未実施、Reduce Motionの確認も未報告。

## 並び替え版の検証・デプロイ
- iPhone／Watch generic Simulator Debug build成功: /tmp/mymusic-scenery-status-order-build.log。
- git status確認→check-iphone.sh成功→deploy-iphone.sh実行。
- MyMusic.xcodeproj／MyMusic scheme／MyMusic.app、Bundle ID maruyama.MyMusic。
- Vespera（iPhone 17e）、UDID 00008150-000C54280E33401C。
- Debug Build／Install／Launchすべて成功: /tmp/mymusic-scenery-status-order-deploy.log。
- git diff --check成功。XCTest未実行、test端末作成0／削除0、XCTestDevices既存合計12K。Xcode data削除なし。
- 実機確認済みのコロン・縮小表示と、未確認の並び替えを区別し、デプロイ後にコミットする。
