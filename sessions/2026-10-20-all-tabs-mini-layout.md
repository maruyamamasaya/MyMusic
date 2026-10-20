# 全タブの通常ミニ領域分離

- MATCH。Git root・main・clean確認済み。ユーザーからハイレゾ下部、続いて全画面が対象と指示。
- safeAreaInsetをNavigationStack外へ置く構成が他4tabに残っていた。設定への局所対応では詳細を含む画面全体の保証にならないため、共通BottomPlayerLayoutへ集約。
- VStackでNavigationStackを含むcontentとminiを縦に分け、contentは残り高さ、miniは自然高で配置。5tabすべてへ適用。デザイン・保存・再生経路は維持。設定詳細でもminiを表示するが独立領域へ置く。
- Library／Playlist／Search／Home内のignoresSafeArea、下部overlay等をコード検索し、内容が明示的に下部領域を無視する実装は見つからず。

## 確認

- 既存iPhone 17e Simulator1台、既存合成WAV2曲を使用。新規端末なし。
- ライブラリ末尾「音楽フォルダを追加」を座標tap→Files picker表示、変更せずcancel。
- プレイリスト一覧と空の詳細／編集表示を確認。Simulator専用QA Layout PlaylistをUI作成。多数曲を含む詳細の末尾は未検証。
- 検索QAで2曲の結果、操作の表示を確認。長い結果・ソフトウェアkeyboard表示中は未検証。
- 設定末尾のデータ管理行がminiより上に表示され、座標tapで遷移を確認。詳細でもminiは別領域に残る。
- ホームのScrollViewをCUAのscroll／drag／keyboardで末尾へ移動できず、ホーム末尾の実操作確認は未完了。
- ハイレゾを確認するため、一時的にHomeViewの初期navigation pathをhiResLibraryとし、RootViewのlibrary復元後に合成WAVを再生する検証buildを使用。miniありのハイレゾ画面で末尾192kHzを座標tap→診断表示、診断末尾までscroll確認。実DAC出力保証ではない。ハイレゾ曲の再生と専用miniは未検証。
- 一時変更は/tmpへ退避した元ファイルから復元し、HomeViewのdiffがないこと、RootViewに共通layoutのdiffだけが残ることを確認。
- 最終の通常起動版でiPhone／Watch generic Simulator Debug BUILD SUCCEEDED。ログ/tmp/mymusic-all-tabs-layout-build.log、git diff --check成功。
- 全Navigation destinationの網羅検証ではない。別画面幅・Dynamic Type大・ハイライト復帰は未検証。
- デプロイ・commit・pushなし。XCTest未実行、test端末作成・削除0台。XCTestDevices容量計測対象のtest実行なし。Simulatorは確認後shutdown、最終通常版をinstallして検証用初期表示が残らないようにする。DerivedData削除なし。

## 実機デプロイ

- 後続の明示依頼でgit status確認→check-iphone.sh成功→deploy-iphone.sh実行。
- MyMusic.xcodeproj / MyMusic scheme / Debug / Product MyMusic / maruyama.MyMusic。
- Vespera（00008150-000C54280E33401C）へBuild・Install・Launchすべて成功。ログ/tmp/mymusic-all-tabs-layout-deploy.log。
- 一時検証コードを除去した通常起動版を使用。署名・project設定変更なし。実機操作は未確認、commit・pushなし。XCTest未実行、test端末作成・削除0台。

## 実機確認とmain反映

- ユーザーがVesperaで「下の部分もタッチできるようになった」と確認。全画面・全操作の網羅確認を意味しない。
- 明示依頼により共通BottomPlayerLayout修正と関連文書をmainへコミット・pushする。
