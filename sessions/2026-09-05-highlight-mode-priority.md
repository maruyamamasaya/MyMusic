# ハイライトのモード適合度優先

## 原因

- 旧方式はModeが0.6〜2.0倍なのに対しPreferenceが0.01〜42倍、Recent Highlightが0.20〜1.00倍で、積の大小がモード方向を容易に逆転した。
- 指数分布による重み付き抽選は低weightにも先頭確率があり、明確な適合差もRandomで逆転できた。

## 修正

- アガる／穏やか／発掘は0〜1の適合度を0.05幅のbandへ分け、bandを第一条件として降順にした。
- 同じband内だけPreference × Overplay × Recent Highlightを比較する。
- Randomは第二scoreへの±0.5% jitterへ縮小し、異なるbandには影響させない。
- シャッフルは特徴適合度を使わず、従来要素のscore順を維持する。
- UI、モード、候補生成、再生制御、永続化は変更していない。

## 検証

- `HighlightSelectionPolicyTests`と既存の`PlaybackSelectionPolicyTests`／`PlaybackSelectionIntegrationTests`をiPhone 17 Simulatorで実行し、全15件成功した。
- 極端なPreference／Recent／Randomを与えてもアガる・穏やかの逆傾向曲が適合曲を越えないこと、発掘優先、シャッフル中立、同等候補だけRandomで順序変更することを確認した。
- iOS Simulator Debug build成功。既存のasset catalog／Swift 6 isolation warningのみ。
- 実機操作確認は未実施。

## 多様性追補

- 同一mode band内を先頭から貪欲配置し、直前Artist 4、直近3曲Artist 2、直前Album 4、直近5曲に同Album 2曲以上で3のdiversity penaltyを適用した。
- 主要8特徴量の共通有効次元でRMS距離を計算し、0.08未満だけscoreを0.97倍にした。シャッフルでは特徴距離を使わない。
- モード切替時は保持済み曲列を多様性文脈に渡し、後続queueにも同じ規則を適用する。
- ハイライト／既存選曲テスト全22件成功。Simulator Debug build成功。
