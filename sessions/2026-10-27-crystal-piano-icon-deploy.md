# 水晶ピアノのアプリアイコンと実機デプロイ

Context Guard MATCH、Git root・作業ツリー確認、既存未コミット変更保持。

ユーザー添付「虹色に輝く水晶のグランドピアノ.png」（1254px正方形、不透明）をアプリアイコンとして反映。sipsで1024px JPEG品質95へ変換し、MyMusic/Assets.xcassets/AppIcon.appiconset/crystal-piano.jpegへ保存。通常／dark／tintedの既存3枠で同じ原画を参照。独自のdark／tinted加工はなし。旧画像3枚は保持。元画像の変更・画像生成・Watchアイコン変更なし。project・署名・識別子設定変更なし。

check-iphone.sh成功後deploy-iphone.shを実行し、Vespera（iPhone 17e、UDID 00008150-000C54280E33401C）へMyMusic.xcodeproj／scheme・product MyMusic／Debug／Bundle ID maruyama.MyMusicのBuild・Install・Launchすべて成功。弱いぼかし版、再生情報、従来ヘッダーへの復元を含む現在の作業ツリーを使用。

アイコンのホーム画面での反映・小サイズでの識別性、Library／Playlistのタイトル復元、再生画面の外観はユーザー実機確認待ち。XCTest未実行、test端末作成0／削除0、XCTestDevices未操作・容量未計測。git diff --check成功。
