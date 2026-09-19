---
status: active
updated: 2026-09-19
---

# 再生中のビジュアル（Visual World）現行仕様

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
| Plasma Spark | `plasma-spark` | 蛇行する紫・シアン・ローズの電流、走る電荷、火花。詳細は[Plasma Spark](NowPlayingVisualWorld-PlasmaSpark.md) |
| Visualizer | `visualizer` | PCMの48点波形、FFTの24帯域バー、流れる粒子。詳細は[Visualizer](NowPlayingVisualWorld-Visualizer.md) |

旧`living-aurora`のビジュアル選択と、独立設定のない旧Living Auroraテーマ由来の初期値はPhoton Sphereへ読み替える。既存の画面テーマ自体は変更しない。

## 入力と描画の境界

`SettingsStore`が種類を所有する。曲の特徴量は`TrackFeatureStore`、再生中の音声解析結果とセッションseedは`PlayerStore`から受け取る。Artworkの代表色・副色・accentは`VisualWorldPaletteService`が抽出する。音声解析は既存の出力tapを共有し、表示用に24帯域、低・中・高域、flux、音程感、48点波形を生成する。`VisualWorldSimulation`が表示用の動きと余韻を管理し、`VisualWorldMetalView`と`VisualWorldInstallation.metal`が通常描画する。Metal初期化失敗時は`VisualWorldScene`のCanvas描画へ切り替える。ビジュアルのために音源、EQ、再生queue、永続化JSONを変更しない。旧来の32区間`spectrumLevels`は周波数帯域として扱わない。

前面・scene active・再生状態・アクセシビリティ・熱状態に応じて描画と追加解析を制御する。通常は最大30fps、低電力時20fps、thermal serious時15fps、critical時は静止する。Reduce Motion、透明度低減、コントラスト増加でも静止表示とする。一時停止後の動きは有限の余韻を残し、約10秒以内に休止する。GPU未完了frameは最大2件で、待ちによって再生やMainActorを塞がない。

## 検証状態と履歴

現行構成のSimulator buildと、一部の実機Debug導入は[CURRENT.md](../CURRENT.md)に記録している。6種類すべてについて実機での連続表示、熱・電力、VoiceOver、Dynamic Typeの最終確認は未完了。

[Beta 2](NowPlayingVisualWorld-Beta2.md)と[Beta 3の旧造形案](NowPlayingVisualWorld-Beta3.md)は履歴であり、現行操作・造形の仕様ではない。設計上の採用理由は[ADR-0006](../decisions/ADR-0006-visual-world-rendering.md)を参照する。

6種類の構成比較と実機での評価項目は[作品レビュー](NowPlayingVisualWorld-Review.md)を参照する。
