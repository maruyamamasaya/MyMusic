#!/usr/bin/env python3
"""Isolated v2 PoC: select metadata first, then process at most 30 fixed tracks."""
from __future__ import annotations

import argparse
import importlib.metadata
import json
import os
import platform
import signal
import sys
import time

sys.dont_write_bytecode = True
from prepare_models import HERE
sys.path.insert(0, str(HERE.parent))
# All library-generated caches are isolated too; do not touch v1's Python cache.
os.environ["NUMBA_CACHE_DIR"] = str(HERE / ".runtime/numba")
os.environ["MPLCONFIGDIR"] = str(HERE / ".runtime/matplotlib")
os.environ["XDG_CACHE_HOME"] = str(HERE / ".runtime/cache")
os.environ["OMP_NUM_THREADS"] = "2"
os.environ["OPENBLAS_NUM_THREADS"] = "2"

from storage import (PocCache, atomic_json, choose_tracks, production_hashes, safe_target,
                     read_v1, validate_manifest, verify_audio_identity)
from engine import Engine, config_key, model_manifest
from reporting import write_reports


def handle_termination(_signum, _frame):
    raise KeyboardInterrupt()


def process_rows(manifest, cache, config, engine, limit):
    counts = dict(attempted=0, success=0, failed=0, skipped=0, interrupted=False, errors=[])
    try:
        for index, row in enumerate(manifest["tracks"], 1):
            if cache.success(row, config):
                counts["skipped"] += 1
                print(f"[{index}/{len(manifest['tracks'])}] SKIP {row['v1'].get('title', '')}", flush=True)
                continue
            if counts["attempted"] >= limit:
                continue
            counts["attempted"] += 1
            print(f"[{index}/{len(manifest['tracks'])}] {row['v1'].get('artist', '')} — "
                  f"{row['v1'].get('title', '')}: analyzing", flush=True)
            try:
                path = verify_audio_identity(row)
                result = engine.analyze(path, row["v1"]["duration"])
                verify_audio_identity(row)
                # Commit before progressing. A killed/interrupted track remains pending.
                cache.save(row, config, "success", result)
                counts["success"] += 1
                top = sorted(result["labels"]["tags"].items(), key=lambda item: -item[1])[:5]
                print(f"Done {result['timing']['total']:.2f}s | "
                      + ", ".join(f"{label} {score:.3f}" for label, score in top), flush=True)
            except Exception as error:
                message = f"{type(error).__name__}: {error}"
                cache.save(row, config, "failed", {"error": message})
                counts["failed"] += 1
                counts["errors"].append({"relativePath": row["relativePath"], "error": message})
                print(f"FAILED: {message}", flush=True)
    except KeyboardInterrupt:
        counts["interrupted"] = True
        print("Interrupted. Completed tracks are committed; run --resume to continue.", flush=True)
    return counts


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--select", type=int, metavar="N", help="Freeze 10–30 tracks from saved v1 metadata; no audio access")
    parser.add_argument("--limit", type=int, default=30, help="Max pending attempts this invocation (1–30)")
    parser.add_argument("--resume", action="store_true", help="Resume (successful PoC cache entries are always skipped)")
    parser.add_argument("--report-only", action="store_true", help="Regenerate reports from saved PoC results; no audio/model inference")
    args = parser.parse_args(argv)
    if not 1 <= args.limit <= 30:
        parser.error("--limit must be 1–30; full-library analysis is not supported")
    manifest_path = HERE / "data/selection.json"
    before = production_hashes()
    if args.select is not None:
        if manifest_path.exists():
            parser.error("Selection is frozen already; this PoC cannot automatically expand its audio scope")
        manifest = dict(productionHashes=before, tracks=choose_tracks(read_v1(), args.select))
        validate_manifest(manifest)
        if production_hashes() != before:
            raise ValueError("Production data changed during selection")
        atomic_json(manifest_path, manifest)
        print(f"Selected {len(manifest['tracks'])} cached identities. Audio files have not been opened.")
        return 0
    if not manifest_path.exists():
        parser.error("Run --select 20 first (metadata-only)")
    manifest = json.loads(manifest_path.read_text())
    validate_manifest(manifest)
    if before != manifest["productionHashes"]:
        raise ValueError("Production snapshot changed; stop and review, do not silently mix versions")
    config = config_key(model_manifest())
    started = time.perf_counter()
    run = dict(platform=platform.platform(), machine=platform.machine(), python=platform.python_version(),
               dependencies={name: importlib.metadata.version(name) for name in
                             ("numpy", "librosa", "onnxruntime", "psutil", "scipy", "numba")})
    cache = PocCache(HERE / "data/poc.sqlite3")
    try:
        if args.report_only:
            run.update(reportOnly=True, setupSeconds=0.0)
        else:
            signal.signal(signal.SIGTERM, handle_termination)
            safe_target(HERE / ".runtime")
            pending = any(not cache.success(row, config) for row in manifest["tracks"])
            # No dependency/model initialization or audio reads on an all-cache-hit resume.
            engine = Engine() if pending else None
            run["setupSeconds"] = time.perf_counter() - started
            from threadpoolctl import threadpool_limits
            with threadpool_limits(limits=2):
                run.update(process_rows(manifest, cache, config, engine, args.limit))
        run["wallSeconds"] = time.perf_counter() - started
        run["productionUnchanged"] = production_hashes() == before
        if not run["productionUnchanged"]:
            raise ValueError("Production changed externally during PoC; do not trust this comparison")
        # Preserve run history, including partial and all-cache-hit invocations.
        history_path = HERE / "data/runs.json"
        history = json.loads(history_path.read_text()) if history_path.exists() else []
        atomic_json(history_path, [*history, run])
        summary = write_reports(manifest, cache, config, run)
        print(json.dumps({"trackCount": summary["tracks"], **run}, ensure_ascii=False, indent=2))
        return 130 if run.get("interrupted") else (1 if run.get("failed") else 0)
    finally:
        cache.close()


if __name__ == "__main__":
    raise SystemExit(main())
