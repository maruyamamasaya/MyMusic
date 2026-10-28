# 画像生成によるテーマアイコン

Context Guard MATCH、Git root確認済み。既存の未コミット変更を保持。

ユーザーの明示依頼でimagegenスキル／built-in image_genを使用し、4枚を個別生成。CLI不使用。生成PNGのalphaを保持してsipsで128pxに縮小し、MyMusic/Assets.xcassets/ThemeIcon{Dark,Aurora,Pulse,Cosmos}.imageset/icon.pngへ保存。全4枚hasAlpha=yesを確認し、生成画像を目視確認。

HomeThemeCycleButtonのSF Symbolsだけを画像へ差し替え。パネルの寸法・奥行き・spring・操作・保存・アクセシビリティ設定は維持。画像表示枠23pt。

## 生成プロンプト

共通（SUBJECTだけ下記へ置換）:

Use case: stylized-concept. Asset type: tiny iPhone music theme toolbar icon. Generate ONE isolated icon: SUBJECT. Monochrome white and silver grayscale only, bold simple silhouette, subtle satin sculpted highlights, refined minimal music hardware aesthetic. Centered square composition with 12 percent transparent margin, readable at 20px. Actual transparent alpha background. No panel, no frame, no lettering, no numbers, no cast shadow outside icon, no colored pixels. Save the output as a PNG and return its local file path.

- Dark: a bold sculpted crescent moon
- Aurora: three flowing aurora ribbons forming a compact wave
- Pulse: five rounded vertical audio waveform bars
- Cosmos: a four-point star with one small orbiting star

## 検証

XCTest未実行。test端末の作成0・削除0、XCTestDevices未操作・容量未計測。実画面・実機の見え方は未確認。今回の生成画像版は実機デプロイしていない。

指定iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB）向けDebug build成功（iPhone／Watch）。git diff --check成功。

## 実機デプロイ

ユーザーの明示依頼でcheck-iphone.sh成功後、deploy-iphone.shを実行。Vespera（iPhone 17e、UDID 00008150-000C54280E33401C）へMyMusic.xcodeproj／scheme・product MyMusic／Debug／Bundle Identifier maruyama.MyMusicのBuild・Install・Launchすべて成功。生成アイコン版を含む未コミット作業ツリーを保持して使用。署名・識別子等の設定変更なし。見え方と操作感はユーザー確認待ち。XCTest未実行、test端末の作成・削除0。
