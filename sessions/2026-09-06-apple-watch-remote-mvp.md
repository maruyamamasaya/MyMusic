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
