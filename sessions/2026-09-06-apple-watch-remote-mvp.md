---
date: 2026-09-06
topic: apple-watch-remote-mvp
status: implemented
---

# Apple Watch リモコン MVP

## 作業

- iPhoneアプリへ`WatchConnectivityService`を追加し、Watch commandを既存`PlayerStore`の`resume`、`pause`、`togglePlayPause`、`next`、`previous`へ接続した。
- `PlayerStore`の現在曲・再生状態・位置・長さをversion付きmessageとしてWatchへ配信するようにした。
- `MyMusicWatch` target、`WatchSessionManager`、SwiftUIの再生中画面を追加した。Watch側は受信状態のみを正とし、非到達時は操作を無効化して安全な案内を表示する。
- command／状態dictionaryの往復テストを追加した。

## 検証

- `plutil -lint MyMusic.xcodeproj/project.pbxproj`: OK。
- `xcodebuild -project MyMusic.xcodeproj -target MyMusicWatch -configuration Debug -sdk watchsimulator CODE_SIGNING_ALLOWED=NO build`: BUILD SUCCEEDED。
- iPhone＋Watch統合schemeは、環境がwatchOS 26.5 runtime未導入と判定するため開始前に停止した。埋め込みとtarget dependencyだけを一時的に外して同じiPhone schemeをbuildし、新規iPhone通信コードを含め`BUILD SUCCEEDED`を確認後、project設定を復元した。
- 同じ一時的な切り分けで`WatchPlaybackMessageTests` 3件をiPhone 17 Simulatorで実行し、`TEST SUCCEEDED`を確認後、project設定を復元した。

## 未確認・後続

- paired iPhone／Apple Watch Simulatorまたは実機でのcommand往復と、iPhone側変更の表示反映。
- 実Artwork転送（MVPはplaceholder）。

## 実機ログ対応

- activation前は最新状態を保留し、`updateApplicationContext`／`sendMessage`を呼ばないよう修正した。
- iPhone側送信条件へpaired／Watch App installedを追加し、activation完了とWatch状態変化後だけ最新値を強制同期する。
- Watch側のreachability callbackもactivation完了を送信条件に含めた。
- 存在しない`clock.badge.plus`を`clock`へ置換した。
- Watch targetと、埋め込みを一時切り離したiPhone schemeはいずれも`BUILD SUCCEEDED`。実機でのログ解消確認は未実施。

## Artwork・曲Preference拡張

- version 1 stateへ後方互換なoptional fieldとして`isFavorite`、`playbackPreference`、`hasArtwork`を追加し、favorite toggle、preference ±1、Artwork要求commandを追加した。
- WatchはTrackごとにArtworkを一度だけ要求する。iPhoneは既存Artworkをactor内で元画像を拡大せず最大512px・品質0.82のJPEGへ変換し、stateと分離した`transferFile`で送信する。一時fileは転送完了時に削除し、Watchは現在画像だけをmemory保持する。
- Watchのお気に入り／Good／Badは`TrackPreferenceStore`の既存APIへ接続し、iPhone側の同Store変更もWatch stateへ反映する。
- iPhone scheme（Watch embeddingのみ一時切り離し）とWatch targetは`BUILD SUCCEEDED`。通信契約5件とArtwork変換1件はiPhone 17 Simulatorで`TEST SUCCEEDED`。
- paired Watch Simulator／実機でのfile transfer、操作往復、レイアウトは未確認。

## Digital Crown音量

- `WKInterfaceVolumeControl(origin: .companion)`を`WKInterfaceObjectRepresentable`でSwiftUI画面へ追加した。
- WatchKitがペアリング中iPhoneのシステム音量、表示値、選択時のDigital Crown入力を直接管理する。WatchConnectivity commandと独自volume stateは追加していない。
- Crown scrollとの競合を避けるため画面は非scroll containerのままとし、標準controlのfocus動作に任せる。

## 再生画面UI改善

- 受信済みArtworkを全面`scaledToFill`背景とし、未取得時は暗いgradientと音符をfallbackにした。
- 全面に上部0.78／中央0.48／下部0.82の黒gradient overlayを置き、白文字・白系controlのcontrastを確保した。
- 上部metadata、中央58pt再生停止、下部46×44ptの前／標準音量／次へ再構成した。既存のお気に入り／Good／Badは最下段の副操作として維持した。
- scroll containerは追加せず、Digital Crownは標準volume controlを選択した時だけ音量へ使う。
- watchOS Simulator SDK向けWatch target buildは`BUILD SUCCEEDED`。paired実機でのtap、Crown、各case sizeのvisual確認は未実施。

## Artwork画質・操作配置調整

- 全面背景向けArtworkを最大192px・品質0.72から、元画像を拡大しない最大512px・品質0.82へ変更した。アスペクト比とTrack単位の要求抑止、`transferFile`別送は維持する。
- 全画面のSafe Area無視をやめ、背景と黒overlayだけをSafe Area外へ延長した。metadataはシステム時刻と重ならないSafe Area内へ置く。
- 前／再生停止／次を同じ50×50ptの横一列へ揃え、中央再生停止だけ白い円で強調した。標準音量controlは独立した右下段へ移した。
- Watch targetは`BUILD SUCCEEDED`。512px上限・JPEG・1px元画像を拡大しないテストはiPhone 17 Simulatorで`TEST SUCCEEDED`。

## Watch SE基準レイアウト再構成

- 全面背景をSafe Area内の固定`frame(width:height:)`へ閉じ込めず、Artworkと黒gradientだけを`ignoresSafeArea`で表示領域全体へ延長した。前景はGeometryReaderのsize／Safe Areaから余白と操作径を計算する。
- 画面高を圧迫していたFavorite／Good／Badの常設行を省スペースなsheetへ移し、曲情報、任意の進捗、前／再生停止／次、独立した音量だけを一画面へ配置した。再生3操作は同径44〜52pt、左右対称の横一列を維持する。
- 40mmでは標準`WKInterfaceVolumeControl`の外周描画が下端へ掛からないよう、音量領域を28pt高・40pt幅にし、行を6pt上へ補正した。44mm以上は38pt高・48pt幅とし、主要再生操作の幅は削らない。
- `PreviewProvider`へSE 40mm、SE 44mm、Ultra 49mmを追加した。3 SimulatorへDebug appをinstall／launchして目視確認し、背景fallbackの端の隙間なし、時計との非重複、長文truncate、3操作の同一line・左右対称、音量の別配置、一画面内収容を確認した。実ArtworkとDigital Crown操作はpaired iPhoneが必要なため未確認。
- Watch targetは`BUILD SUCCEEDED`。iPhone 17 SimulatorでArtwork変換2件とWatch通信契約5件を実行し、`TEST SUCCEEDED`。
