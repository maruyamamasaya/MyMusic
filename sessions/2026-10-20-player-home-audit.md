# ホーム・ミニプレイヤーの再点検

- MATCH。Git root確認済み、未コミット変更を保持。Vesperaへのデプロイなし。
- ユーザー指定により、テーマ／車窓をホームtitle左側のToolbarItemGroupへ配置。単一ToolbarItem内のHStackから個別toolbar itemへ変更。
- 車窓のdisabled条件から非同期クイック候補snapshotを除き、loadingのみ抑止。候補0件で黙って戻らずalertを表示する。
- 通常ミニ外側の横余白12→20pt、iPhone 17eでメニューバーの両端と整列。高さ64ptを維持。ViewThatFitsで曲情報160ptを確保できない場合はグッドのみ省略。ハートは維持。車窓の評価操作は両方維持。
- スモーク背景係数0.65→0.82、実不透明度約74〜78％。Reduce Transparency維持。
- RootViewの通常mini表示条件を、ハイレゾsessionの有無だけでなくcurrentTrackの有無も含む元の条件へ揃えた。tabごとの記述を整形。

## 実操作による検証

- 既存iPhone 17e Simulator EB3A49ED-6553-4D7E-B933-387951643EABの1台を使用、新規端末なし。
- ユーザー音源は使用せず、合成WAV2曲（各180秒）をSimulatorのDocuments/QA Musicへ作成。Files pickerのこのiPhone内へ露出しなかったため、/tmpの一時seed appを同一Simulator bundleへinstallしてbookmarkだけを作成。その後本体を再installして、本体の通常scan／playback経路を使用。seed appのコードはリポジトリに含めない。
- 本体で停止状態から車窓をtap→QA Track Oneが再生中、進行1％。車窓からホームへ復帰、縦向き復帰確認。
- miniで一時停止（13％）→車窓tap→QA Track Twoへクイック再生開始、進行0％、pauseアイコン表示。
- 再生中のQA Track Two、進行13％から車窓へ→同曲16％、先頭へのresetなし。
- 最終の左側配置でテーマ2→3→4→1→2の循環を実画面で確認。左側車窓アイコンも実tapで起動。
- 最終miniでグッド非表示・ハート表示、mini／menu左右端の整列、全周金属枠、高さを本体画面で確認。ハートtap→heart.fill、次曲tap→QA Track Oneへ変更、queue末尾で次曲disabled確認。
- opacity最終版も本体へinstallし、車窓起動→ホーム復帰→miniを描画確認。画像/tmp/mymusic-audit-final.png。
- iPhone／Watch generic Simulator Debug BUILD SUCCEEDED。ログ/tmp/mymusic-audit-build.log。git diff --check成功。lint設定なし。
- Simulator動画未登録のため車窓画面は未登録案内で確認。映像再生、実機データでの挙動、狭い別機種・大きいDynamic Type、ハイレゾ実動作は未検証。候補0件alertはコード確認のみ。
- XCTest未実行、test端末作成・削除0台。XCTestDevices容量計測対象のtest実行なし。既存Simulatorは確認後shutdown、テストfixtureはSimulator内に残す。DerivedData削除なし。

## 最終版の実機デプロイ

- 後続の明示依頼により、git status確認→check-iphone.sh成功→deploy-iphone.shを実行。
- MyMusic.xcodeproj / MyMusic scheme / Debug / Product MyMusic / Bundle ID maruyama.MyMusic。
- Vespera（UDID 00008150-000C54280E33401C）へBuild・Install・Launchすべて成功。ログ/tmp/mymusic-audit-final-deploy.log。
- ホーム左側のテーマ／車窓、候補snapshot依存の解除、mini幅整列・グッド省略・濃さ0.82を含む。実機での表示と操作は未確認。署名・project設定変更なし。
- XCTest未実行、test端末作成・削除0台。
