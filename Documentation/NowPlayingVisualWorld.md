---
status: active
updated: 2026-09-20
---

# 再生中のビジュアル（Visual World）現行仕様

## 最新状況（2026-09-20）

この文書は**現在の作業ツリーにある6種類の実装**をまとめたもの。直近のVisualizer／Plasma Sparkの変更は未コミットで、正式リリース版を示すものではない。旧Beta資料より、この文書と実装コードを現行状態として扱う。

- **実装**：6種類を選択でき、選択は画面テーマとは独立して保存・バックアップされる。通常描画はMetal、初期化失敗時はCanvasへ切り替わる。
- **直近の変更**：Plasma Sparkはピーク時だけ現れる細い主放電と、画面端まで届く最大2本の枝に変更。Visualizerは中央の一本の48点PCM波形、Photon Sphereと共通の微小光子、短い円形波紋に整理した。旧Visualizerのバー、フィラメント、多種類の波紋、独立粒子バーストは描画しない。
- **確認済み**：Visual Worldのロジックテスト14件、iOS Simulator build、Vespera向けDebug実機build・install・launchが成功。Canvasの390×844画像で静穏・低域・中域・高域の波形とPlasmaの枝を目視確認し、静穏時に見えた横長の光の帯は修正後の画像で消失した。
- **未確認**：6種類を同じ実音源で連続鑑賞した実機評価、今回のiPhone上のMetal描画画像、長時間の熱・電力、VoiceOver／Dynamic Type。CometのWatch Appは同じ実機buildに埋め込まれたが、今回の直接installはCoreDeviceServiceの初期化タイムアウトで未完了。Watchはビジュアル描画の対象画面ではない。

変更と検証の詳細は[2026-09-20の作業記録](../sessions/2026-09-20-visual-world-refinement.md)を参照する。

## 画面と操作

通常の再生中画面とアート画面は同じシート内にあり、右上のボタンで切り替える。作業用再生画面は別画面。アート画面左上のメニュー、または設定 → デザイン → 再生中のビジュアルで描画種類を選ぶ。選択は両画面で共有し、アプリ全体のテーマとは独立して保存・バックアップする。

アート画面の下部には小さなArtwork、曲名、アーティスト名、前へ・再生／一時停止・次へ・いいね・グッドをまとめたバーを常時表示する。バー以外の領域は1回タップで再生／一時停止、2回タップでいいねを切り替える。両タップは排他的に判定する。曲の詳細操作は通常画面へ切り替えて行う。背景スワイプ、長押し、隠れたコントローラー、詳細パネルは現行実装にない。

## 選択できる描画

| 表示名 | 保存ID | 描画 |
| --- | --- | --- |
| Photon Sphere | `simple-dark` | 固定外形の光の球、内部粒子と光、外周の微小な光子と衛星球。詳細は[Photon Sphere](NowPlayingVisualWorld-PhotonSphere.md) |
| Pulse Neon | `pulse-neon` | 奥から手前へ進む光のゲート。交差梁、ダイヤ、六角形、山形、段付きフレームの5形 |
| Blue Cosmos | `blue-cosmos` | 青い夜空、星雲、緩やかに漂い明滅する星 |
| 薄明 | `twilight` | 画面上部約8割の青い夜空、少なく暗い星、下側の暖色の地平線と雲 |
| Plasma Spark | `plasma-spark` | 24構図から選ぶ細い白熱放電、画面端まで伸びる枝、紫・シアン・ローズのGlowと微小光子。詳細は[Plasma Spark](NowPlayingVisualWorld-PlasmaSpark.md) |
| Visualizer | `visualizer` | 中央の一本の48点波形、Photon Sphereと共通の微小光子、短い円形波紋。詳細は[Visualizer](NowPlayingVisualWorld-Visualizer.md) |

旧`living-aurora`のビジュアル選択と、独立設定のない旧Living Auroraテーマ由来の初期値はPhoton Sphereへ読み替える。既存の画面テーマ自体は変更しない。

## 入力と描画の境界

`SettingsStore`が種類を所有する。曲の特徴量は`TrackFeatureStore`、再生中の音声解析結果とセッションseedは`PlayerStore`から受け取る。Artworkの代表色・副色・accentは`VisualWorldPaletteService`が抽出する。音声解析は既存の出力tapを共有し、表示用に24帯域、低・中・高域、flux、音程感、48点波形を生成する。`VisualWorldSimulation`が表示用の動きと余韻を管理し、`VisualWorldMetalView`と`VisualWorldInstallation.metal`が通常描画する。Metal初期化失敗時は`VisualWorldScene`のCanvas描画へ切り替える。ビジュアルのために音源、EQ、再生queue、永続化JSONを変更しない。旧来の32区間`spectrumLevels`は周波数帯域として扱わない。

前面・scene active・再生状態・アクセシビリティ・熱状態に応じて描画と追加解析を制御する。通常は最大30fps、低電力時20fps、thermal serious時15fps、critical時は静止する。Reduce Motion、透明度低減、コントラスト増加でも静止表示とする。一時停止後の動きは有限の余韻を残し、約10秒以内に休止する。GPU未完了frameは最大2件で、待ちによって再生やMainActorを塞がない。

## 検証状態と履歴

最新の検証・導入結果はこの文書の「最新状況」と[CURRENT.md](../CURRENT.md)に記録している。実機での6種類の連続表示、熱・電力、VoiceOver、Dynamic Typeの最終確認は未完了。

[Beta 2](NowPlayingVisualWorld-Beta2.md)と[Beta 3の旧造形案](NowPlayingVisualWorld-Beta3.md)は履歴であり、現行操作・造形の仕様ではない。設計上の採用理由は[ADR-0006](../decisions/ADR-0006-visual-world-rendering.md)を参照する。

6種類の構成比較と実機での評価項目は[作品レビュー](NowPlayingVisualWorld-Review.md)を参照する。
