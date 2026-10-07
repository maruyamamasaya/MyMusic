# Vesperaへの配置とリモート反映

ユーザーの明示依頼により両アプリをデプロイし、全未コミット変更をコミット・pushする。Context Guard MATCH、Git rootはMyMusic／main、fetch後origin/mainと一致。開始時のSemantic backup／保全文書等の変更は保持してbuildした。

- check-iphone.shの初回はVespera unavailableで停止。接続依頼後、ユーザーから接続済みの回答を受け再check成功。その後だけdeploy-iphone.shを実行。
- project MyMusic.xcodeproj、scheme MyMusic、configuration Debug、product MyMusic.app、bundle maruyama.MyMusic。
- 端末Vespera（iPhone 17e）、UDID 00008150-000C54280E33401C。Build／Install／Launchすべて成功。署名／Bundle Identifier／Team／Deployment Targetは変更していない。
- PYTHONPATH=analyzer python3 -m unittest discover -s analyzer/tests -v: 40 tests成功。git diff --check成功。
- xcodebuild testは実行しない。Simulator／test端末の作成・削除0／0。XCTestDevices残容量12KB、削除なし。
- HomeStereoも既定deploy-macos.shでRelease build／署名・hash検証／正式配置・起動が成功し、別repository側へ記録した。
- Tea Proの全rate切替、操作UI、実データrestoreは今回未検証。デプロイはこれらの成功保証ではない。
- 既存の全未コミット変更と今回のデプロイ記録をコミット・push対象とする。
