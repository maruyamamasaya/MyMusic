# Search result pagination performance

## 目的

約10,000曲のLibraryで広い検索条件を使った際のList生成、不要な派生結果構築、SwiftUI body内の全件処理を抑える。

## 変更

- `SearchView`の曲／Album／Artist結果を100件単位の段階表示にした。検索条件またはLibrary等のrevision変更時は先頭100件へ戻す。
- `TrackSearchWorker`は選択中の検索fieldに必要なpresentation結果だけを構築する。
- 検索中stateを追加し、debounce／actor処理中に空結果画面を表示しない。
- playlist対象件数は検索時に一度集計する。保存時だけ全結果から対象Trackを解決する。
- 表示ページとは独立して全検索結果を保持し、再生queueと検索playlistの意味を変更しない。

## 検証

- generic iOS Simulator Debug build: 成功。
- `AlbumArtistLibraryTests` 4件、`AlbumArtistSearchServiceTests` 5件、`SongsViewArrangementTests` 3件、`TrackSearchStoreTests` 3件の計15件が成功。
- 100→200件、9,900→9,950件、上限到達時のpagination境界を確認。
- test前後の`XCTestDevices`はUUID folder 0件、合計12 KB。新規test端末の作成・削除は0件。
- 専用lint設定は確認されていない。

## 未確認

- 実機約10,000曲での検索入力latency、連続scroll、allocation／peak memory。
- 今回は実機deployを依頼されていないため未実施。
