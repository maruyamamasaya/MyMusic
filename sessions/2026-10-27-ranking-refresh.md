# ランキングの更新タイミング

- 要求はMyMusicの保守としてMATCH。Git rootを確認し、既存の未コミット変更を保持。
- ArtistRankingViewの`.task(id: input)`を`.task`へ変更。画面表示時とpull-to-refreshだけ現在入力で集計し、表示中の履歴・評価・ライブラリ・部門設定変更では再集計しない。部門／方式切替は既存の集計結果を使用する。
- 画面説明、CURRENT.md、ARCHITECTURE.mdを更新。集計Service・Store・永続化は変更なし。
- 指定iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB）向けDebug build成功（埋め込みWatchを含む）。sandbox内ではCoreSimulator接続不可のため、権限拡張後に既存端末を確認してbuild成功。
- git diff --check成功。Viewのtaskトリガーのみの変更のためXCTest未実行。test端末の作成／削除は0台、XCTestDevicesの操作なし。実画面操作・実機デプロイ・負荷計測は未実施。

## Vesperaへのデプロイ

- ユーザーの明示依頼でgit status確認後、check-iphone.sh成功、deploy-iphone.sh成功。sandbox内の端末一覧取得はtimeoutしたため、権限拡張後にチェックとデプロイを実施。
- Vespera（iPhone 17e）、UDID `00008150-000C54280E33401C`。
- MyMusic.xcodeproj／MyMusic scheme／MyMusic product／Bundle ID `maruyama.MyMusic`。Debug Build・Install・Launch成功。未コミット変更を含む現在の作業ツリーを使用し、署名・project設定変更なし。
- 実機でのランキング更新操作は未確認。XCTest未実行、test端末作成／削除0台。
