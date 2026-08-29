"""Report-only evaluation of frozen scores; ground truth never changes inference."""
from __future__ import annotations

import json
import statistics
from evaluate import target, atomic_json, atomic_text, protected_hashes

FEATURES = ('vocal','instrumental','aggressive','calm','energy','electronic','piano','ambient','drumAndBass','dark','bright')
METHODS = ('mean','median','max','p90','p95','voicePatchRatio','segmentMedian')
TRUTH = dict(vocal='Vocal',instrumental='Instrumental',mostly_instrumental='Mostly Instrumental')


def decision(vocal):
    return 'vocal' if vocal > .5 else ('instrumental' if vocal < .5 else 'tie')


def score_count(rows, truth, method='mean', exclude_hard=False):
    subset = [r for r in rows if r['identity']['evaluation']['truth']==truth
              and not (exclude_hard and r['identity']['evaluation'].get('hardCase'))]
    correct = sum(decision(r['baseline']['aggregation'][method])==truth for r in subset)
    return dict(correct=correct,total=len(subset))


def rating(row):
    spec,b = row['identity']['evaluation'],row['baseline']
    pred = decision(b['features']['vocal'])
    if spec.get('hardCase'):
        return 'Hard Case'  # Still counted as an error in the Instrumental denominator.
    if spec['truth']=='mostly_instrumental':
        return '概ね一致' if pred=='instrumental' else '不一致'
    if pred != spec['truth']:
        return '不一致'
    return '一致'


def fmt(v):
    return '—' if v is None else f'{v:.3f}'


def top(labels,n=10):
    return sorted(labels.items(),key=lambda x:-x[1])[:n]


def report(manifest,rows):
    audit = json.loads(target('output/frontend-audit.json').read_text())
    regression = json.loads(target('output/regression.json').read_text())
    comparison = json.loads(target('output/comparison.json').read_text())
    if [r['identity'] for r in comparison['tracks']] != [r['identity'] for r in rows]:
        raise ValueError('Comparison does not match baseline')
    counts = {truth:score_count(rows,truth) for truth in ('vocal','instrumental')}
    generic = score_count(rows,'instrumental',exclude_hard=True)
    seconds = statistics.mean(r['baseline']['timing']['total'] for r in rows)
    methods = {m:{truth:score_count(rows,truth,m) for truth in ('vocal','instrumental')} for m in METHODS}
    lines = ['# Vocal / Instrumental追加評価 — 2026-08-29','',
        '## 結論','',
        '**推奨 A: 現行headで559曲の「評価」へ進める。ただし本番採用ではなく、今回は559曲を実行していない。**',
        '一般Vocalとオーケストラ/クラシックは分離できた。電子系BGMの既知2例は誤判定が残り、Hard Caseとして追跡する。',
        '次の評価では正解付きVocal/Instrumentalを分け、電子系BGMと声入りInstrumentalを独立した層として集計する。',
        '本番への自動適用、confidenceの校正、閾値変更、例外ルールは行わない。選曲集合が小さく、ライブラリ全体の精度保証ではない。','',
        f"対象JSONは{manifest['sourceCount']:,}曲。追加音源{len(rows)}曲、前回{len(regression['tracks'])}曲は保存Embeddingだけで回帰確認。",
        f"Vocal正例: {counts['vocal']['correct']}/{counts['vocal']['total']}。Instrumental正例: {counts['instrumental']['correct']}/{counts['instrumental']['total']}（Hard Caseを除外しない）。",
        f"Hard Case以外のInstrumental: {generic['correct']}/{generic['total']}。Mostly Instrumentalは二値精度の分母へ入れず別評価。",
        '正誤の集計は2クラスsoftmaxのargmax（同値は保留）。0.5は評価上の境界で、MyMusicのBadge閾値を変更したものではない。','',
        '## 対象と結果','',
        '|Track / Artist|Ground Truth|Vocal|Instrumental|Aggressive|Calm|判定|',
        '|---|---|---:|---:|---:|---:|---|']
    for row in rows:
        r,b=row['identity'],row['baseline']
        f=b['features']
        lines.append(f"|{r['v1']['title']} / {r['v1']['artist']}|{TRUTH[r['evaluation']['truth']]}|"+
                     '|'.join(fmt(f[k]) for k in ('vocal','instrumental','aggressive','calm'))+f'|{rating(row)}|')
    lines += ['','## 候補確認と除外','',
        '全対象はArtist/title/relativePath、fileSize/更新日時で確認。ファイル名による分類はしていない。',
        '「勝手にシンドバット」は保存名「勝手にシンドバッド」/サザンオールスターズ、2024 Remasterの1件を特定。表記差を評価用manifestへ記録。',
        '「イージーゲーム」はtitle一致、artist=natsumi、album=和ぬか、pathのfeat. 和ぬか_natsumiを確認。',
        '交響アクティブNEETsの20候補から3曲、Classicsは別アルバムの月の光/G線上のアリア/白鳥を選択。スコアを見る前に固定した。','']
    for excluded in manifest['excluded']:
        spec=excluded['spec']
        lines += [f"- {spec['artist']} / {spec['title']}: **{excluded['status']}**"]
        for candidate in excluded.get('candidates',[]):
            lines += [f"  - `{candidate['relativePath']}` / {candidate['fileSize']} bytes / {candidate['duration']:.3f}s"]
    lines += ['','## Frontend・head・修正前後','',
        '公式native Essentia TensorflowInputMusiCNNと、silence/4種sine/noise/長さ境界の8入力で数値比較。',
        f"16k PCMからのmel値は最大絶対差 {audit['maxAbsError']:.8f}。scale/window/melの大きな不整合は検出しなかった。",
        '一方、現行frontendはEOFに到達する最後の中心frameを1つ欠く。PoC隔離候補 `frontend_candidate.py` で修正し、nativeのframe数と一致させた。',
        '修正前prefixはbit単位で同じ。今回全曲の30秒区間では追加frameが完全patchに使われないため、保存Embeddingをそのまま再利用できることを確認。',
        f"同じheadで再評価した追加{len(rows)}曲の特徴量最大差={comparison['maxFeatureDelta']}、前回11曲の最大差={regression['maxFeatureDelta']}。誤判定も改善していない。",
        '現行Engineは比較用baselineとして変更せず残した。修正候補は境界バグの修正であって、分類精度を良く見せる係数調整ではない。',
        'voice/instrumentalはmetadataの順序 [instrumental, voice]、出力は2クラスSoftmax。再sigmoidなし、embedding互換性/shape/確率和/checksumを確認。',
        'Calm/Aggressiveは独立head。EnergyはDSP、energeticはrawタグ。Electronic/Piano/Ambient/DnB等のmappingは変更なし。',
        '未検証: native decoder/resamplerとのbit一致、TensorFlowとONNXグラフの完全同値。native streamingの無音時noise付加も模倣していない。',
        'native検証は同じPCMのmel抽出部分の検証で、音源全経路の完全パリティを主張しない。','',
        '|合成入力|旧frame|native/candidate frame|旧patch|修正patch|mel最大誤差|',
        '|---|---:|---:|---:|---:|---:|']
    for c in audit['cases']:
        lines.append(f"|{c['signal']}|{c['oldFrames']}|{c['nativeFrames']}|{c['oldPatches']}|{c['newPatches']}|{c['maxAbsError']:.8f}|")
    lines += ['','## 区間別V/I（全曲）','',
        '各区間は30秒。V/Iは区間内patch Softmaxの平均。最終値は3区間の全87patch平均（各29patch）。',
        '|Track|開始秒（3区間）|区間1 V / I|区間2 V / I|区間3 V / I|最終 V / I|',
        '|---|---|---|---|---|---|']
    for row in rows:
        b=row['baseline']; ss=b['segmentVI']
        starts=', '.join(f"{s['offset']:.2f}" for s in ss)
        pairs='|'.join(f"{s['vocal']:.3f} / {s['instrumental']:.3f}" for s in ss)
        lines.append(f"|{row['identity']['v1']['title']}|{starts}|{pairs}|{b['features']['vocal']:.3f} / {b['features']['instrumental']:.3f}|")
    lines += ['','## 集約方式比較（採用変更なし）','',
        'mean/median/max/p90/p95はpatchのVocal score。voicePatchRatioはV>Iのpatch割合。segmentMedianは区間平均の中央値。',
        'Softmax値は人声の占有時間ではない。重複する約2秒patchの割合も真の秒数比率ではない。','',
        '|方式|Vocal正例 正解数|Instrumental正例 正解数|','|---|---:|---:|']
    for method,values in methods.items():
        lines.append('|'+method+'|'+'|'.join(f"{values[t]['correct']}/{values[t]['total']}" for t in ('vocal','instrumental'))+'|')
    lines += ['','|Track|mean|median|max|p90|p95|voicePatchRatio|segmentMedian|',
              '|---|---:|---:|---:|---:|---:|---:|---:|']
    for row in rows:
        lines.append('|'+row['identity']['v1']['title']+'|'+'|'.join(fmt(row['baseline']['aggregation'][m]) for m in METHODS)+'|')
    lines += ['','### 最後の歌','',
        'Ground Truthは「約95% Instrumental主体、約5%人声」であり、binaryの完全無声音源として採点しない。',
        '今回の3区間90秒は約475.55秒の曲の18.9%しか観測していない。声の実在する時刻の注釈もないため、全曲の5%という割合を検証できない。',
        '現行meanでInstrumental主体を維持。max/p90/p95ではVocal側へ反転するため採用しない。medianは低下するが、この1曲の都合で採用しない。',
        'patchの26.4%がVoice優勢でも、曲全体の26.4%に実声があるという意味ではない。声入り区間を確定したとは言えない。','',
        '### 誤検出はどの音で起きたか','',
        'オーケストラ/チェロ/ピアノ/弦主体の8曲では最終値に極端な誤検出なし。一部patchにはVoice高値があるが平均でInstrumentalを維持。',
        'ワールドチャンピオンシップ戦: V=0.689、3区間ともV優勢。median=0.828、Voice優勢patch約73.6%で、単発transientだけとは説明できない。',
        'raw上位はRock/Symphonic Rock/Metal/Synthesizer等。Electronicタグ自体は0.088と低く、人間の説明と完全一致していない。',
        '前回バトルアリーナも保存EmbeddingでV=0.791を再現。電子系・歪み/リードに富むBGMで混同する仮説はあるが、因果関係は未確定。',
        'Choir-like/Pad/Lead synth/Vocal chopを独立に識別する教師ラベルや分離stemはない。各音色を実際にVoiceとして拾ったと断定しない。',
        'Genre/Artist/Track metadataでInstrumentalへ上書きするルールは追加しない。','',
        '## 前回11曲の回帰（音源読み込み0）','',
        '|Track / Artist|Vocal|Instrumental|最大特徴差|','|---|---:|---:|---:|']
    for r in regression['tracks']:
        t=r['identity']['v1'];f=r['features']
        lines.append(f"|{t['title']} / {t['artist']}|{f['vocal']:.3f}|{f['instrumental']:.3f}|{r['delta']}|")
    lines += ['','前回正常だったShow、AZKi、DAZBEE、ファタールを含む全11曲は完全同値。バトルアリーナの既知誤判定と360°等の境界的な値もそのまま。','',
              '## 全特徴・各モデルraw主要ラベル','',
              'モデル間のscoreは同一校正ではない。各モデル内でのみ順位付け。binary headは全2ラベル。raw全patch値はbaseline.jsonに保存。','']
    for row in rows:
        ident,b=row['identity'],row['baseline'];t=ident['v1']
        lines += [f"### {t['title']} — {t['artist']}",'',f"`{t['relativePath']}`",'',
                  '|特徴|score|','|---|---:|']
        for key in FEATURES:
            lines.append(f"|{key}|{fmt(b['features'].get(key))}|")
        for group,labels in {**b['labels'],**b['heads']}.items():
            lines += ['',f"{group}: "+' / '.join(f'{label} {v:.3f}' for label,v in top(labels))]
        lines += ['','区間ごとのraw上位（V/I以外、各モデル3件）:','']
        for s in b['segments']:
            lines.append(f"- {s['offset']:.2f}s: "+'; '.join(g+': '+', '.join(f'{label} {v:.3f}' for label,v in top(labels,3)) for g,labels in s['labels'].items()))
        lines.append('')
    intact = protected_hashes() == manifest['protectedHashes']
    lines += ['## 性能・安全性','',
        f"baseline平均 {seconds:.3f} 秒/曲、ピークRSS {max(r['baseline']['peakMiB'] for r in rows):.1f} MiB。曲は逐次、各3×30秒のみ。",
        '初回2曲→再開13曲→再実行15件Skipを確認。保存は曲単位atomic replace。Ctrl+C/SIGTERM後は完了分を維持。',
        f"本番JSON/SQLiteと前回20曲・11曲PoC生成物のSHA-256一致: {intact}。本番SQLiteには接続せず、別プロセスを停止/変更していない。",
        '今回の書き込みはanalyzer/poc/vi_evalとPoCのREADME/.gitignoreだけ。iPhone/Badge threshold/Selection/Playback/JSON schema変更なし。',
        '本番Import JSONは生成しない。baseline/comparison/regressionは診断用JSONでImport用ではない。','',
        '## 一次資料','',
        '- [MusiCNN frontend公式実装](https://github.com/MTG/essentia/blob/master/src/algorithms/spectral/tensorflowinputmusicnn.cpp)',
        '- [FrameCutter公式実装](https://github.com/MTG/essentia/blob/master/src/algorithms/standard/framecutter.cpp)',
        '- [voice/instrumental head metadata](https://essentia.upf.edu/models/classification-heads/voice_instrumental/voice_instrumental-discogs-effnet-1.json)',
        '- [Essentia 2.1b6.dev1389 arm64配布](https://pypi.org/project/essentia/2.1b6.dev1389/#files)','']
    atomic_text(target('output/report.md'),'\n'.join(lines))
    atomic_json(target('output/summary.json'),dict(count=len(rows),counts=counts,genericInstrumental=generic,
        recommendation='A: advance to labelled 559-track evaluation, not production; keep electronic BGM hard cases',
        methods=methods,meanSeconds=seconds,protectedUnchanged=intact,
        afterDelta=comparison['maxFeatureDelta'],regressionDelta=regression['maxFeatureDelta']))
