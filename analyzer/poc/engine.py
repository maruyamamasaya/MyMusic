"""Bounded CPU inference. Semantic scores come only from trained model outputs."""
from __future__ import annotations

import gc
import json
import math
import os
import resource
import subprocess
import sys
import time
from pathlib import Path

from prepare_models import CHECKSUMS, HERE, sha256

# ORT 1.29's API opt-out is too late for its initialization event on macOS.
# This process-level switch must be set before importing onnxruntime.
os.environ["ORT_DISABLE_TELEMETRY"] = "1"

REVISION = "effnet-jamendo-poc2-average-mono"
MAPPING = {
    "piano": ("tags", "piano"),
    "ambient": ("tags", "ambient"),
    "electronic": ("tags", "electronic"),
    "drumAndBass": ("discogs", "Electronic---Drum n Bass"),
    "calm": ("mood", "calm"),
    "dark": ("mood", "dark"),
    "vocal": ("tags", "voice"),
}
OMITTED = ("bright", "aggressive", "instrumental")


def model_manifest() -> dict:
    manifest = json.loads((HERE / "models/manifest.json").read_text())
    for key in ("discogs", "tags", "mood"):
        for extension in ("json", "onnx"):
            path = HERE / "models" / f"{key}.{extension}"
            if sha256(path) != CHECKSUMS[path.name] or manifest[key][extension]["sha256"] != CHECKSUMS[path.name]:
                raise ValueError(f"Model checksum mismatch: {path.name}")
    return manifest


def config_key(manifest: dict) -> str:
    return json.dumps({"revision": REVISION, "models": manifest, "analysisVersion": 2,
                       "DSP": "dsp-beta1-r2 metrics only; sr22050; 3x30s; median",
                       "frontend": "MusiCNN symmetric Hann512/hop256/mel96/16k/patch128/hop62",
                       "aggregation": "mean of patch sigmoid probabilities", "batch": 8,
                       "decode": "native rate float32; channel mean; librosa soxr_hq to22050",
                       "threads": 2, "mapping": MAPPING}, sort_keys=True)


def mapped_features(scores: dict[str, dict[str, float]]) -> dict[str, float]:
    # No sigmoid a second time, no min/max rescaling, no DSP semantic fallback.
    result = {}
    for feature, (group, label) in MAPPING.items():
        value = float(scores[group][label])
        if not math.isfinite(value) or not 0 <= value <= 1:
            raise ValueError(f"Invalid model probability: {group}/{label}")
        result[feature] = round(value, 6)
    return result


def mel_spectrogram(y):
    """Independently implement the published MusiCNN frontend parameters.

    See README for the precise official references and validation limitations.
    No per-track normalization: the pretrained network expects absolute log mel.
    """
    import librosa
    import numpy as np

    if y.size < 32768:
        raise ValueError("At least 2.048 seconds are needed for a model patch")
    frame_count = 1 + math.ceil((len(y) - 256) / 256)
    padded = np.pad(y, (256, 512))
    frames = np.lib.stride_tricks.sliding_window_view(padded, 512)[::256][:frame_count]
    windowed = frames * np.hanning(512).astype(np.float32)
    power = np.abs(np.fft.rfft(windowed, axis=1)) ** 2
    filters = librosa.filters.mel(sr=16000, n_fft=512, n_mels=96,
                                 fmin=0, fmax=8000, htk=False, norm="slaney")
    return np.log10(1.0 + 10000.0 * (power @ filters.T)).astype(np.float32)


def peak_mib() -> float:
    value = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return value / (1024 ** 2 if sys.platform == "darwin" else 1024)


def average_channels(raw: bytes, channels: int):
    import numpy as np
    if not 1 <= channels <= 8:
        raise ValueError("PoC supports 1–8 channels")
    samples = np.frombuffer(raw, dtype="<f4")
    if samples.size % channels:
        raise ValueError("Incomplete PCM frame")
    # Same arithmetic mean policy as librosa.to_mono / Essentia MonoLoader mix.
    # FFmpeg '-ac 1' uses different gains for stereo and is intentionally avoided.
    return samples.reshape(-1, channels).mean(axis=1)


class Engine:
    def observe_embedding(self, embedding):
        """Optional bounded PoC observer; default stores no embeddings."""

    def observe_segment(self, samples, sample_rate):
        """Optional diagnostics observer; never feeds metadata into inference."""

    def __init__(self):
        import onnxruntime as ort
        import numpy as np

        ort.disable_telemetry_events()
        self.sessions = {}
        self.labels = {}
        for group in ("discogs", "tags", "mood"):
            opts = ort.SessionOptions()
            opts.intra_op_num_threads = 2
            opts.inter_op_num_threads = 1
            opts.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
            self.sessions[group] = ort.InferenceSession(
                str(HERE / "models" / f"{group}.onnx"), opts, providers=["CPUExecutionProvider"])
            self.labels[group] = json.loads((HERE / "models" / f"{group}.json").read_text())["classes"]
            session = self.sessions[group]
            # Top50's metadata incorrectly says 56 outputs; check the actual graph.
            if session.get_outputs()[0].shape[-1] != len(self.labels[group]):
                raise ValueError(f"Model output / label count mismatch: {group}")
        for group, label in MAPPING.values():
            if label not in self.labels[group]:
                raise ValueError(f"Missing label: {group}/{label}")
        # Synthetic warmup, not another real track. Separate from per-track timings.
        from mymusic_analyzer.audio import _analyze_segment
        _analyze_segment(np.sin(np.arange(22050, dtype=np.float32) * .04) * .01, 22050)
        self.predict(np.zeros(48000, dtype=np.float32))

    def predict(self, y) -> tuple[dict, int, float, float]:
        import numpy as np

        start = time.perf_counter()
        mel = mel_spectrogram(y)
        starts = range(0, len(mel) - 128 + 1, 62)
        preprocessing = time.perf_counter() - start
        sums = {key: np.zeros(len(labels), dtype=np.float64) for key, labels in self.labels.items()}
        count = 0
        inference = 0.0
        for offset in range(0, len(starts), 8):
            start = time.perf_counter()
            batch = np.stack([mel[s:s + 128] for s in starts[offset:offset + 8]])
            preprocessing += time.perf_counter() - start
            start = time.perf_counter()
            style, embedding = self.sessions["discogs"].run(
                ["activations", "embeddings"], {"melspectrogram": batch})
            predictions = {"discogs": style}
            for group in ("tags", "mood"):
                predictions[group] = self.sessions[group].run(
                    ["activations"], {"embeddings": embedding})[0]
            inference += time.perf_counter() - start
            self.observe_embedding(embedding)
            for group, values in predictions.items():
                if not np.isfinite(values).all() or np.any(values < 0) or np.any(values > 1):
                    raise ValueError(f"Non-probability output in {group}")
                sums[group] += values.sum(axis=0, dtype=np.float64)
            count += len(batch)
        if not count:
            raise ValueError("No model patches")
        return sums, count, preprocessing, inference

    def analyze(self, path: Path, duration: float) -> dict:
        import librosa
        import numpy as np
        import psutil
        from mymusic_analyzer.audio import _analyze_segment, _segment_offsets

        started = time.perf_counter()
        timing = dict(decode=0.0, dsp=0.0, preprocessing=0.0, inference=0.0)
        start = time.perf_counter()
        probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0",
                                "-show_entries", "stream=channels,sample_rate", "-of", "json", str(path)],
                               capture_output=True, timeout=30, check=True)
        stream = json.loads(probe.stdout)["streams"][0]
        channels, native_rate = int(stream["channels"]), int(stream["sample_rate"])
        if not 1 <= channels <= 8 or not 8000 <= native_rate <= 192000:
            raise ValueError("Native audio format outside the bounded PoC limits")
        timing["decode"] += time.perf_counter() - start
        sums = {key: np.zeros(len(labels), dtype=np.float64) for key, labels in self.labels.items()}
        metrics = []
        loudness = []
        patch_count = 0
        offsets = _segment_offsets(duration, 30.0, 3)
        for offset in offsets:
            start = time.perf_counter()
            command = ["ffmpeg", "-v", "error", "-nostdin", "-threads", "1",
                       "-ss", str(offset), "-i", str(path), "-t", str(min(30.0, duration - offset)),
                       "-map", "0:a:0", "-vn", "-ac", str(channels), "-ar", str(native_rate),
                       "-f", "f32le", "pipe:1"]
            decoded = subprocess.run(command, capture_output=True, timeout=60, check=True)
            y = average_channels(decoded.stdout, channels)
            del decoded
            y = librosa.resample(y, orig_sr=native_rate, target_sr=22050, res_type="soxr_hq")
            timing["decode"] += time.perf_counter() - start
            if len(y) < 22050 * 2.048 or not np.isfinite(y).all():
                raise ValueError("Audio segment is too short or invalid")
            start = time.perf_counter()
            metrics.append(_analyze_segment(y, 22050))
            self.observe_segment(y, 22050)
            loudness.append(float(20 * np.log10(max(float(np.sqrt(np.mean(y ** 2))), 1e-10))))
            timing["dsp"] += time.perf_counter() - start
            start = time.perf_counter()
            y16 = librosa.resample(y, orig_sr=22050, target_sr=16000, res_type="soxr_hq")
            timing["preprocessing"] += time.perf_counter() - start
            prediction, count, preprocessing, inference = self.predict(y16)
            for group in sums:
                sums[group] += prediction[group]
            patch_count += count
            timing["preprocessing"] += preprocessing
            timing["inference"] += inference
            del y, y16, prediction
            gc.collect()
        aggregate = {key: float(np.median([m[key] for m in metrics])) for key in metrics[0]}
        scores = {group: dict(zip(self.labels[group], (values / patch_count).tolist()))
                  for group, values in sums.items()}
        features = mapped_features(scores)
        features["energy"] = round(min(1.0, max(0.0, .55 * aggregate["loudness"]
                                  + .25 * aggregate["onset"] + .20 * aggregate["percussive"])), 6)
        if aggregate["tempo"] > 0:
            features["tempo"] = round(aggregate["tempo"], 3)
        timing["total"] = time.perf_counter() - started
        return dict(features=features, labels=scores, metrics=aggregate,
                    rmsDBFS=float(np.median(loudness)), offsets=offsets, patches=patch_count,
                    channels=channels, nativeRate=native_rate, revision=REVISION,
                    timing=timing, rssMiB=psutil.Process().memory_info().rss / 1024 ** 2,
                    peakMiB=peak_mib())
