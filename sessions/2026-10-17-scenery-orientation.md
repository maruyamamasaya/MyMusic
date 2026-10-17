# 車窓モードの自動回転・コミット — 2026-10-17

## 変更

- ユーザー依頼により、ここまでの車窓モード・保存対応・Vespera実機確認の記録をまとめてコミット・pushする。
- 追加要望に合わせ、iPhoneで車窓画面を開くとlandscape、閉じるとportraitへの回転を要求する。
- MyMusicAppDelegateとSceneryOrientationHost／Controllerを追加。車窓表示中だけsupportedInterfaceOrientationsを制限し、破棄時には通常のallButUpsideDownへ戻す。表示中のwindow sceneへUIKit標準のrequestGeometryUpdateを使う。UIDeviceのprivate KVC等は使わない。
- iPadの方向制限は追加しない。plist・project・署名・識別子・Team・Deployment Targetを変更しない。
- システムが横向き要求を拒否した場合は画面へ案内しlogにも記録する。縦向き復帰の拒否はlogへ記録する。
- CURRENT／ARCHITECTURE更新。保存・開き直しランダム再生・変更・解除は従来どおりユーザー実機確認済み。自動回転は別項目として未確認。

## 検証

- 最終Swift変更でiPhone／埋め込みWatch generic Simulator Debug build: **BUILD SUCCEEDED**。
- git diff --check成功。
- 回転はUIKitの画面lifecycleに依存するため、実機での入退出、Files pickerを開いた時の表示、端末回転ロック、background復帰は未確認。
- 今回の自動回転版はVesperaへ未デプロイ。
- XCTest／Simulator testは未実行。test端末作成0／削除0。XCTestDevices残容量12K。Xcode data削除なし。
