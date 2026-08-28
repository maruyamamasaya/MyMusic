---
status: active
date: 2026-08-14
---

# ADR-0002: 完成基準版を維持し新機能を Beta 単位で届ける

## Context

2026-08-14 時点でローカル player の基本体験が一通り成立した。一方、独自機能や streaming 等の拡張候補が多く、一度の大変更は既存の library / playback / search / playlist を回帰させる危険がある。

## Decision

- 2026-08-14 の状態を「完成基準版」として、App Store 正式リリースとは区別する。
- 新機能は小さな Original Features Beta として一つずつ実装する。
- 各 Beta の目的、操作、既知の制約を文書化し、個別に build / 検証する。
- 安定した機能だけを基準版へ昇格する。
- streaming / server integration は明示的に着手するまで将来機能とする。

## Consequences

- 既存の基本フローを受け入れ基準として回帰確認する必要がある。
- Beta 固有の暫定制約は CURRENT と詳細資料に明示する。
- 無関係な複数機能を一つの変更へまとめない。

## Evidence

- `0ff15cd` (`Document completed baseline and beta development workflow`) と、その時点から継続している README の「現在の位置づけ」「次のフェーズ」。
