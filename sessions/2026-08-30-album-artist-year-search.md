---
date: 2026-08-30
topic: album-artist-year-search
---

# Album Artist / 年代検索

## 作業

- 検索対象へ「アルバムアーティスト」と「年代」を追加した。
- 複合条件へAlbum Artistの部分一致・完全一致・除外と、年の完全一致を追加した。
- 年代条件の候補は、現在のライブラリにあるTrackの年metadataから降順で構成する。
- Album Artist / 年代検索は一致Trackからアルバム結果を構成し、結果行にも年を表示する。
- 従来のArtist検索はTrack ArtistとAlbum Artistの両方を対象とする互換動作を維持した。

## 検証

- iPhone 17 / iOS Simulator向けDebug `build-for-testing`: 成功。
- iPhone 17 / iOS Simulatorの全XCTest: 成功。
- Album Artist専用検索がTrack Artistへ誤一致しないこと、年metadata検索、両方の複合条件をXCTestへ追加した。

## 制約

- Album Artistまたは年metadataがないTrackは、それぞれの専用検索には一致しない。
- 実機と実音源での表示・操作確認は未実施。
