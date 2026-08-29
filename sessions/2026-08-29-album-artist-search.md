# Album Artist と検索負荷改善

## 作業

- `Track`へoptionalな`albumArtistName`とmetadata revisionを追加し、旧JSON decodeを維持した。
- AVFoundationのiTunes Album Artist、次にID3 TPE2（Band/orchestra/accompaniment）からAlbum Artistを抽出した。
- Album keyを`albumTitle + (albumArtistName ?? artistName)`へ変更した。Album表示も同じartistを使用し、Artist一覧はTrack Artistのまま維持した。
- 統合前のTrack Artist別Album IDをfavorite互換aliasとして保持した。
- keyword／複合Artist条件をTrack ArtistまたはAlbum Artistに一致させた。`含まない`は両方に含まれない場合だけ成立する。
- `TrackSearchStore`に225ms debounce、前Task cancel、結果stateを追加した。全曲検索とAlbum／Artist結果導出は専用actorで実行し、64曲ごとにcancelを確認する。
- `SearchView`はquery、filter、library tracks、playback history変更時だけ検索snapshotを更新する。Player／Audio sessionには変更を加えていない。
- 保存検索playlistの明示同期も同じ検索actorを経由し、画面離脱時にTaskをcancelする。

## 検証

- iPhone 17 / iOS 26.5 SimulatorでXCTest 38件成功（新規7件を含む）。
- Debug Simulator build成功。
- `git diff --check`成功。

## 制約・未解決

- 旧library cacheは即時に読み込めるが、Album Artist値の取得には一度手動で再スキャンする必要がある。metadata revisionにより旧Trackだけを一度再抽出する。
- Album ArtistはAVFoundationが安全に公開するiTunes keyとID3 TPE2のみを対象とし、独自atom／frame parserは追加していない。
- Simeji / RTIInputSystemClient等のkeyboardログをMyMusic固有エラーとは扱わず、ログ抑止処理は追加していない。
