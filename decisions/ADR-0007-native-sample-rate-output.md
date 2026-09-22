---
status: accepted
date: 2026-09-22
---

# ADR-0007: USB DACでは音源のサンプルレートを優先する

## Context

MyMusicはFLAC、ALAC、WAV、AIFFをAVAudioFileでPCMへdecodeして再生するが、従来はAVAudioSessionへ希望sample rateを設定していなかった。このため、USB DACが音源rateに対応していてもiOSの現在rateへsample-rate conversionされる可能性があり、音源rateと実出力rateの違いもUIから確認できなかった。

一方、再生経路にはfade mixer、音量normalization、user EQ、AVAudioEngine main mixerが存在する。したがって、PCM sample値の完全一致を意味するbit-perfectを保証する設計ではない。

## Decision

- 設定「音源レート優先」を既定ONとする。
- USB Audio routeでは、再生するAVAudioFileのprocessing sample rateを`AVAudioSession.setPreferredSampleRate`へ渡す。
- 希望値は保証値として扱わず、session activation後の`AVAudioSession.sampleRate`を実出力rateの正本とする。
- pause後のresume、USB DAC接続、route構成変更でも現在音源rateを再要求する。USB DAC取り外し時は既存どおり安全のためpauseする。
- 再生画面では音源rateと実出力rateを分離表示し、一致時は「ネイティブレート」、不一致時は「サンプルレート変換あり」と表示する。
- Hi-Res判定はJEITAのCD相当超過例に従い、lossless PCM系音源で、sample rateが44.1kHz以上・bit depthが16bit以上、かつsample rateが48kHz超またはbit depthが16bit超の場合とする。
- 日本オーディオ協会の公式Hi-Res Audioロゴはライセンス対象のため使用せず、独自のテキストbadge「Hi-Res」を表示する。
- upsamplingは情報を増やさないため、DACの最大rateではなく音源rateとの一致を優先する。

## Consequences

- USB DACと音源が同じrateを採用できる場合、不要なsample-rate conversionを避けられる。
- iOSの希望値が採用されない場合も、実測rateと変換有無を利用者が確認できる。
- 曲ごとに44.1kHz系と48kHz系が切り替わると、hardware再構成に伴う短い無音が生じる可能性がある。
- EQ、normalization、fadeを有効にした再生は引き続きPCM sample値を変更するため、UIでbit-perfectとは表示しない。
- USB DACの実機名、対応rate、route change挙動は機器とiOSに依存するため、実機検証を継続する。
- Tea ProではAudio Sessionの非アクティブ化とAVAudioEngine graph再構築を追加しても192kHz音源が44.1kHz出力のままであり、既存再生基盤へのリスクに対して効果がなかったため採用しない。直接PCM出力は現行backendを変更せず、分離したBetaでのみ検証する。
