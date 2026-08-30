---
date: 2026-08-30
topic: station-decade-filter
status: complete
---

# 気分ステーションの年代指定

## 変更

- 気分・音・必要時の特徴量補足に続く任意条件として、10年単位の年代質問を追加した。
- 年代候補は通常再生対象かつ特徴量のあるTrackの有効な年metadataから降順で構成する。
- 「すべての年代」は年metadataがない曲も含む従来動作を維持し、年代候補がなければ質問を省略する。
- 指定年代で候補を絞ってから既存の特徴量score、閾値、artist分散を適用する。
- 結果概要へ年代条件と、その年代で選曲対象になった曲数を表示する。

## 検証

- `MoodStationServiceTests`と`StationStoreIntegrationTests`の14件、および全XCTestがiPhone 17 / iOS 26.5 Simulatorで成功した。
- 有効／無効／欠落した年からの年代候補、年代境界、指定年代だけの選曲、年がない従来質問フロー、Dynamic Type / Dark Mode描画を確認した。
- Simulator Debug buildはfresh DerivedDataで成功した。既存のasset catalogとSwift concurrency警告は残るが、今回変更したファイルに新規warningはない。

## 制約

- 年代はTrackの年metadataを10年単位に正規化するため、元tagが欠落・誤記されている場合は補正しない。
- 年代指定時だけ、年metadataがない曲を候補外とする。
- 実音源・実機での年代候補の妥当性と操作感は未確認。
