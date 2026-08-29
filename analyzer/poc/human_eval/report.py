"""Human-readable before/after evidence. No audio processing or score tuning."""
from __future__ import annotations

import json
import statistics

from benchmark import HERE, hashes
from heads import MAPPING, REVISION
from storage import atomic_json, atomic_text

FEATURES = ("vocal", "instrumental", "aggressive", "calm", "energy", "piano", "ambient",
            "electronic", "drumAndBass", "dark", "bright")


def fmt(value):
    return "—" if value is None else f"{value:.3f}"


def make_report(selection, before_records):
    result = json.loads((HERE / "output/after.json").read_text())
    tracks = result["tracks"]
    if len(tracks) != len(selection["tracks"]):
        raise ValueError("Incomplete head evaluation")
    reviews = json.loads((HERE / "review.json").read_text())["tracks"]
    if [r["title"] for r in reviews] != [r["identity"]["v1"]["title"] for r in tracks]:
        raise ValueError("Review annotations do not match the frozen sample set")
    diagnostic = json.loads((HERE / "output/mtt-diagnostic.json").read_text())
    mtt = {r["relativePath"]: r["labels"] for r in diagnostic}
    mean_seconds = statistics.mean(r["before"]["timing"]["total"] for r in tracks)
    head_seconds = statistics.mean(r["after"]["headSeconds"] for r in tracks)
    lines = ["# 人間が傾向を把握した11曲 — Analyzer v2微修正", "",
             "## 結論", "",
             "推奨: **モデル/head自体を再検討する（Vocal/Instrumental headを優先、backboneは維持）**。",
             "Vocal検出と激しい/穏やかな曲の相対差は改善したが、バトルアリーナをVocalと誤判定する。",
             "最低限のV/I分離を全評価曲で達成したとは言えないため、559曲への展開・本番Importは行わない。",
             "この11曲は調整判断に使った開発集合で、独立した精度評価ではない。係数学習や曲別の補正はしていない。", "",
             "## 最小変更", "",
             "共有Discogs-EffNetは維持。3つの軽量head（合計約1.54MB）を使用。", "",
             "|MyMusic|変更前|変更後|", "|---|---|---|",
             "|vocal|Jamendo top50 voice|voice_instrumental / voice|",
             "|instrumental|未出力|voice_instrumental / instrumental|",
             "|aggressive|未出力|mood_aggressive / aggressive|",
             "|calm|Jamendo Mood calm|mood_relaxed / relaxed|", "",
             "全patchの学習済みsoftmax出力を平均。再sigmoid、clamp、min-max調整、Artist依存ルールなし。",
             "Calmは『リラックスした曲全体』の近似であり、声質の柔らかさだけを測るものではない。",
             "Electronic/Piano/Ambient/DnB/Dark/Energy/Tempoは変更前と同値。Brightは未出力。",
             "energeticとsoftはJamendoのraw labelとして別記し、Energyへ混ぜない。", "",
             "## 曲別比較（変更後）", "",
             "|Track / Artist|Vocal|Instrumental|Aggressive|Calm|Electronic|Piano|評価|",
             "|---|---:|---:|---:|---:|---:|---:|---|"]
    for record, review in zip(tracks, reviews):
        identity = record["identity"]["v1"]
        f = record["after"]["features"]
        values = "|".join(fmt(f.get(k)) for k in ("vocal", "instrumental", "aggressive", "calm", "electronic", "piano"))
        lines.append(f"|{identity['title']} / {identity['artist']}|{values}|{review['rating']}|")
    lines += ["", "## 変更前→変更後", "", "|Track|Vocal|Instrumental|Aggressive|Calm|", "|---|---|---|---|---|"]
    for record in tracks:
        b, a = record["before"]["features"], record["after"]["features"]
        values = "|".join(f"{fmt(b.get(key))} → {fmt(a.get(key))}" for key in MAPPING)
        lines.append(f"|{record['identity']['v1']['title']}|{values}|")
    lines += ["", "## 全特徴量・raw labels（各モデル内上位10）", "",
             "異なる分類器のscoreは校正されていないため、分類器を跨いで上位順位を作らない。性別やライブ検出器は追加していない。", ""]
    for index, (record, review) in enumerate(zip(tracks, reviews), 1):
        identity = record["identity"]
        b, a = record["before"], record["after"]
        lines += [f"### {index}. {identity['v1']['title']} — {identity['v1']['artist']}", "",
                  f"**{review['rating']}** — {review['note']}", "",
                  f"relativePath: `{identity['relativePath']}`", "",
                  f"fileSize: {identity['fileSize']} / duration: {identity['v1']['duration']}s", "",
                  "|特徴|変更前|変更後|", "|---|---:|---:|"]
        for feature in FEATURES:
            lines.append(f"|{feature}|{fmt(b['features'].get(feature))}|{fmt(a['features'].get(feature))}|")
        lines += ["", f"raw energetic: {b['labels']['mood']['energetic']:.4f}; raw soft: {b['labels']['mood']['soft']:.4f}",
                  f"20–250Hz power比率: {b['diagnostics']['bass20to250PowerRatio']:.4f}; "
                  f"20–120Hz: {b['diagnostics']['sub20to120PowerRatio']:.4f}",
                  "低域比率は曲全体のFFT powerで、声の基本周波数・男性判定・ボーカル分離ではない。", ""]
        for group, values in {**b["labels"], **a["heads"], "mtt-diagnostic-only": mtt[identity["relativePath"]]}.items():
            lines += [f"{group}:", ""]
            for rank, (label, score) in enumerate(sorted(values.items(), key=lambda item: -item[1])[:10], 1):
                lines.append(f"{rank}. {label}: {score:.4f}")
            lines.append("")
    lines += ["## 誤判定の追加検査", "",
              "バトルアリーナのVocalは区間平均0.697 / 0.864 / 0.812。曲平均0.791、patch中央値0.852なので、",
              "一部区間だけの外れ値ではない。中央値化で解決するものではなく、平均方法や閾値を調整しなかった。",
              "追加のMTT headも同じEmbeddingで検査。バトルアリーナはvocal 0.042 / no vocals 0.044と双方低く、",
              "Instrumentalを明確に示せない。これらを比率で強制正規化することはせず、mappingには不採用。",
              "声に似たシンセ/ギター等の音色、モデル学習集合との違いが候補だが原因はこの検査だけでは確定しない。", "",
              "## 再開・性能・保護", "",
              f"実音源は11曲だけ、平均 {mean_seconds:.3f} 秒/曲（最大3×30秒）。修正headは保存済みEmbeddingのみで平均 {head_seconds:.4f} 秒/曲。",
              "再解析なしで同じ入力のbefore/afterを比較。中間Embeddingはこの評価領域内だけで、Import JSONへは含めない。",
              "本番SQLiteにはWALがあったため接続せず、559曲の既存JSONから対象metadataを照合した。",
              "本番SQLite本体・本番JSON・前回20曲のPoC SQLite/JSONについて実行前後のSHA-256一致を確認。",
              "既存WALは別プロセスの管理対象で、削除・checkpoint・書き込みをしていない。", "",
              "```json", json.dumps(selection["sourceHashes"], indent=2), "```", ""]
    atomic_text(HERE / "output/report.md", "\n".join(lines))
    summary = dict(revision=REVISION, count=len(tracks), meanBaselineSeconds=mean_seconds,
                   meanHeadSeconds=head_seconds, protectedUnchanged=hashes() == selection["sourceHashes"],
                   recommendation="Reconsider Vocal/Instrumental head; retain backbone; do not expand to 559",
                   ratings=reviews)
    atomic_json(HERE / "output/summary.json", summary)


if __name__ == "__main__":
    raise SystemExit("Use benchmark.py --stage report")
