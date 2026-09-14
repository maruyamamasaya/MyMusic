# Watch Artwork再試行とPlaylist管理改善

## 作業

- WatchのArtwork要求が一時失敗後に要求済みのまま残る問題を修正した。Watch側は要求送信・timeout・file読込失敗、iPhone側は画像準備・file転送失敗を最大3回まで再試行する。
- iPhone側のArtwork送信管理をTrack IDだけでなくArtwork identifierとの組み合わせにし、同一Trackの埋め込みArtwork更新も再転送する。
- Playlist画面に専用のタグ管理ページを追加し、全タグの使用数、名称変更、削除、通常／作業用Playlistへの割り当てを提供した。
- 曲をPlaylistへ登録する追加先選択画面で、選択したPlaylistタグフィルターを通常／作業用別に保存し、次回の登録時に復元するようにした。保存したタグが存在しなくなった場合は安全に「すべて」へ戻す。Playlist詳細の曲一覧へはフィルターを追加しない。
- ホームのチューニングは既存の見出し・現在値・カプセルUIを維持し、下層surfaceと外枠だけを削除した。
- `MusicLibraryService`のdefault checkpoint生成をMainActor convenience initializerへ分離し、Swift concurrency警告を解消した。
- AnalyzerのPython 3.10互換SHA-256 fallback、Analyticsの日付依存／Windows path testを修正した。

## 検証

- `xcodebuild` generic iOS Simulator Debug build: `BUILD SUCCEEDED`。iPhone／Watchを含み、AppIntents未使用による既知のmetadata warning以外のSwift warningなし。
- iPhone 17 Pro / iOS 26.5 Simulator、並列test無効で`PlaylistTagStoreTests` 4件成功。
- Python 3.10.4でAnalyzer／Semantic unittest 38件成功。
- Analytics Python unittest 52件成功。
- `XCTestDevices`は開始時UUID folder 0件、合計12KB。既存Simulatorを1台だけ使用した。

## 未検証

- Watch Artworkの実機間転送、到達性復帰、実際の転送失敗時retryは署名・Watch接続復旧後に確認する。
- Playlistタグ管理、追加先Playlistの保存フィルター、ホームのチューニング表示は実機UIで未確認。
