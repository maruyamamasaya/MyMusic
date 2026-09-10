# 音楽史ランキング50位表示

## 作業

- 年別と月別の曲／アーティストランキング集計上限を10件から50件へ拡張した。
- 年別概要はアーティストTOP5、曲TOP10、月別概要は曲／アーティストTOP10を維持した。
- 概要件数を超えるランキングがある場合、「続きを見る」から順位・Artwork・再生回数を並べた専用画面へ遷移するようにした。
- 曲ランキングから既存の曲別音楽史への遷移を維持した。
- 月の「この頃を再生」は既存の最大25曲を維持し、ランキング表示件数とは分離した。

## 検証

- `xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/MyMusicHistoryRankingDerivedData CODE_SIGNING_ALLOWED=NO build`
- `BUILD SUCCEEDED`

## 未解決事項

- なし。
