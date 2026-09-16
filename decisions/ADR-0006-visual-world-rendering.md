---
status: accepted-for-beta
date: 2026-09-16
---

# ADR-0006: Visual Worldの音響解析と描画を再生経路から分離する

## Context

巨大構造の遮蔽・反射・材質と、実音のスペクトラム／音程感が必要。既存Canvasと32区間の時間領域ピークだけではその情報を持たない。再生音源・EQ・キューの品質と意味を保つ。

## Decision

- 出力tapは増やさず既存tapを共有。追加PCMの受け渡しは事前確保slotとatomic所有権。満杯なら映像sampleだけをdropする。
- FFT／調波salienceはserial utility queueで最大20Hz。generationとtimestampで古い結果を無効にする。ViewからAVFoundationを操作しない。
- 表示の力学はSimulationに、描画はMetal／MTKViewに分離。Metalは限定した幾何交差と反射を使い、無制限のraymarchや多重反射を避ける。
- 30fpsを基準とし、解像度・反射・粒子・fpsの品質段階を設ける。GPUを待って音声やMainActorをblockしない。初期化不能時はCanvas fallback。
- 新しい永続化schema、Swift package、再エンコード、署名変更は導入しない。

## Evidence / Limits

Simulator向けSwift／Metal build、macOSの実ソースXCTest 10件、Mac GPUによる4テーマと20秒の合成入力の描画を確認。iPhone実機での熱・電力・長時間の音切れ・Bluetooth同期は未検証。初回Betaの採用であり、完成基準版への昇格を意味しない。

## 造形の改訂

同日のユーザー指示により幾何構造と反射面のアート方向を撤回し、単一の発光球体へ置換。Metal採用・解析分離・有界処理の判断は維持し、描画は球体内部の最大18 step samplingを使用する。
