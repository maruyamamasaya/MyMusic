---
status: accepted
date: 2026-08-29
---

# ADR-0004: Mac解析の固定ゲインで控えめな音量ノーマライズを行う

## Context

ライブラリにはマスタリング年代や入手元による大きな音量差がある一方、全曲を同じ音圧へ揃える処理、音源の書き換え、iPhone上の全曲解析、曲中で追従する圧縮はMyMusicの非破壊・軽量な再生方針に合わない。既存のMac Analyzer、schema v1 JSON、TrackFeature照合、AVAudioEngineのfade / EQ経路との互換性も必要だった。

## Decision

- Mac AnalyzerでFFmpeg `loudnorm`を解析用途だけに実行し、全曲のIntegrated LUFSとTrue Peakを測定する。音声ファイルは出力・変更しない。
- target -14 LUFS、無補正範囲 -17...-11 LUFS、最大±4 dB、True Peak ceiling -1 dBTPの固定ポリシーで`normalizationGainDB`を算出する。
- ラウドネスcacheを既存DSP cache keyから分離し、旧DSP結果を再計算せず音量情報だけをbackfillできるようにする。
- schema v1の任意fieldとして3値を追加する。欠落時は0 dBとし、Semantic v2との前後のimportでも音量値と分類値を相互に保持する。
- iPhoneではTrackごとの固定ゲインを専用のAVAudioUnitEQ global gain段へ適用する。fade mixer、ユーザーEQ、音源データから分離し、OFFまたは0 dBではbypassする。
- コンプレッサー、リミッター、曲中の動的ゲイン追従は導入しない。

## Consequences

- 通常範囲と未解析曲は既存音量のままになり、設定初期値OFFで既存ユーザーへの影響を避けられる。
- 全曲Integrated LUFS測定は全音声を走査するため、既存の区間DSP解析より時間がかかる。
- -1 dBTP ceilingは元音源と固定ゲインに対する制約であり、後段のユーザーEQによるピーク増加を防ぐリミッターではない。
- 将来の補正モードはMac側`NormalizationPolicy`と設定構造を拡張して導入できるが、現時点では控えめな1種類だけを提供する。
