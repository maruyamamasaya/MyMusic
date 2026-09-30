# ホーム再生開始時の再生中画面表示（2026-10-01）

- ホームの即再生マイミュージック、MIX、プレイリストから再生を開始後、RootViewの既存Now Playing sheetを表示する。
- HomeDestinationViewからcallbackを渡し、選択してランダム再生、Favorite Album／Artist、あとで聴く、最近再生した曲の再生操作も対応。共有Viewのcallback既定値は空操作で、他の利用箇所の挙動を保持。
- Mood Mixは再生成功のcallback、Deep Diveは非空キューの開始時にHomeViewへ表示予約を記録。選択sheetのonDismissで再生中画面を開くため競合を避ける。再生せず閉じるときは開かない。
- 変更対象: HomeView、HomeCategoryDetailView、MoodMixSelectionView、SelectiveRandomPlayView、FavoriteCollectionsView、ListenLaterView、CURRENT、ARCHITECTURE。既存の未コミット変更は保持。
- generic iOS Simulator Debug build: BUILD SUCCEEDED。UI callbackの変更につきXCTestは実行せず。専用lintなし、git diff --check成功。実機上のタップ／sheetアニメーション確認は未実施。
- git status確認 → check-iphone.sh成功 → deploy-iphone.sh実行。Project MyMusic.xcodeproj、Scheme／Product MyMusic、Debug、Bundle ID maruyama.MyMusic、Vespera UDID 00008150-000C54280E33401C。Build／Install／Launchすべて成功。
- test端末作成0件、削除0件、XCTestDevicesの終了時合計容量3.5G。署名・識別子などの設定変更なし。
