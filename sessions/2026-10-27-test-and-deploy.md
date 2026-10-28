# テストとVesperaへのデプロイ

- 依頼: Simulatorテストから実機デプロイまで実施。Context GuardはMATCH、Git root確認済み。開始時working treeはclean。
- 通常sandboxではCoreSimulator接続拒否を再現。権限を拡張したコマンドでは指定iPhone 17e（EB3A49ED-6553-4D7E-B933-387951643EAB、iOS 26.5、Booted）へ接続成功。端末故障や不在を示す結果ではない。
- 初回全テスト失敗。HomeCategoryTestsの旧ホーム期待値、DataTransferTestsの旧genre除外期待値、TrackFeatureDisplayIntegrationTestsのPlayerStore注入漏れを修正。exportの期待値はe15a26eの参照保持修正を確認して更新。アプリ本体・JSON実装・構造・署名設定は変更なし。
- 指定UDID、並列test無効、worker 1、同時destination 1で再実行。XCTest 365件とSwift Testing 12件が失敗0、TEST SUCCEEDED。test buildにiPhone／埋め込みWatch targetを含む。Watch Simulator起動検証は実施していない。
- check-iphone.sh成功後、deploy-iphone.shを実行。MyMusic.xcodeproj／MyMusic scheme／Debug／product MyMusic／Bundle Identifier maruyama.MyMusic。Vesperaは実機iPhone 17e、UDID 00008150-000C54280E33401C、paired、Developer Mode enabled、connected。Build・Install・Launchすべて成功。
- ログ: /tmp/mymusic-20261027-test.log（初回）、/tmp/mymusic-20261027-test-retry.log（成功）、/tmp/mymusic-20261027-deploy.log。
- XCTestDevicesは開始前UUID folderなし・12 KiB、終了後もUUID folderなし・12 KiB。test端末作成0／削除0、データ削除なし。DerivedData削除なし。
- git diff --check成功。専用lint未設定。実機での画面・操作・音声出力確認は未実施。commit／push未実施。
