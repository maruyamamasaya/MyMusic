from __future__ import annotations

import gc
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DSP_MODEL_REVISION = "dsp-beta1-r2"


@dataclass(frozen=True)
class AnalysisConfig:
    sample_rate: int = 22_050
    segment_seconds: float = 30.0
    segment_count: int = 3

    def cache_key(self) -> str:
        return (
            f"sr={self.sample_rate};segment={self.segment_seconds:g};"
            f"count={self.segment_count};model={DSP_MODEL_REVISION}"
        )


def analyze_audio(path: Path, duration: float, config: AnalysisConfig) -> dict[str, Any]:
    # Heavy dependencies are imported here so CLI help and cache inspection remain fast.
    import librosa
    import numpy as np

    segment_metrics: list[dict[str, float]] = []
    for offset in _segment_offsets(duration, config.segment_seconds, config.segment_count):
        load_duration = min(config.segment_seconds, max(0.5, duration - offset))
        y, sample_rate = librosa.load(
            str(path),
            sr=config.sample_rate,
            mono=True,
            offset=offset,
            duration=load_duration,
            dtype=np.float32,
        )
        if y.size < sample_rate // 2:
            del y
            continue
        segment_metrics.append(_analyze_segment(y, sample_rate))
        del y
        gc.collect()

    if not segment_metrics:
        raise ValueError("解析可能な音声サンプルを読み込めませんでした")

    metrics = {
        key: float(np.median([segment[key] for segment in segment_metrics]))
        for key in segment_metrics[0]
    }
    scores = _scores(metrics)
    tempo_values = [segment["tempo"] for segment in segment_metrics if segment["tempo"] > 0]
    if tempo_values:
        scores["tempo"] = round(float(np.median(tempo_values)), 3)
    return scores


def _segment_offsets(duration: float, segment_seconds: float, segment_count: int) -> list[float]:
    segment_length = min(segment_seconds, duration)
    available = max(0.0, duration - segment_length)
    if segment_count <= 1 or available <= segment_length * 0.25:
        return [available * 0.5]
    if segment_count == 2:
        fractions = [0.15, 0.85]
    elif segment_count == 3:
        fractions = [0.1, 0.5, 0.9]
    else:
        fractions = [index / (segment_count - 1) for index in range(segment_count)]
    return [available * fraction for fraction in fractions]


def _analyze_segment(y: Any, sample_rate: int) -> dict[str, float]:
    import librosa
    import numpy as np

    hop_length = 512
    magnitude = np.abs(librosa.stft(y, n_fft=2048, hop_length=hop_length))
    power = magnitude**2
    total_power = float(np.sum(power)) + 1e-12
    frequencies = librosa.fft_frequencies(sr=sample_rate, n_fft=2048)

    rms_frames = librosa.feature.rms(S=magnitude)[0]
    rms = float(np.mean(rms_frames))
    loudness_db = float(librosa.amplitude_to_db(np.asarray([max(rms, 1e-8)]), ref=1.0)[0])
    rms_db_frames = librosa.amplitude_to_db(np.maximum(rms_frames, 1e-8), ref=1.0)
    dynamic_range = float(np.percentile(rms_db_frames, 90) - np.percentile(rms_db_frames, 10))

    onset_envelope = librosa.onset.onset_strength(S=librosa.power_to_db(power, ref=np.max), sr=sample_rate, hop_length=hop_length)
    tempo_value = librosa.feature.tempo(onset_envelope=onset_envelope, sr=sample_rate, hop_length=hop_length, aggregate=np.median)
    tempo = float(np.asarray(tempo_value).reshape(-1)[0]) if np.asarray(tempo_value).size else 0.0
    onset_strength = _clip(float(np.mean(onset_envelope)) / 4.0)
    pulse_clarity = _pulse_clarity(onset_envelope, sample_rate, hop_length)

    harmonic, percussive = librosa.decompose.hpss(magnitude)
    harmonic_ratio = float(np.sum(harmonic**2) / total_power)
    percussive_ratio = float(np.sum(percussive**2) / total_power)

    centroid = float(np.mean(librosa.feature.spectral_centroid(S=magnitude, sr=sample_rate))) / (sample_rate / 2)
    bandwidth = float(np.mean(librosa.feature.spectral_bandwidth(S=magnitude, sr=sample_rate))) / (sample_rate / 2)
    rolloff = float(np.mean(librosa.feature.spectral_rolloff(S=magnitude, sr=sample_rate, roll_percent=0.85))) / (sample_rate / 2)
    flatness = float(np.mean(librosa.feature.spectral_flatness(S=magnitude)))
    zcr = float(np.mean(librosa.feature.zero_crossing_rate(y))) / 0.2
    contrast = float(np.mean(librosa.feature.spectral_contrast(S=magnitude, sr=sample_rate))) / 35.0

    chroma = librosa.feature.chroma_stft(S=power, sr=sample_rate, tuning=0.0)
    chroma_distribution = np.mean(chroma, axis=1) + 1e-8
    chroma_distribution /= np.sum(chroma_distribution)
    chroma_entropy = -float(np.sum(chroma_distribution * np.log(chroma_distribution))) / math.log(12)

    bass_ratio = _band_ratio(power, frequencies, 20, 250, total_power)
    mid_ratio = _band_ratio(power, frequencies, 250, 4_000, total_power)
    high_ratio = _band_ratio(power, frequencies, 4_000, sample_rate / 2, total_power)

    return {
        "tempo": tempo if math.isfinite(tempo) else 0.0,
        "loudness": _clip((loudness_db + 60.0) / 52.0),
        "dynamic": _clip(dynamic_range / 24.0),
        "onset": onset_strength,
        "pulse": pulse_clarity,
        "harmonic": _clip(harmonic_ratio),
        "percussive": _clip(percussive_ratio),
        "centroid": _clip(centroid),
        "bandwidth": _clip(bandwidth),
        "rolloff": _clip(rolloff),
        "flatness": _clip(flatness / 0.3),
        "zcr": _clip(zcr),
        "contrast": _clip(contrast),
        "chroma_concentration": _clip(1.0 - chroma_entropy),
        "bass": _clip(bass_ratio * 4.0),
        "mid": _clip(mid_ratio * 1.5),
        "high": _clip(high_ratio * 5.0),
    }


def _scores(m: dict[str, float]) -> dict[str, Any]:
    brightness = _clip(0.42 * m["centroid"] + 0.33 * m["rolloff"] + 0.25 * m["high"])
    energy = _clip(0.55 * m["loudness"] + 0.25 * m["onset"] + 0.20 * m["percussive"])
    transient_balance = _clip(1.0 - abs(m["percussive"] - 0.35) / 0.65)

    piano = _clip(
        0.28 * m["harmonic"]
        + 0.24 * m["chroma_concentration"]
        + 0.20 * transient_balance
        + 0.16 * m["contrast"]
        + 0.12 * m["mid"]
        - 0.10 * m["flatness"]
    )
    ambient = _clip(
        0.24 * m["harmonic"]
        + 0.23 * (1.0 - m["onset"])
        + 0.20 * (1.0 - m["pulse"])
        + 0.18 * (1.0 - energy)
        + 0.15 * (1.0 - m["zcr"])
    )
    electronic = _clip(
        0.24 * m["percussive"]
        + 0.20 * m["bass"]
        + 0.18 * m["flatness"]
        + 0.23 * m["pulse"]
        + 0.15 * brightness
    )

    tempo = m["tempo"]
    tempo_affinity = max(_gaussian(tempo, 172.0, 24.0), 0.72 * _gaussian(tempo, 86.0, 12.0)) if tempo > 0 else 0.0
    drum_and_bass = _clip(
        0.32 * tempo_affinity
        + 0.20 * electronic
        + 0.18 * m["percussive"]
        + 0.16 * m["bass"]
        + 0.14 * m["pulse"]
    )
    aggressive = _clip(
        0.28 * energy
        + 0.22 * m["loudness"]
        + 0.18 * m["onset"]
        + 0.17 * brightness
        + 0.15 * m["percussive"]
    )
    calm = _clip(
        0.30 * (1.0 - aggressive)
        + 0.22 * m["harmonic"]
        + 0.18 * (1.0 - m["onset"])
        + 0.15 * (1.0 - energy)
        + 0.15 * ambient
    )
    dark = _clip(0.72 * (1.0 - brightness) + 0.28 * m["bass"])
    vocal = _clip(
        0.28 * m["harmonic"]
        + 0.25 * m["mid"]
        + 0.19 * m["contrast"]
        + 0.16 * m["dynamic"]
        + 0.12 * (1.0 - m["flatness"])
        - 0.13 * m["percussive"]
    )

    return {
        "energy": _rounded(energy),
        "piano": _rounded(piano),
        "ambient": _rounded(ambient),
        "electronic": _rounded(electronic),
        "drumAndBass": _rounded(drum_and_bass),
        "aggressive": _rounded(aggressive),
        "calm": _rounded(calm),
        "bright": _rounded(brightness),
        "dark": _rounded(dark),
        "vocal": _rounded(vocal),
        "instrumental": _rounded(1.0 - vocal),
    }


def _pulse_clarity(onset_envelope: Any, sample_rate: int, hop_length: int) -> float:
    import librosa
    import numpy as np

    if onset_envelope.size < 4 or float(np.max(onset_envelope)) <= 0:
        return 0.0
    maximum_lag = max(2, int((60.0 / 40.0) * sample_rate / hop_length))
    autocorrelation = librosa.autocorrelate(onset_envelope, max_size=maximum_lag)
    minimum_lag = max(1, int((60.0 / 240.0) * sample_rate / hop_length))
    denominator = float(autocorrelation[0]) + 1e-12
    return _clip(float(np.max(autocorrelation[minimum_lag:])) / denominator)


def _band_ratio(power: Any, frequencies: Any, low: float, high: float, total: float) -> float:
    selected = (frequencies >= low) & (frequencies < high)
    return float(power[selected, :].sum() / total)


def _gaussian(value: float, center: float, width: float) -> float:
    return math.exp(-0.5 * ((value - center) / width) ** 2)


def _clip(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def _rounded(value: float) -> float:
    return round(_clip(value), 6)
