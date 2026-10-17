# Sony Bluetoothでの再生ヨレ調査

## 観測

- ユーザー報告: 古いSony Bluetooth機器で頻繁に一瞬音がヨレる。他のヘッドフォン・新しいBluetooth機器では問題なし。
- 同じSony・同じ曲を別アプリで再生すると少ない。通常再生・画面ロック中のMyMusicでも発生。
- 型番、音源形式、実出力rate、実際のbuffer時間、症状発生時の計測は未取得。故障・性能退行・library件数との因果は未確定。

## 静的調査

- Git root一致、開始時作業ツリーclean。AudioPlayerService、PlayerStore、可視化解析、曲別位置保存、NowPlaying、関連履歴とADR-0007を確認。
- 通常経路はAVAudioFile → AVAudioPlayerNode.scheduleSegment → transition mixer → normalization EQ → user EQ → main mixer → iOS出力。速度・pitch調整unitなし。音源rateで処理し、main mixer以降は出力に合わせる構成。
- preferred sample rate要求はUSB限定。preferred I/O buffer durationは未指定（短い値を強制しているわけではない）。tapの2,048 framesは解析用であり出力buffer指定ではない。
- tap自体は通常再生にも残るが、可視化／metricsが無効なら早期return。Visual WorldとAudioInformationはscene非activeで解析を無効にする。解析有効時の配列生成・MainActor Task発行には改善余地があるが、lock中の症状原因と断定しない。
- 0.5秒timerは位置通知用。7秒ごとの位置保存は対象曲のみをactorで保存。15秒ごとの履歴時間更新も対象曲の保存。音声callback内で2万曲全体を走査する実装は確認されない。ただし他Storeの同時処理やメモリ圧迫を静的調査のみで除外しない。
- route changeは監視するが、engine configuration changeの専用監視・復旧と、buffer/latency/engine状態の診断記録はない。configuration changeはApple仕様上engine停止を伴うため、頻繁な一瞬のヨレと直結する証拠ではない。
- 最後のAudioPlayerService変更（2026-10-04）はpause時timer停止など。直近の車窓変更が通常音声経路を直接変更した証拠は得られていない。

## 結論・次段階

- 静的調査で根本原因は特定できない。Sony故障や2万曲・150GBによる性能劣化とは判断しない。
- ユーザー方針: 他のBluetooth機器では正常なため、現時点では事例の記録までとし、追加計測・修正は困った際の再相談で再開する。
- 次は実機で実出力rate、I/O buffer duration、output latency、route/engine configuration通知、CPU/audio処理を発生時刻と対応づける。必要ならその後Bluetooth限定buffer希望値の比較を行う。buffer増量は改善保証でなく、Sony受信bufferの変更でもない。
- アプリコード・音声設定・architectureは変更せず。実機deploy、build、testは未実施。test端末の作成・削除なし。

## 参照

- https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification
- https://developer.apple.com/documentation/avfaudio/avaudiosession/iobufferduration
- https://developer.apple.com/documentation/avfaudio/avaudioengine/mainmixernode
