# 音楽特徴量 Beta 1

## 目的

Macで解析済みの音楽特徴量をMyMusicへ安全に読み込み、既存Trackとは独立した補助データとして保存する。
Beta 1はiPhone上で音響解析、音源の再エンコード、全曲SHA-256計算を行わない。

## Import操作

「設定」→「音楽特徴量」→「特徴量JSONを読み込む」からFiles上のJSONを選ぶ。
Import後は合計、照合成功、未照合、曖昧、新規保存、更新、旧analysisVersionによる未更新件数を表示する。

## Schema

確定schemaは[track-feature-schema-v1.json](track-feature-schema-v1.json)、生成例は
[track-feature-v1.example.json](track-feature-v1.example.json)を参照する。

- `schemaVersion`: JSON構造のバージョン。Beta 1は整数`1`のみ。
- `analysisVersion`: 解析モデル・特徴量定義のバージョン。1以上の整数。同一Trackには同じ版または新しい版だけを保存する。
- `generatedAt`: Mac側で解析結果を生成したRFC 3339日時。小数秒あり／なしを受理する。
- `relativePath`: Mac側で選んだ音楽ライブラリrootから音源までの相対パス。絶対パスと`.`／`..`成分は禁止。
- `fileSize`: 音源ファイルのbyte数。
- `duration`: 秒単位の再生時間。
- `modificationDate`: 任意のRFC 3339日時。Beta 1では保存するが照合条件にはしない。
- `contentHash`: 任意のSHA-256（64桁hex）。Beta 1では保存するが、iPhone側で生成・照合はしない。
- `title` / `artist` / `album`: フォールバック照合用の任意metadata。フォールバックにはtitleとartistの両方が必要。
- `features.tempo`: 任意のBPM。0より大きい有限値。
- `features.integratedLUFS` / `truePeakDBTP` / `normalizationGainDB`: 任意の音量解析3項目。指定時は3項目すべてを含め、補正値は`-4.0...4.0 dB`とする。
- その他の標準特徴量: 任意の`0.0...1.0`。
- `features.additional`: 将来の分類値を格納する任意の辞書。値は`0.0...1.0`。標準特徴量と同名のキーは禁止。

## 照合ルール

1. Unicode正規化した`relativePath`が一致する候補を検索する。
2. パス候補を`fileSize`完全一致かつ`duration`差0.5秒以内で検証する。
3. 検証済み候補が1曲なら照合成功、0曲なら未照合、複数なら曖昧とする。
4. `relativePath`候補が1曲もない場合だけフォールバックする。
5. フォールバックは`fileSize`完全一致、`duration`差0.5秒以内、titleとartist一致を必須とし、album指定時はalbum一致も必須とする。
6. フォールバック候補が複数なら曖昧とし、自動保存しない。

metadata比較では前後空白、大小文字、ダイアクリティカルマーク、文字幅の差を正規化する。曲名だけでは照合しない。

## 保存と削除

特徴量はApplication Supportの`MyMusic/track-features.json`へ保存し、Track IDをキーにメモリindex化する。
同一Trackの再Importではレコードを増やさず上書きする。古い`analysisVersion`へのダウングレードは行わない。ただし、既存の新しいSemantic特徴量を保ったまま、古いAnalyzer JSONから音量解析3項目だけを補完できる。以後Semantic JSONを再Importしても保存済み音量項目は保持する。

管理画面の「特徴量データを削除」はこの専用ファイルだけを削除する。Track、Playlist、PlaybackHistory、評価、お気に入り、再生機能には触れない。

## Beta 1の制限

- 音響解析、特徴量表示Badge、特徴量を使った選曲は未実装。
- `contentHash`は将来の完全一致用予約フィールドであり、Beta 1の照合には利用しない。
- 未照合・曖昧項目の個別修正UIは未実装。Mac側JSONを修正して再Importする。
