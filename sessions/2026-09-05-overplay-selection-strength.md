# Overplay選曲抑制の強化

## 作業

- iOSのOverplay計算、通常shuffle／Mood Stationへの適用、Preference／Favorite／Boredomとの境界、およびPC版Analytics「おすすめ」との違いを確認した。
- Overplay multiplierを線形の用途別補正から共通の二次カーブ `1 - 0.875 × score²` へ変更した。範囲は1.0〜0.125で、完全除外はしない。
- 詳細仕様の正本を`ARCHITECTURE.md`へ集約し、`CURRENT.md`は現在状態と正本への参照だけに更新した。

## 検証

- `PlaybackSelectionPolicyTests`へScore 0／25／50／75／100%の代表値、Station、境界値、高Preferenceとの積を追加・更新した。
- iPhone 17 Simulatorで`PlaybackSelectionPolicyTests`を実行し、4件すべて成功した（`TEST SUCCEEDED`）。このtest実行によりアプリとtest targetのbuildも成功した。

## 非変更範囲

- OverplayScore計算式、Preference weight表、Favoriteの候補構成、Boredom eligibility、未再生Discovery、作業用再生、Analytics推薦式は変更していない。
