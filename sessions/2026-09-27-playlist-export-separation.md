# Playlist書き出しの通常／作業用分離

## 作業

- 完全同期用`MyMusic-Playlists.json`の解決元を通常表示中のTrackから`unfilteredTracks`へ変更し、作業用PlaylistのTrackが書き出し時に欠落しないようにした。
- `MyMusic-Regular-Playlists.json`と`MyMusic-Work-Playlists.json`を追加した。前者は通常Playlistと非作業用genre曲、後者は作業用Playlistとgenreに「作業用BGM」を持つ曲だけを含む。
- 20分以上などのduration条件は追加していない。長尺でもgenreがAmbientの曲は通常側として扱う。
- データ管理とAnalytics同期画面へ分割書き出しを追加した。Analytics ZIPは完全snapshotとして従来の統合版だけを含む。

## 検証

- `git diff --check`成功。
- generic iOS Simulator Debug build成功。
- iPhone 17e / iOS 26.5 Simulatorを1台だけ使用し、`AnalysisDataExportTests` 5件を並列OFF・worker 1で実行して全件成功した。
- 統合Playlist Track IDがLibrary Track ID集合の部分集合であること、通常／作業用のkindと曲分類、1時間のAmbient曲が作業用版へ入らないことを追加テストで確認した。
- 専用lint設定は確認されていないため、lintは実行していない。

## 制約

- 旧仕様で作業用Playlistへ保存されたgenre未指定の長尺曲は、統合版には保持されるが、現在のgenre契約に従い作業用分割版には含めない。
