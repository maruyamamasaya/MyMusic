"""Reports use saved PoC results only, and never open audio files."""
from __future__ import annotations

import json
import statistics
import sys

from prepare_models import HERE
from storage import atomic_json, atomic_text
from engine import MAPPING, OMITTED

sys.path.insert(0, str(HERE.parent))
from mymusic_analyzer.schema import make_document

FEATURES = ("piano", "ambient", "drumAndBass", "dark", "bright", "calm",
            "aggressive", "electronic", "vocal", "instrumental", "energy")
# Observation only: unchanged iPhone threshold. Not a v2 calibration parameter.
BADGE_THRESHOLD = 0.68


def distribution(values: list[float]) -> dict:
    if not values:
        return {"count": 0}
    bins = [0] * 10
    for value in values:
        bins[min(9, int(value * 10))] += 1
    return dict(count=len(values), min=min(values), max=max(values), mean=statistics.mean(values),
                median=statistics.median(values), std=statistics.pstdev(values), histogram=bins,
                aboveThreshold=sum(value >= BADGE_THRESHOLD for value in values))


def text_cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def write_reports(manifest: dict, cache, config: str, run: dict) -> dict:
    records = []
    for row in manifest["tracks"]:
        result = cache.success(row, config)
        if result:
            records.append((row, result))
    tracks = []
    for row, result in records:
        identity = {key: value for key, value in row["v1"].items() if key != "features"}
        tracks.append({**identity, "features": result["features"]})
    # Existing schema, a different analysis version; never use the production output path.
    atomic_json(HERE / "output/music_features_v2_poc.json", make_document(2, tracks))
    stats = {}
    for feature in FEATURES:
        stats[feature] = {
            "v1": distribution([row["v1"]["features"][feature] for row, _ in records
                                if feature in row["v1"]["features"]]),
            "v2": distribution([result["features"][feature] for _, result in records
                                if feature in result["features"]]),
        }
    means = {key: statistics.mean([result["timing"][key] for _, result in records])
             for key in ("decode", "dsp", "preprocessing", "inference", "total")} if records else {}
    summary = dict(tracks=len(records), selected=len(manifest["tracks"]), run=run,
                   distribution=stats, meanSeconds=means,
                   estimatesSeconds={str(n): means.get("total", 0) * n for n in (559, 20000)},
                   peakMiB=max((result["peakMiB"] for _, result in records), default=0),
                   productionHashes=manifest["productionHashes"],
                   mapping=MAPPING, omitted=OMITTED)
    history_path = HERE / "data/runs.json"
    summary["runHistory"] = json.loads(history_path.read_text()) if history_path.exists() else []
    atomic_json(HERE / "output/summary.json", summary)
    atomic_json(HERE / "output/comparison.json", [dict(identity=row, v2=result) for row, result in records])
    lines = ["# MyMusic Analyzer v2 PoC — 実測レポート", "",
             f"完了 {len(records)} / 選択 {len(manifest['tracks'])} 曲。分析対象は固定manifestのみ。",
             "v1は保存済み値、v2は実音源の最大3×30秒。ジャンルの正解アノテーションはありません。",
             "分布改善は分類正解率の証明ではありません。曲名による選曲理由も正解ラベルではありません。", "",
             "## 実行・性能", "", "```json", json.dumps(run, ensure_ascii=False, indent=2), "```", "",
             "|工程|平均 秒/曲|", "|---|---:|"]
    lines += [f"|{key}|{value:.4f}|" for key, value in means.items()]
    if records:
        total = means["total"]
        lines += ["", f"559曲: {total * 559 / 60:.1f}分。20,000曲: {total * 20000 / 3600:.2f}時間。",
                  "いずれも90秒上限・逐次・ローカルファイル・同一Macの線形推定。全曲解析は実行していません。",
                  "初回モデルロード/合成信号warmupはrunのsetupSeconds。DL、iCloud待ち、熱による低速化、障害再試行は推定外。",
                  f"Pythonプロセスの実測peak RSS: {summary['peakMiB']:.1f} MiB（OS high-water mark）。",
                  "FFmpeg子プロセスは含まない。after-track RSSを各曲に記録。波形・embeddingは永続化しない。"]
        completed_runs = [item for item in summary["runHistory"] if item.get("attempted")]
        lines += ["", "実解析の実行履歴（最新runが全Skipでも計測履歴を維持）:", "", "```json",
                  json.dumps(completed_runs, ensure_ascii=False, indent=2), "```"]
    lines += ["", "## 同じ曲集合の分布", "", "stdは母標準偏差。閾値は既存UIの0.68を観察するだけで変更なし。", "",
              "|特徴|版|n|min|max|mean|median|std|≥0.68|", "|---|---|---:|---:|---:|---:|---:|---:|---:|"]
    for feature, versions in stats.items():
        for version, values in versions.items():
            if values["count"]:
                numbers = "|".join(f"{values[key]:.4f}" for key in ("min", "max", "mean", "median", "std"))
                lines.append(f"|{feature}|{version}|{values['count']}|{numbers}|{values['aboveThreshold']}|")
            else:
                lines.append(f"|{feature}|{version}|0|—|—|—|—|—|未出力|")
    lines += ["", "### v2ヒストグラム（0.1刻み）", "", "[0,.1), [.1,.2), …, [.9,1] の件数。", "",
              "|特徴|件数ベクトル|", "|---|---|"]
    lines += [f"|{feature}|{versions['v2'].get('histogram', '未出力')}|" for feature, versions in stats.items()]
    lines += ["", "## 曲別の新旧比較と上位ラベル", "",
              "上位5は汎用50タグ分類の中での順位。Mood、Discogsは別表示（異なる分類器の確率を混ぜて順位付けしない）。",
              "0〜1は未校正のモデル出力であり、人間の確信度ではありません。", ""]
    for index, (row, result) in enumerate(records, 1):
        title = text_cell(row["v1"].get("title", row["relativePath"]))
        artist = text_cell(row["v1"].get("artist", ""))
        lines += [f"### {index:02}. {title} — {artist}", "", f"選曲: {row['selectionReason']}", "",
                  f"relativePath: `{row['relativePath']}`", "", "|特徴|v1|v2|", "|---|---:|---:|"]
        for feature in FEATURES:
            old = row["v1"]["features"].get(feature)
            new = result["features"].get(feature)
            lines.append(f"|{feature}|{old:.4f}|{f'{new:.4f}' if new is not None else '—'}|" if old is not None
                         else f"|{feature}|—|{new}|")
        lines += ["", "汎用タグ上位5:", ""]
        for rank, (label, score) in enumerate(sorted(result["labels"]["tags"].items(), key=lambda item: -item[1])[:5], 1):
            lines.append(f"{rank}. {label}: {score:.4f}")
        for group in ("mood", "discogs"):
            top = sorted(result["labels"][group].items(), key=lambda item: -item[1])[:5]
            lines += ["", group + ": " + "; ".join(f"{label} {score:.4f}" for label, score in top)]
        badges = sorted(((key, value) for key, value in result["features"].items()
                         if key in MAPPING and value >= BADGE_THRESHOLD), key=lambda item: -item[1])[:3]
        lines += ["", "既存閾値でのBadge候補: " + (", ".join(key for key, _ in badges) or "なし"),
                  f"decode {result['timing']['decode']:.2f}s / DSP {result['timing']['dsp']:.2f}s / "
                  f"preprocess {result['timing']['preprocessing']:.2f}s / inference {result['timing']['inference']:.2f}s / "
                  f"total {result['timing']['total']:.2f}s / RSS {result['rssMiB']:.1f} MiB", ""]
    lines += ["## 保護対象SHA-256", "", "```json", json.dumps(manifest["productionHashes"], indent=2), "```", ""]
    atomic_text(HERE / "output/report.md", "\n".join(lines))
    return summary
