"""Frozen pretrained heads. No artist/title inputs, trained coefficients, or rescaling."""
from __future__ import annotations

import json
import math
from pathlib import Path
import sys
import time

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import engine  # Sets the process-level telemetry opt-out before ONNX is imported.
from prepare_models import sha256
from storage import atomic_json
from prepare_heads import CHECKSUMS, DIRECTORY, MODELS
from mymusic_analyzer.schema import make_document

REVISION = "human-eval-heads-v1"
MAPPING = {
    "vocal": ("voice_instrumental", "voice"),
    "instrumental": ("voice_instrumental", "instrumental"),
    "aggressive": ("mood_aggressive", "aggressive"),
    "calm": ("mood_relaxed", "relaxed"),
}


def remap(features, predictions):
    result = dict(features)
    for feature, (head, label) in MAPPING.items():
        value = float(predictions[head][label])
        if not math.isfinite(value) or not 0 <= value <= 1:
            raise ValueError("Invalid head score")
        result[feature] = round(value, 6)
    # Instrumental is the learned binary head output, not 1 minus a generic tag.
    return result


def manifest():
    data = json.loads((DIRECTORY / "manifest.json").read_text())
    for model in MODELS:
        for extension in ("json", "onnx"):
            name = f"{model}-discogs-effnet-1.{extension}"
            if sha256(DIRECTORY / name) != CHECKSUMS[name] or data[name]["sha256"] != CHECKSUMS[name]:
                raise ValueError(f"Head checksum mismatch: {name}")
    return {name: value for name, value in data.items()
            if name in {f"{model}-discogs-effnet-1.{extension}" for model in MODELS for extension in ("json", "onnx")}}


class HeadBank:
    def __init__(self):
        import onnxruntime as ort
        ort.disable_telemetry_events()
        self.sessions, self.labels = {}, {}
        for model in MODELS:
            path = DIRECTORY / f"{model}-discogs-effnet-1"
            metadata = json.loads(path.with_suffix(".json").read_text())
            self.labels[model] = metadata["classes"]
            if metadata["inference"]["embedding_model"]["model_name"] != "discogs-effnet-bs64-1":
                raise ValueError("Incompatible embedding model")
            options = ort.SessionOptions()
            options.intra_op_num_threads = 2
            options.inter_op_num_threads = 1
            options.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
            session = ort.InferenceSession(str(path.with_suffix(".onnx")), options,
                                           providers=["CPUExecutionProvider"])
            if session.get_inputs()[0].shape[-1] != 1280 or session.get_outputs()[0].shape[-1] != len(self.labels[model]):
                raise ValueError("Head schema mismatch")
            self.sessions[model] = session
        for model, label in MAPPING.values():
            if label not in self.labels[model]:
                raise ValueError("Missing mapping label")

    def predict(self, embeddings):
        import numpy as np
        if (embeddings.ndim != 2 or embeddings.shape[1] != 1280
                or not 1 <= len(embeddings) <= 256 or not np.isfinite(embeddings).all()):
            raise ValueError("Invalid/beyond-limit cached embeddings")
        result = {}
        for model, session in self.sessions.items():
            total = np.zeros(len(self.labels[model]), dtype=np.float64)
            for offset in range(0, len(embeddings), 8):
                batch = np.asarray(embeddings[offset:offset + 8], dtype=np.float32)
                predictions = session.run(None, {session.get_inputs()[0].name: batch})[0]
                if (not np.isfinite(predictions).all() or np.any(predictions < 0) or np.any(predictions > 1)
                        or not np.allclose(predictions.sum(axis=1), 1, atol=1e-5)):
                    raise ValueError("Expected binary softmax probabilities")
                total += predictions.sum(axis=0, dtype=np.float64)
            result[model] = dict(zip(self.labels[model], (total / len(embeddings)).tolist()))
        return result


def refine(selection, records):
    import numpy as np
    from benchmark import hashes
    if {row["relativePath"] for row in selection["tracks"]} != {record["identity"]["relativePath"] for record in records}:
        raise ValueError("Finish all selected baseline tracks before the head comparison")
    before = hashes()
    models = manifest()
    target = HERE / "output/after.json"
    config = json.dumps(dict(revision=REVISION, mapping=MAPPING, models=models,
                            aggregation="mean of per-patch binary softmax"), sort_keys=True)
    saved = json.loads(target.read_text()) if target.exists() else {}
    cached = {item["identity"]["relativePath"]: item for item in saved.get("tracks", [])}
    bank = None
    results = []
    run = dict(success=0, skipped=0, audioReads=0, setupSeconds=0.0)
    for record in records:
        baseline = record["before"]
        embedding_path = (HERE / baseline["embeddingFile"]).resolve()
        if not embedding_path.is_relative_to(HERE / "data"):
            raise ValueError("Embedding path escapes the evaluation data directory")
        if sha256(embedding_path) != baseline["embeddingSHA256"]:
            raise ValueError("Embedding checksum mismatch")
        old = cached.get(record["identity"]["relativePath"])
        if saved.get("config") == config and old and old["before"] == baseline:
            results.append(old)
            run["skipped"] += 1
            continue
        if bank is None:
            start = time.perf_counter()
            bank = HeadBank()
            run["setupSeconds"] = time.perf_counter() - start
        start = time.perf_counter()
        with np.load(embedding_path, allow_pickle=False) as data:
            predictions = bank.predict(data["embeddings"])
        elapsed = time.perf_counter() - start
        features = remap(baseline["features"], predictions)
        result = {**record, "after": dict(features=features, heads=predictions, headSeconds=elapsed)}
        results.append(result)
        run["success"] += 1
        atomic_json(target, dict(config=config, tracks=results))  # Checkpoint each track.
        print(record["identity"]["v1"]["title"], {key: features[key] for key in MAPPING}, flush=True)
    if hashes() != before:
        raise ValueError("Protected files changed externally during head evaluation")
    run["protectedUnchanged"] = True
    atomic_json(target, dict(config=config, tracks=results, run=run))
    export = []
    for result in results:
        identity = {key: value for key, value in result["identity"]["v1"].items() if key != "features"}
        export.append({**identity, "features": result["after"]["features"]})
    atomic_json(HERE / "output/music_features_human_eval.json", make_document(2, export))
    print(json.dumps(run, indent=2))
