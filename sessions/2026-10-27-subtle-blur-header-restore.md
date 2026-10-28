# 弱いぼかしと従来ヘッダーの復元

Context Guard MATCH、Git root確認。既存作業ツリーを保持。

ユーザーから、グレーの素材が強すぎることとライブラリ／プレイリストのヘッダータイトルが消えるとの報告。今回追加したフル強度のSwiftUI materialをホーム帯、通常mini、HiRes mini、通常／作業用／HiRes再生情報欄すべてから除去し、SubtleBackdropBlurへ置換。UIVisualEffectViewのsystemUltraThinMaterialDarkをUIViewPropertyAnimatorのfractionComplete=0.08で静止表示し、黒40%（通常miniは既存スモーク約40〜43%）を重ねる。解体時にanimatorを停止。文字／操作にはblurしない。ホームの左右いっぱい・角丸なしの帯を維持。透明度低減／高コントラストは不透明を維持。

ThemeScreenModifierはガラスとtoolbarBackground(.visible)を撤去し、以前の黒gradientと標準の表示タイミングへ戻した。LibraryView／PlaylistViewのnavigationTitle宣言は存在することを確認。タイトル文言やnavigation構造は変更していない。

指定iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB）向けDebug build成功（iPhone／Watch）。既存アプリへ上書きinstall・launch成功。terminateは対象processなしの応答、データ削除なし。Auroraホームのスクリーンショット（/tmp/mymusic-subtle-blur.png）でグレーの膜を除いた黒い全幅帯と弱いぼかしを確認。

CUAはSimulatorを名前・bundle ID・絶対pathとも解決できないため、ライブラリ／プレイリストのタイトル、スクロール中、再生画面・mini、Dynamic Type大、各テーマでの描画と操作は未確認。OS更新時のfractional blurの外観・再挿入時挙動・実機負荷は要確認。実機未デプロイ。XCTest未実行、test端末作成0／削除0、XCTestDevices未操作・容量未計測。
