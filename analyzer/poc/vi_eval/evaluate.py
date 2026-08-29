"""Bounded follow-up evaluation; never opens production SQLite or previous caches for write."""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import signal
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
POC = HERE.parent
sys.path.insert(0, str(POC))
import run as runtime
sys.path.insert(0, str(POC / "human_eval"))
from benchmark import EvaluationEngine
from engine import config_key, model_manifest
from heads import HeadBank, manifest as head_manifest, remap
from prepare_models import sha256
from storage import atomic_json, atomic_text, validate_manifest, verify_audio_identity, PocCache

REPO = POC.parent.parent


def target(relative):
    path = HERE / relative
    resolved = path.resolve()
    if not resolved.is_relative_to(HERE) or path.is_symlink():
        raise ValueError("Output must remain in vi_eval")
    if path.exists() and path.is_file() and path.stat().st_nlink != 1:
        raise ValueError("Hard-linked output forbidden")
    return resolved


def protected_hashes():
    paths = [REPO / "music_features.json", REPO / "analyzer/cache/analysis.sqlite3"]
    for directory in (POC / "data", POC / "output", POC / "human_eval/data", POC / "human_eval/output"):
        paths.extend(p for p in directory.iterdir() if p.is_file())
    return {str(p.relative_to(REPO)): sha256(p) for p in sorted(paths)}


def resolve_candidates(rows, spec):
    # Deliberately no fuzzy/first-result match. Metadata is used only here.
    candidates = [r for r in rows if r.get("artist") == spec["artist"] and r.get("title") == spec["title"]]
    if "requiredAlbum" in spec:
        candidates = [r for r in candidates if r.get("album") == spec["requiredAlbum"]]
    if "requiredPathText" in spec:
        candidates = [r for r in candidates if spec["requiredPathText"] in r["relativePath"]]
    return candidates


def selection():
    path = target("data/selection.json")
    if path.exists():
        result = json.loads(path.read_text())
        validate_manifest(result)
        if len(result["tracks"]) > 16:
            raise ValueError("This evaluation is capped at 16 new tracks")
        return result
    before = protected_hashes()
    document = json.loads((REPO / "music_features.json").read_text())
    roots = {r["root"] for r in json.loads((POC / "human_eval/data/selection.json").read_text())["tracks"]}
    if len(roots) != 1:
        raise ValueError("Ambiguous library root")
    root = Path(roots.pop()).resolve()
    rows, excluded = [], []
    specs = json.loads((HERE / "samples.json").read_text())["tracks"]
    if len(specs) > 16:
        raise ValueError("Do not expand this fixed follow-up set")
    for spec in specs:
        candidates = resolve_candidates(document["tracks"], spec)
        if len(candidates) != 1:
            excluded.append(dict(spec=spec, status="ambiguous" if candidates else "unmatched",
                                 candidates=[{k:v for k,v in r.items() if k != "features"} for r in candidates]))
            continue
        entry = candidates[0]
        path = (root / entry["relativePath"]).resolve()
        if not path.is_relative_to(root):
            raise ValueError("Source escapes root")
        try:
            stat = path.stat()
            saved_time = datetime.fromisoformat(entry["modificationDate"].replace("Z", "+00:00")).timestamp()
            if stat.st_size != entry["fileSize"] or int(stat.st_mtime) != int(saved_time):
                raise ValueError("Source identity changed since saved export")
            row = dict(root=str(root), relativePath=entry["relativePath"], fileSize=entry["fileSize"],
                       mtimeNS=stat.st_mtime_ns, v1=entry, evaluation=spec)
            verify_audio_identity(row)
        except (OSError, ValueError) as error:
            excluded.append(dict(spec=spec, status="unavailable", error=str(error)))
            continue
        rows.append(row)
    result = dict(tracks=rows, excluded=excluded, sourceCount=len(document["tracks"]),
                  protectedHashes=before, createdAt=datetime.now().astimezone().isoformat())
    validate_manifest(result)
    if protected_hashes() != before:
        raise ValueError("Source changed during selection; no snapshot written")
    atomic_json(target("data/selection.json"), result)
    return result


class TraceEngine(EvaluationEngine):
    """Keep patch/segment boundaries without changing the existing classifier."""
    def predict(self, samples):
        result = super().predict(samples)
        if self.collecting:
            sums, count, _, _ = result
            self.segments.append(dict(samples16k=len(samples), patches=count,
                                      labels={g:dict(zip(self.labels[g], (s / count).tolist())) for g,s in sums.items()}))
        return result

    def analyze(self, path, duration):
        self.segments = []
        result = super().analyze(path, duration)
        if len(self.segments) != len(result["offsets"]):
            raise ValueError("Segment boundary mismatch")
        start = 0
        for segment, offset in zip(self.segments, result["offsets"]):
            segment.update(offset=offset, patchStart=start, patchEnd=start + segment["patches"])
            start += segment["patches"]
        result["segments"] = self.segments
        return result


class PatchHeads(HeadBank):
    """Read all softmax outputs before any aggregation. No metadata accepted."""
    def predict_patches(self, embeddings):
        import numpy as np
        if (embeddings.ndim != 2 or embeddings.shape[1] != 1280 or not 1 <= len(embeddings) <= 256
                or not np.isfinite(embeddings).all()):
            raise ValueError("Invalid bounded embeddings")
        result = {}
        for name, session in self.sessions.items():
            predictions = np.concatenate([session.run(None, {session.get_inputs()[0].name:
                np.asarray(embeddings[i:i+8], dtype=np.float32)})[0] for i in range(0, len(embeddings), 8)])
            if (not np.isfinite(predictions).all() or np.any(predictions < 0) or np.any(predictions > 1)
                    or not np.allclose(predictions.sum(axis=1), 1, atol=1e-5)):
                raise ValueError("Expected learned binary softmax")
            result[name] = {label: predictions[:, i].astype(float).tolist() for i,label in enumerate(self.labels[name])}
        return result


def summarize(raw, segments):
    import numpy as np
    means = {g:{label:float(np.mean(values)) for label,values in labels.items()} for g,labels in raw.items()}
    v = np.asarray(raw["voice_instrumental"]["voice"])
    segment_scores = []
    for s in segments:
        start, end = s["patchStart"], s["patchEnd"]
        if not 0 <= start < end <= len(v):
            raise ValueError("Invalid segment boundaries")
        segment_scores.append(dict(offset=s["offset"], patches=end-start,
            vocal=float(v[start:end].mean()), instrumental=float(np.mean(raw["voice_instrumental"]["instrumental"][start:end]))))
    aggregation = dict(mean=float(v.mean()), median=float(np.median(v)), max=float(v.max()),
        p90=float(np.percentile(v,90)), p95=float(np.percentile(v,95)),
        voicePatchRatio=float(np.mean(v > .5)), tiePatchRatio=float(np.mean(v == .5)),
        segmentMedian=float(np.median([r["vocal"] for r in segment_scores])))
    # .5 is binary argmax for evaluation, NOT a changed MyMusic Badge threshold.
    return dict(heads=means, rawHeads=raw, segmentVI=segment_scores, aggregation=aggregation)


def save_embeddings(path, array):
    import numpy as np
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, suffix=".npz", delete=False) as handle:
        np.savez_compressed(handle, embeddings=array)
        handle.flush()
        os.fsync(handle.fileno())
        temporary = handle.name
    os.replace(temporary, path)


def baseline(manifest, limit):
    from threadpoolctl import threadpool_limits
    config = config_key(model_manifest()) + json.dumps(head_manifest(),sort_keys=True) + ";vi-trace-v1"
    counts = dict(success=0, skipped=0, failed=0, audioTracks=0, interrupted=False)
    model, heads = None, None
    started = time.perf_counter()
    try:
        with threadpool_limits(limits=2):
            for index,row in enumerate(manifest["tracks"],1):
                key = hashlib.sha256(PocCache.key(row).encode()).hexdigest()
                path, embedding_path = target(f"data/{key}.json"), target(f"data/{key}.npz")
                if path.exists():
                    saved = json.loads(path.read_text())
                    if saved["config"] != config or sha256(embedding_path) != saved["embeddingSHA256"]:
                        raise ValueError("Frozen result/config changed; never silently overwrite baseline")
                    counts["skipped"] += 1
                    continue
                if counts["audioTracks"] >= limit:
                    continue
                counts["audioTracks"] += 1
                print(f"[{index}/{len(manifest['tracks'])}] {row['v1']['artist']} / {row['v1']['title']}",flush=True)
                try:
                    source = verify_audio_identity(row)
                    model = model or TraceEngine()
                    heads = heads or PatchHeads()
                    result = model.analyze(source, row["v1"]["duration"])
                    verify_audio_identity(row)
                    head_start = time.perf_counter()
                    detail = summarize(heads.predict_patches(model.last_embeddings),result["segments"])
                    result["headSeconds"] = time.perf_counter()-head_start
                    result.update(detail)
                    result["features"] = remap(result["features"],detail["heads"])
                    save_embeddings(embedding_path,model.last_embeddings)
                    del model.last_embeddings
                    saved = dict(identity=row, baseline=result,config=config,embeddingFile=embedding_path.name,
                                 embeddingSHA256=sha256(embedding_path))
                    atomic_json(path,saved)
                    counts["success"] += 1
                    print('V/I', result['heads']['voice_instrumental'], 'segments',
                          [round(s['vocal'],3) for s in result['segmentVI']],flush=True)
                except Exception as error:
                    counts["failed"] += 1
                    print(f"FAILED {type(error).__name__}: {error}",flush=True)
                    atomic_json(target(f"data/{key}.error.json"),dict(error=str(error)))
    except KeyboardInterrupt:
        counts["interrupted"] = True
    counts.update(wallSeconds=time.perf_counter()-started)
    history_path = target("data/runs.json")
    history = json.loads(history_path.read_text()) if history_path.exists() else []
    atomic_json(history_path,[*history,counts])
    print(json.dumps(counts,indent=2))
    return 130 if counts["interrupted"] else (1 if counts["failed"] else 0)


def records(manifest):
    result = []
    for row in manifest["tracks"]:
        key = hashlib.sha256(PocCache.key(row).encode()).hexdigest()
        path = target(f"data/{key}.json")
        if not path.exists():
            raise ValueError("Complete the fixed baseline first")
        record = json.loads(path.read_text())
        if record["identity"] != row:
            raise ValueError("Frozen identity differs")
        result.append(record)
    return result


def regression():
    """Re-run only the heads on all 11 saved embeddings; no audio/backbone."""
    import numpy as np
    head_manifest()
    old = json.loads((POC / "human_eval/output/after.json").read_text())["tracks"]
    bank = PatchHeads()
    results = []
    for row in old:
        before = row["before"]
        path = (POC / "human_eval" / before["embeddingFile"]).resolve()
        if not path.is_relative_to(POC / "human_eval/data") or sha256(path) != before["embeddingSHA256"]:
            raise ValueError("Previous embedding changed")
        with np.load(path,allow_pickle=False) as data:
            raw = bank.predict_patches(data["embeddings"])
        # Prior experiment: each saved 30s window had exactly 29 patches.
        if before["patches"] != 29 * len(before["offsets"]):
            raise ValueError("Old segment boundaries cannot be safely inferred")
        segments = [dict(offset=o,patchStart=i*29,patchEnd=(i+1)*29) for i,o in enumerate(before["offsets"])]
        detail = summarize(raw,segments)
        features = remap(before["features"], detail["heads"])
        delta = max(abs(features[k]-row["after"]["features"][k]) for k in features)
        results.append(dict(identity=row["identity"],features=features,delta=delta,**detail))
    atomic_json(target("output/regression.json"),dict(tracks=results,audioReads=0,backboneRuns=0,
        maxFeatureDelta=max(r["delta"] for r in results)))
    print('Regression:',len(results),'tracks, max delta',max(r["delta"] for r in results))


def comparison(manifest):
    """After-candidate check from the same certified patch embeddings, no audio."""
    import numpy as np
    from frontend_candidate import unchanged_patch_layout
    head_manifest()
    audit = json.loads(target("output/frontend-audit.json").read_text())
    if not all(r["cachedEmbeddingsReusable"] for r in audit["layouts"]):
        raise ValueError("Candidate changes used patches; cached comparison is not valid")
    bank = PatchHeads()
    output = []
    for row in records(manifest):
        if not all(unchanged_patch_layout(s["samples16k"]) for s in row["baseline"]["segments"]):
            raise ValueError("Cannot reuse a changed patch layout")
        path = target("data/" + row["embeddingFile"])
        if sha256(path) != row["embeddingSHA256"]:
            raise ValueError("Frozen embedding modified")
        with np.load(path,allow_pickle=False) as data:
            detail = summarize(bank.predict_patches(data["embeddings"]),row["baseline"]["segments"])
        features = remap(row["baseline"]["features"],detail["heads"])
        delta = max(abs(features[k]-row["baseline"]["features"][k]) for k in features)
        output.append(dict(identity=row["identity"],features=features,delta=delta,**detail))
    atomic_json(target("output/comparison.json"),dict(tracks=output,audioReads=0,
        note="Terminal-frame candidate adds no consumed patches for these 30s windows. Mean/mapping unchanged.",
        maxFeatureDelta=max(r["delta"] for r in output)))
    print('Candidate comparison:',len(output),'tracks, max delta',max(r['delta'] for r in output))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", choices=("select","baseline","regression","compare","report"),required=True)
    parser.add_argument("--limit",type=int,default=16)
    args = parser.parse_args()
    if not 1 <= args.limit <= 16:
        parser.error("limit must be 1–16; no whole-library option")
    signal.signal(signal.SIGTERM,runtime.handle_termination)
    manifest = selection()
    before = protected_hashes()
    code = 0
    try:
        if args.stage == "select":
            print(json.dumps(dict(count=len(manifest['tracks']),excluded=manifest['excluded']),ensure_ascii=False,indent=2))
        elif args.stage == "baseline":
            code = baseline(manifest,args.limit)
            if code == 0:
                # A partial run need not have every result, but identity/config
                # errors in a complete run must not be silently suppressed.
                complete = all(target('data/' + hashlib.sha256(PocCache.key(row).encode()).hexdigest()
                                      + '.json').exists() for row in manifest['tracks'])
                if complete:
                    atomic_json(target("output/baseline.json"),records(manifest))
        elif args.stage == "regression":
            regression()
        elif args.stage == "compare":
            comparison(manifest)
        else:
            from report_vi import report
            report(manifest,records(manifest))
    finally:
        after = protected_hashes()
        atomic_json(target("output/protection.json"),dict(before=before,after=after,
                    unchanged=before == after,unchangedSinceSelection=after == manifest["protectedHashes"]))
        if after != before:
            raise ValueError("Protected file changed externally; no overwrite/revert attempted")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
