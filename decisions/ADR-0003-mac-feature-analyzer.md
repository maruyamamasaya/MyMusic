---
status: active
date: 2026-08-27
---

# ADR-0003: 音楽特徴量を Mac で解析し versioned JSON で取り込む

## Context

約2万曲も想定する特徴量解析では、iPhone の再生品質と負荷を守りつつ、再開可能で再現しやすい処理が必要だった。Essentia の学習済み model も検討されたが、macOS ARM の TensorFlow / Homebrew build と追加依存の再現性が課題として記録されている。

## Decision

- iPhone では解析、再エンコード、全曲 SHA-256 を行わない。
- Mac の逐次 Python CLI で librosa / Mutagen / SoundFile を用いた決定論的 DSP Beta v1 score を計算する。
- SQLite cache で中断・再開し、schemaVersion / analysisVersion を持つ JSON contract で iPhone に渡す。
- iPhone は path、file size、duration、metadata の保守的な規則で Track と照合し、特徴量を Track 本体から独立して保存する。
- score を学習済み分類器の確率として表示しない。

## Consequences

- iPhone の音源と playback path を変更せず、特徴量を削除しても library / playlist / history に影響しない。
- JSON schema と matching compatibility が app / analyzer 間の境界になる。
- heuristic の妥当性は少数曲と聴感で検証する必要がある。
- content hash、trained model、parallel processing は将来拡張であり現行 contract の機能ではない。

## Evidence

- `Documentation/TrackFeatureBeta1.md` の安全な import / matching 方針。
- `analyzer/README.md` の「採用方針」と実行・cache・schema の説明。
- 2026-08-27 の Track Feature 実装履歴と `Documentation/TrackFeatureBeta3.md` の検証記録。
