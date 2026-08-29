"""Compare synthetic signals with official native Essentia, not another librosa formula."""
from __future__ import annotations

import json
import sys
import importlib.metadata
from evaluate import HERE, POC, target, selection, records, atomic_json
sys.path.insert(0,str(HERE / ".native"))
import essentia
import essentia.standard as es
import numpy as np
from engine import mel_spectrogram
from frontend_candidate import corrected_mel, patch_starts, unchanged_patch_layout


def audit():
    reference = es.TensorflowInputMusiCNN()
    cases = []
    rng = np.random.default_rng(20260829)
    signals = {"silence":np.zeros(48000,dtype=np.float32),
               "noise30s":rng.normal(0,.1,480000).astype(np.float32),
               "patch_boundary":rng.normal(0,.1,48384).astype(np.float32),
               "minimum_patch":rng.normal(0,.1,32768).astype(np.float32)}
    for hz in (80,440,1000,6000):
        signals[f"sine{hz}"]=(.1*np.sin(np.arange(48000)*2*np.pi*hz/16000)).astype(np.float32)
    for name,y in signals.items():
        native = np.stack([reference(f) for f in es.FrameGenerator(y,frameSize=512,hopSize=256,startFromZero=False)])
        baseline, candidate = mel_spectrogram(y), corrected_mel(y)
        if candidate.shape != native.shape:
            raise ValueError("Corrected frame count does not match native Essentia")
        prefix_equal = bool(np.array_equal(candidate[:len(baseline)],baseline))
        difference = np.abs(candidate-native)
        if not prefix_equal or float(difference.max()) > 3e-4:
            raise ValueError(f"Native parity failed: {name}, {difference.max()}")
        cases.append(dict(signal=name,samples=len(y),oldFrames=len(baseline),nativeFrames=len(native),
                          oldPatches=len(patch_starts(len(baseline))),newPatches=len(patch_starts(len(candidate))),
                          maxAbsError=float(difference.max()),meanAbsError=float(difference.mean()),prefixBitIdentical=prefix_equal))
    selected = records(selection())
    layouts = []
    for row in selected:
        segments = row["baseline"]["segments"]
        safe = all(unchanged_patch_layout(s["samples16k"]) for s in segments)
        layouts.append(dict(relativePath=row["identity"]["relativePath"],cachedEmbeddingsReusable=safe,
                            samples=[s["samples16k"] for s in segments]))
    if not all(r["cachedEmbeddingsReusable"] for r in layouts):
        raise ValueError("A selected track needs new patches; do not claim cached equivalence")
    old = json.loads((POC / "human_eval/output/after.json").read_text())["tracks"]
    # Old results record offsets/patch counts, and the previous code used 30s windows.
    old_safe = all(r["before"]["patches"] == 29 * len(r["before"]["offsets"])
                   and all(o + 30 <= r["identity"]["v1"]["duration"] for o in r["before"]["offsets"])
                   for r in old) and unchanged_patch_layout(480000)
    if not old_safe:
        raise ValueError("Old embeddings cannot be certified reusable")
    result = dict(essentia=importlib.metadata.version("essentia"),implementation=essentia.__version__,
                  reference="native TensorflowInputMusiCNN + FrameGenerator(startFromZero=False)",cases=cases,
                  correction="Append terminal centered frame; no magnitude/mel/normalization changes",
                  realAudioReads=0,layouts=layouts,regressionReusable=len(old),
                  maxAbsError=max(r["maxAbsError"] for r in cases),
                  limitation="Tests mel extraction with identical 16k PCM, not bit-exact native decoder/resampler or TensorFlow/ONNX graph parity. Streaming silence noise is not injected.")
    atomic_json(target("output/frontend-audit.json"),result)
    print(json.dumps(result,ensure_ascii=False,indent=2))


if __name__ == "__main__":
    audit()
