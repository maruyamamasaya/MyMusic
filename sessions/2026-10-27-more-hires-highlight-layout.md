# もっと見る・ハイレゾ画像とハイライト上部の整理

Context Guard MATCH、Git root確認、既存未コミット変更保持。

## 変更

imagegenスキル／built-in image_genで2枚を個別生成し目視確認。もっと見るはクリスタルのアルバムが奥へ続く構図、ハイレゾは金の精密な波形とサファイアの構図。768px JPEG品質88へ変換してMyMusic/Resources/HomeTileImages/playlist-more-v1.jpgとlibrary-hires-v1.jpgへ保存。原本は生成先へ保持。HomePlaylistMoreTileは既存loaderとstateで背景画像を読み、読込不可時は従来gradient。HiResは既存HomeDestinationのlocalBackgroundImageNameへ追加。タイルのaction・寸法・表示条件を維持。HomeCategoryTestsの旧「work以外は画像なし」期待値をHiRes追加へ追従。

追加指示でチューニングへのhomeSectionBackdrop呼出しを撤去。黒い帯・fadeなしでtheme背景をそのまま表示。他sectionの下地は維持。

HighlightTrackPageのheaderから「ハイライト／上へスワイプして次の曲」の案内と上部reshuffleを撤去し、選曲モードPickerだけにした。reshuffleは下のplaybackButtons列へ移動。PickerとArtworkの間の伸縮Spacerを除去、上paddingを従来最大safeInset+12から8ptへ。Artworkは幅上限size.width-40、高さ上限size.height×0.54（従来-44、×0.46）へ拡大、最大440ptを維持。既存のswipe／モード／各action／再生責務は変更なし。

## 検証

指定iPhone 17e Simulator向けDebug build成功（iPhone／Watch）、git diff --check成功。生成画像目視確認。XCTest未実行、変更したテスト期待値の実行確認なし。test端末作成0／削除0、XCTestDevices未操作・容量未計測。実機未デプロイ。小さい高さ・大きい文字でのハイライトArtworkと下部操作列の収まり、実際のタイルcrop・可読性は未確認。

## 生成プロンプト

### more

Use case: stylized-concept. Asset type: square background artwork for a small music-player carousel tile. An elegant luminous corridor of floating translucent crystal album sleeves, opening into deep indigo space, a restrained warm golden light at the distant right-hand vanishing point. A sense of discovering more music, layered depth, jewel-like cyan and violet reflections. Premium cinematic photographic 3D texture, vivid but tasteful highlights over a near-black foundation, visual focus in upper right, lower half dark calm space for white app labels. Fill canvas edge to edge. No text, lettering, digits, borders, icons, UI, watermark or phone mockup.

### hires

Use case: stylized-concept. Asset type: square background artwork for a small music-player carousel tile. A refined sculptural visualization of high-resolution sound: a luminous finely spaced golden audio waveform suspended above dark sapphire crystal, concentric precision etched grooves and subtle prismatic refraction, luxurious acoustic instrument craftsmanship, detailed but uncluttered. No literal headphones, no brand logos. Premium cinematic photographic 3D texture, vivid but tasteful highlights over a near-black foundation, visual focus in upper right, lower half dark calm space for white app labels. Fill canvas edge to edge. No text, lettering, digits, borders, icons, UI, watermark or phone mockup.


## 実機デプロイ

ユーザー依頼でcheck-iphone.sh成功後deploy-iphone.shを実行。Vespera（iPhone 17e、UDID 00008150-000C54280E33401C）へMyMusic.xcodeproj／scheme・product MyMusic／Debug／Bundle ID maruyama.MyMusicのBuild・Install・Launchすべて成功。現在の未コミット作業ツリーを保持して使用、署名等の設定変更なし。画像とハイライト配置の実機確認はユーザー確認待ち。XCTest追加実行なし、test端末作成0／削除0。
