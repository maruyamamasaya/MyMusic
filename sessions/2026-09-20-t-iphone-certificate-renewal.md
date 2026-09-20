# T の iPhone: 開発署名の更新と導入

- 対象は `T`（iPhone 13、UDID `00008110-000E705934F1801E`）。`check-iphone.sh` で paired、Developer Mode enabled、tunnel connected を確認した。
- 端末上の既存 MyMusic は `maruyamatomoka.MyMusic`。通常の project 設定は `maruyama.MyMusic` / Team `U29GY347DY` のため、標準デプロイでは既存アプリを更新できない。
- ユーザー承認のもと、T 用 Team `HNCTDS53YZ` と既存 Bundle Identifier をコマンドラインで指定し、Watch の埋め込みと依存だけを一時的に外して `MyMusic.xcodeproj` / `MyMusic` / Debug の実機 build を試した。project file は終了時に復元し、差分がないことを確認した。
- 初回 Build は署名入力の収集で `No Accounts: Add a new account in Accounts settings`、`No profiles for 'maruyamatomoka.MyMusic' were found` により失敗した。ユーザーが T の Apple ID を Xcode の Accounts に追加後、同じ設定で再試行し `BUILD SUCCEEDED`。
- 生成されたアプリに Watch の埋め込みはなく、`codesign --verify --strict` に成功。署名 Team は `HNCTDS53YZ`、Bundle Identifier は `maruyamatomoka.MyMusic`。embedded provisioning profile は T の UDID を含み、2026-09-27 07:35:28 UTC（16:35:28 JST）に期限が切れる。
- T への install は成功。初回起動は iPhone 側で開発者プロファイル未信頼として拒否された。ユーザーが端末側で信頼操作を行った後、`devicectl device process launch` が成功した。
- iOS test は実行していない。XCTestDevices の新規作成・削除はともに0件、終了時の残量は12KB。
