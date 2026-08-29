"""Explicit human evaluation set. Metadata selects tracks; it never enters a model."""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import signal
import sys
import time

HERE = Path(__file__).resolve().parent
POC = HERE.parent
sys.path.insert(0, str(POC))
import run as poc_runtime  # Reuse the isolated runtime environment / cache settings.
from engine import Engine, config_key, model_manifest
from prepare_models import sha256
from storage import (PocCache, atomic_json, atomic_text, safe_target,
                     validate_manifest, verify_audio_identity)

SOURCE_JSON = POC.parent.parent / "music_features.json"
PROTECTED = [SOURCE_JSON, POC.parent / "cache/analysis.sqlite3",
             POC / "data/poc.sqlite3", POC / "output/music_features_v2_poc.json"]


def hashes():
    # No SQLite connection to production: its active WAL is intentionally untouched.
    return {str(path): sha256(path) for path in PROTECTED}


def resolve_unique(tracks, artist, title):
    candidates = [track for track in tracks if track.get("artist") == artist and track.get("title") == title]
    if len(candidates) != 1:
        raise ValueError(f"Expected ONE exact artist/title match: {artist} / {title}; "
                         f"candidates={[t['relativePath'] for t in candidates]}")
    return candidates[0]


def selection():
    target = HERE / "data/selection.json"
    if target.exists():
        manifest = json.loads(target.read_text())
        validate_manifest(manifest)
        return manifest
    before = hashes()
    document = json.loads(SOURCE_JSON.read_text())
    specs = json.loads((HERE / "samples.json").read_text())["tracks"]
    roots = {row["root"] for row in json.loads((POC / "data/selection.json").read_text())["tracks"]}
    if len(roots) != 1 or len(specs) > 30:
        raise ValueError("Ambiguous root or too many evaluation samples")
    root = Path(roots.pop()).resolve()
    rows = []
    for spec in specs:
        entry = resolve_unique(document["tracks"], spec["artist"], spec["title"])
        relative = entry["relativePath"]
        path = (root / relative).resolve()
        if not path.is_relative_to(root):
            raise ValueError("Path escapes library root")
        stat = path.stat()
        saved_time = datetime.fromisoformat(entry["modificationDate"].replace("Z", "+00:00")).timestamp()
        if stat.st_size != entry["fileSize"] or int(stat.st_mtime) != int(saved_time):
            raise ValueError(f"Saved JSON identity no longer matches: {relative}")
        row = dict(root=str(root), relativePath=relative, fileSize=entry["fileSize"],
                   mtimeNS=stat.st_mtime_ns, v1=entry, v1Config="saved JSON snapshot",
                   expectation=spec["expectation"], selectionReason="exact artist/title from human evaluation list")
        verify_audio_identity(row)
        rows.append(row)
    manifest = dict(tracks=rows, sourceHashes=before,
                    note="Production SQLite has WAL; only frozen export JSON used for selection")
    validate_manifest(manifest)
    if before != hashes():
        raise ValueError("Protected files changed during metadata selection")
    atomic_json(target, manifest)
    return manifest


class EvaluationEngine(Engine):
    """Capture only this small set's patch embeddings and unscaled bass diagnostics."""
    collecting = False

    def observe_embedding(self, embedding):
        if self.collecting:
            self.embedding_batches.append(embedding.copy())

    def observe_segment(self, samples, sample_rate):
        if not self.collecting:
            return
        import librosa
        import numpy as np
        power = np.abs(librosa.stft(samples, n_fft=2048, hop_length=512)) ** 2
        frequencies = librosa.fft_frequencies(sr=sample_rate, n_fft=2048)
        total = float(power.sum()) + 1e-12
        self.diagnostics.append({
            "bass20to250PowerRatio": float(power[(frequencies >= 20) & (frequencies < 250)].sum() / total),
            "sub20to120PowerRatio": float(power[(frequencies >= 20) & (frequencies < 120)].sum() / total),
        })

    def analyze(self, path, duration):
        import numpy as np
        self.embedding_batches, self.diagnostics = [], []
        self.collecting = True
        try:
            result = super().analyze(path, duration)
        finally:
            self.collecting = False
        self.last_embeddings = np.concatenate(self.embedding_batches)
        self.embedding_batches.clear()
        if self.last_embeddings.shape != (result["patches"], 1280):
            raise ValueError("Embedding patch alignment mismatch")
        result["diagnostics"] = {key: float(np.median([item[key] for item in self.diagnostics]))
                                 for key in self.diagnostics[0]}
        return result


def baseline_config():
    return config_key(model_manifest()) + ";human-eval-embedding-capture-v1"


def load_records(manifest):
    cache = PocCache(HERE / "data/baseline.sqlite3")
    try:
        records = []
        for row in manifest["tracks"]:
            result = cache.success(row, baseline_config())
            if result:
                records.append(dict(identity=row, before=result))
        return records
    finally:
        cache.close()


def baseline(manifest, limit):
    import numpy as np
    from threadpoolctl import threadpool_limits
    before = hashes()
    started = time.perf_counter()
    config = baseline_config()
    cache = PocCache(HERE / "data/baseline.sqlite3")
    counts = dict(attempted=0, success=0, failed=0, skipped=0, interrupted=False)
    engine = None
    try:
        with threadpool_limits(limits=2):
            for index, row in enumerate(manifest["tracks"], 1):
                saved = cache.success(row, config)
                if saved:
                    if sha256(HERE / saved["embeddingFile"]) != saved["embeddingSHA256"]:
                        raise ValueError("Saved embedding corrupted; do not silently reanalyze")
                    counts["skipped"] += 1
                    continue
                if counts["attempted"] >= limit:
                    break
                counts["attempted"] += 1
                engine = engine or EvaluationEngine()
                print(f"[{index}/{len(manifest['tracks'])}] {row['v1']['artist']} / {row['v1']['title']}", flush=True)
                try:
                    path = verify_audio_identity(row)
                    result = engine.analyze(path, row["v1"]["duration"])
                    verify_audio_identity(row)
                    identifier = hashlib.sha256(PocCache.key(row).encode()).hexdigest()
                    embedding_path = safe_target(HERE / "data" / f"{identifier}.npz")
                    np.savez_compressed(embedding_path, embeddings=engine.last_embeddings)
                    del engine.last_embeddings
                    result["embeddingFile"] = str(embedding_path.relative_to(HERE))
                    result["embeddingSHA256"] = sha256(embedding_path)
                    cache.save(row, config, "success", result)
                    counts["success"] += 1
                    print(json.dumps(result["features"]), flush=True)
                except Exception as error:
                    counts["failed"] += 1
                    cache.save(row, config, "failed", {"error": str(error)})
                    print(f"Failed: {error}", flush=True)
    except KeyboardInterrupt:
        counts["interrupted"] = True
    finally:
        cache.close()
    counts.update(wallSeconds=time.perf_counter() - started, protectedUnchanged=before == hashes())
    history_path = HERE / "data/baseline-runs.json"
    last_run_path = HERE / "data/last-baseline-run.json"
    history = json.loads(history_path.read_text()) if history_path.exists() else (
        [json.loads(last_run_path.read_text())] if last_run_path.exists() else [])
    atomic_json(history_path, [*history, counts])
    atomic_json(HERE / "data/last-baseline-run.json", counts)
    if not counts["protectedUnchanged"]:
        raise ValueError("Protected files changed externally during evaluation; inspect before continuing")
    print(json.dumps(counts, indent=2))
    return 130 if counts["interrupted"] else (1 if counts["failed"] else 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", choices=("select", "baseline", "heads", "report"), required=True)
    parser.add_argument("--limit", type=int, default=11)
    args = parser.parse_args()
    if not 1 <= args.limit <= 30:
        parser.error("--limit must be 1–30")
    signal.signal(signal.SIGTERM, poc_runtime.handle_termination)
    manifest = selection()
    if args.stage == "select":
        print(json.dumps(manifest, ensure_ascii=False, indent=2))
        return 0
    if args.stage == "baseline":
        code = baseline(manifest, args.limit)
        atomic_json(HERE / "output/before.json", load_records(manifest))
        return code
    if args.stage == "heads":
        from heads import refine
        refine(manifest, load_records(manifest))
    else:
        from report import make_report
        make_report(manifest, load_records(manifest))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
