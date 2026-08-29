# Analyzer v2 PoC — 最終評価

評価日 2026-08-28、Apple M1 Max / 32 GiB。固定した20曲だけを解析。
ジャンル正解ラベル付きデータではないため「上位ラベルがmetadata上もっともらしいか」と分布を検査した。
全曲・全ラベル・選曲理由は `output/report.md`、機械可読値は `output/summary.json` と `output/comparison.json`。

## 結論: **B — モデル本体は維持し、mapping / headと評価曲を調整して再PoC**

Discogs-EffNetは軽く、Piano/Electronic/Rock等の上位タグには有望な分離が見えたのでC（モデル変更）ではない。
一方、`voice` / `calm` / `dark` のraw scoreは今回の使い方と既存0.68閾値には適合しない。
Ambient/DnBの明確な正例も不足するため、現状を559曲へ拡大するAとは判定しない。
このJSONはImportせず、次のラベル付きPoCまで本番利用しない。

次のPoCでは、同じEffNet embeddingを使う専用 `voice_instrumental` headを比較し、
Jamendo instrument/mood headの出力を小さな正解付き集合で評価する。重いbackboneは増やさない。
確認済みのAmbient、DnB、Calm、Dark、Vocal、Instrumental各2〜3曲を含む10〜30曲を人手で用意する。
Piano/Electronic mappingは維持候補。Dark/Calm/Vocalは検証まで未出力候補。
Bright/Aggressive/Instrumentalを似た別ラベルや反転値から補完しない。

## v1 vs v2分布

同一20曲。stdは母標準偏差、`≥.68` は既存Badge閾値を変更せず観察した件数。
`—` は低スコアではなく、根拠の弱いmappingを避けて未出力にしたもの。

|特徴|版|min|max|mean|median|std|≥.68|
|---|---|---:|---:|---:|---:|---:|---:|
|Piano|v1|.4474|.6289|.5227|.5208|.0574|0|
||v2|.0083|.8367|.2822|.1524|.2680|3|
|Ambient|v1|.2453|.7440|.4415|.3902|.1380|2|
||v2|.0035|.1209|.0379|.0286|.0337|0|
|DnB|v1|.2147|.7396|.4370|.4488|.1221|1|
||v2|.000025|.0653|.0084|.0035|.0153|0|
|Dark|v1|.5429|.9624|.7639|.7671|.1028|16|
||v2|.0044|.0713|.0247|.0180|.0186|0|
|Calm|v1|.3397|.7999|.5038|.4354|.1481|4|
||v2|.0007|.0246|.0085|.0063|.0072|0|
|Electronic|v1|.1802|.6148|.4430|.4828|.1157|0|
||v2|.0072|.6331|.1713|.0881|.1810|0|
|Vocal|v1|.4923|.8923|.6634|.6636|.1376|10|
||v2|.0050|.0888|.0291|.0188|.0239|0|
|Energy (DSP)|v1|.3018|.7458|.5894|.6466|.1394|9|
||v2|.3018|.7458|.5894|.6466|.1394|9|
|Bright|v1|.0522|.5160|.2533|.3010|.1240|0|
||v2|—|—|—|—|—|—|
|Aggressive|v1|.2298|.6408|.4988|.5697|.1324|0|
||v2|—|—|—|—|—|—|
|Instrumental|v1|.1077|.5077|.3366|.3364|.1376|0|
||v2|—|—|—|—|—|—|

Pianoの0.4〜0.6集中とDarkの一律Badge化は解消した。
Piano独奏2曲は0.837/0.788、Cello+Pianoは0.717、Rock曲の一つは0.008だった。
Electronic系metadata候補は0.633/0.470、古典2曲は0.021/0.007だった。
ただしDark/Calm/Vocalは逆方向にほぼゼロへ集中しており、raw sigmoid値をMyMusicの共通強度として使えない。
とくにVocal豊富な集合で最大0.089なので `voice → vocal` の直接mappingは不採用候補。

## 人間が確認できる上位タグ

全20曲の汎用タグ上位5は `output/report.md` に曲名・Artist・relativePathとともに記録済み。
代表例:

|曲|上位5タグ|
|---|---|
|Chopin Nocturne|classical .893 / piano .837 / soundtrack .147 / easylistening .110 / jazz .057|
|Just Be Friends -piano.ver-|piano .589 / pop .502 / classical .215 / soundtrack .157 / happy .103|
|INTERNET YAMERO|electronic .633 / pop .320 / synthesizer .217 / techno .107 / dance .101|
|東京テディベア|rock .556 / metal .311 / drums .296 / alternative .216 / synthesizer .210|
|Hollow|rock .467 / pop .272 / drums .260 / bass .256 / electricguitar .199|
|Andante from second sonata|classical .890 / piano .276 / soundtrack .152 / violin .100 / orchestral .099|

metadataから期待しやすい大分類とは整合する例がある。ただしこれは音を聴いたblind評価でもprecision/recallでもない。
20曲中15曲が48kHz stereo、5曲が44.1kHz stereoだった。

## 新旧の代表比較

|曲|版|Piano|Electronic|DnB|Dark|Calm|Vocal|Energy|
|---|---|---:|---:|---:|---:|---:|---:|---:|
|Chopin Nocturne|v1|.597|.180|.215|.737|.800|.867|.307|
||v2|.837|.021|.0004|.018|.014|.008|.307|
|INTERNET YAMERO|v1|.447|.528|.464|.746|.440|.509|.688|
||v2|.093|.633|.0367|.035|.002|.014|.688|
|東京テディベア|v1|.473|.550|.546|.737|.372|.552|.707|
||v2|.008|.040|.0008|.064|.001|.089|.707|
|lovely|v1|.538|.427|.396|.902|.570|.714|.551|
||v2|.280|.141|.0040|.048|.025|.045|.551|

Energy最大差は0.000394、Tempoは20/20でv1と一致した。
最初の試行でFFmpeg既定stereo→monoがv1の算術平均より約3.0103dB大きいことを合成信号で検出。
native channelをfloat32で取り出して算術平均し、soxr_hqで22,050Hzへ変換するよう修正して同じ20曲を再測定した。
旧試行もPoC領域に保存し、本番データは変更していない。

## Performance / Memory

モデルsetup後、1曲あたり最大3×30秒、逐次処理、thread 2、batch最大8。

|工程|平均 秒/曲|
|---|---:|
|decode/probe/seek/resample|0.301|
|DSP|3.229|
|model frontend|0.024|
|ONNX inference (backbone + 2 heads)|0.407|
|合計|4.052|

20曲実測の線形外挿は559曲 **37.7分**、20,000曲 **22.51時間**。
初回依存/JIT/model warmupは別で最大約29秒を観測。iCloud待ち、再試行、thermal throttlingは含まない。
Python peak RSSは **492.5 MiB**。track後RSSはおよそ480〜492 MiBで単調増加せず、20曲ではリーク兆候なし。
FFmpeg子プロセスのpeakは含まない。全20曲はstereoなので、一時PCMは区間ごとに最大約11.5MB。
曲ごと・区間ごとに波形、mel、embeddingを解放し、全音源をMemoryへ保持しない。

## Safety / Validation

- 本番cache SHA-256: `4d4f0a7a03258247c8dc3bd6f36d51b301b4319aa7bc1bf25d7108daa4d01acb`（前後一致）
- 本番JSON SHA-256: `fd08802d32e34cc7cba473a2e08ce3ef2b2642c752970a6b12a382c2039db5ab`（前後一致）
- PoC SQLite: success 20、`PRAGMA integrity_check = ok`
- 再実行: 20/20 Skip、モデルを作らず音源を読まない
- schemaVersion 1 / analysisVersion 2、exact identity 20/20、既存validator PASS
- Bright/Aggressive/Instrumental/Loudnessはfeaturesに未出力
- v1 tests 6件、PoC tests 9件、計15件PASS
- MyMusic Swift/iPhone、Badge閾値、Selection、Playback、Xcode projectは変更なし
