# Watch音量操作UI微調整

## 変更

- 再生画面右上の操作を「音量、詳細」の順にし、詳細ボタンを右端へ移した。
- 音量controlは詳細と同じ32ptのlayout枠を使い、標準`WKInterfaceVolumeControl`の表示scaleを0.55から0.65へ拡大した。
- 音量値とDigital Crown入力は引き続き`WKInterfaceVolumeControl(origin: .companion)`へ任せ、WatchConnectivityの独自音量commandは追加していない。

## 判断

- 標準volume controlは選択後にDigital Crownで調整する設計である。画面表示直後からCrownを音量へ固定すると、watchOSのfocus、スクロール、アクセシビリティ操作と競合し得るため採用しなかった。
- タップなし操作を優先する場合も、private APIやiPhoneのシステム音量を模倣する独自実装は行わず、標準controlの範囲で実機検証できる方法だけを候補とする。

## 検証

- `xcodebuild -project MyMusic.xcodeproj -target MyMusicWatch -configuration Debug -sdk watchsimulator CODE_SIGNING_ALLOWED=NO build`: `BUILD SUCCEEDED`。
- AppIntents未使用によるmetadata extraction skipと、複数architectureに対する`ONLY_ACTIVE_ARCH`の既存warningが出たが、今回の変更に関するcompile errorはない。
- paired iPhone／Watch実機での表示サイズとDigital Crown操作は未確認。
