# ホーム代表アートワークのパフォーマンス改善

## 作業

- Home Destinationごとの代表候補、代表Track、artwork identifier、即時再生可否を一つのsnapshotへ事前計算した。
- `representativeCandidateIDs`による再描画ごとの候補ID生成を廃止し、関連Storeの軽量revision通知で実データ変更時だけsnapshotを更新するようにした。
- 表示中の代表Trackを即時再生queueの先頭へ置く既存契約は維持した。
- HomeのPlaylist／作業用PlaylistはLibrary／Playlist変更時に全Playlistを一つのTrack ID indexから解決し、同じPlaylistの結果を画像、件数、再生可否に再利用した。
- ArtworkServiceへdecode済みUIImage cacheを追加し、UIImage生成をMainActor外へ移した。
- entitlement警告を発生させる`MPNowPlayingInfoCenter.playbackState`の直接設定を削除した。Now Playing metadata、経過時間、playback rate、artwork、Remote Command処理は維持した。

## 検証

- iPhone 17 / iOS 26.5 Simulatorの全XCTest: 初回は成功。最終再実行では今回未変更の非同期テスト（`StationStoreIntegrationTests` 4件、`LibraryGenreFilterTests` 1件）が待機中stateのまま失敗した。Home代表曲Policyを含む他テストは成功した。
- iOS Simulator Debug build（署名なし）: `BUILD SUCCEEDED`。
- `git diff --check`: 成功。

## 未検証

- 実ライブラリを使った連続縦横スクロール、gesture gate timeoutの非再現、ロック画面操作は実機での手動確認が必要。
