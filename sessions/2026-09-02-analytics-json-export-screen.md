# Analytics用JSON書き出し画面

## 作業

- 設定の「データ管理」に「Analyticsと同期」へのNavigationLinkを追加した。
- PC版Analyticsが対応するLibrary、Playback Events、Playback Preferences、Track Features、Volume Normalization、Playlists、Equalizer、Genre Display Presetsの8種類を個別に書き出せる一覧画面を追加した。
- JSON生成はすべて既存`MusicDataExportService`を使用し、共有は既存`ActivityShareSheet`を使用した。schema、filename、export内容、Analytics側、再生・履歴保存処理は変更していない。
- 画面にオンライン同期を行わない旨を明記した。通信処理は追加していない。

## 検証

- iOS Simulator Debug build: `BUILD SUCCEEDED`
- `git diff --check`: エラーなし。

## 未確認

- Simulatorまたは実機での8項目それぞれの共有シート操作は未実施。
