---
status: active
date: 2026-08-28
---

# ADR-0001: View → Store → Service の責務境界を維持する

## Context

既存の `AGENTS.md` と `README.md` は一貫して View → Store → Service → Model / Apple Framework を基本構成として示し、実コードも `Views/`、`Stores/`、`Services/`、`Models/` に分離されている。再生では SwiftUI View から AVFoundation を直接扱わず、`PlayerStore` を経由して `AudioPlayerService` を利用している。

## Decision

- View は presentation と user interaction に限定する。
- `@Observable` Store は MainActor 上の application / screen state と Service の調整を担う。
- Service は playback、file、metadata、persistence、analysis 等の実操作を担う。
- Model は data contract とし、UI logic を持たせない。
- とくに AVFoundation による再生は `AudioPlayerService` に隔離する。

## Consequences

- View の preview / 分割と、Service / business logic の test がしやすくなる。
- 新しい機能は既存 Store / Service の責務を確認し、必要な境界だけを追加する。
- 簡単な UI 変更でも Service を直接呼ぶ近道は採らず、必要なら Store API を用意する。

## Evidence

- 2026-08-14 の baseline 文書化 commit (`0ff15cd`) に含まれる README / agent guide。
- 現在の directory layout と `MyMusicApp` の environment injection。
