from __future__ import annotations

import json
import math
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Sequence


LOUDNESS_ANALYSIS_REVISION = "ffmpeg-loudnorm-bs1770-v1"


@dataclass(frozen=True)
class NormalizationPolicy:
    target_lufs: float = -14.0
    no_change_min_lufs: float = -17.0
    no_change_max_lufs: float = -11.0
    maximum_boost_db: float = 4.0
    maximum_cut_db: float = -4.0
    true_peak_ceiling_dbtp: float = -1.0


CONSERVATIVE_POLICY = NormalizationPolicy()


def calculate_normalization_gain_db(
    integrated_lufs: float,
    true_peak_dbtp: float,
    policy: NormalizationPolicy = CONSERVATIVE_POLICY,
) -> float:
    """Return a fixed, conservative gain while respecting the true-peak ceiling."""
    if not math.isfinite(integrated_lufs) or not math.isfinite(true_peak_dbtp):
        raise ValueError("ラウドネス値は有限値にしてください")
    if policy.no_change_min_lufs <= integrated_lufs <= policy.no_change_max_lufs:
        return 0.0

    target_gain = policy.target_lufs - integrated_lufs
    bounded_gain = min(max(target_gain, policy.maximum_cut_db), policy.maximum_boost_db)
    peak_safe_gain = min(bounded_gain, policy.true_peak_ceiling_dbtp - true_peak_dbtp)
    return round(min(max(peak_safe_gain, policy.maximum_cut_db), policy.maximum_boost_db), 3)


def analyze_loudness(
    path: Path,
    policy: NormalizationPolicy = CONSERVATIVE_POLICY,
    runner: Callable[..., subprocess.CompletedProcess[str]] = subprocess.run,
) -> dict[str, float]:
    """Measure the source without writing audio by running FFmpeg's BS.1770 loudnorm pass."""
    filter_value = (
        f"loudnorm=I={policy.target_lufs:g}:TP={policy.true_peak_ceiling_dbtp:g}:"
        "LRA=11:print_format=json"
    )
    command: Sequence[str] = (
        "ffmpeg", "-hide_banner", "-nostats", "-nostdin", "-i", str(path),
        "-map", "0:a:0", "-vn", "-sn", "-dn", "-af", filter_value,
        "-f", "null", "-",
    )
    completed = runner(command, capture_output=True, text=True, check=False)
    if completed.returncode != 0:
        message = completed.stderr.strip().splitlines()[-1] if completed.stderr.strip() else "unknown error"
        raise RuntimeError(f"FFmpeg loudness analysis failed: {message}")

    statistics = _extract_statistics(completed.stderr)
    integrated_lufs = _finite_float(statistics.get("input_i"), "input_i")
    true_peak_dbtp = _finite_float(statistics.get("input_tp"), "input_tp")
    gain_db = calculate_normalization_gain_db(integrated_lufs, true_peak_dbtp, policy)
    return {
        "integratedLUFS": round(integrated_lufs, 3),
        "truePeakDBTP": round(true_peak_dbtp, 3),
        "normalizationGainDB": gain_db,
    }


def _extract_statistics(output: str) -> dict[str, Any]:
    decoder = json.JSONDecoder()
    for start in (index for index, character in reversed(list(enumerate(output))) if character == "{"):
        try:
            value, _ = decoder.raw_decode(output[start:])
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and {"input_i", "input_tp"}.issubset(value):
            return value
    raise ValueError("FFmpeg loudnorm statistics were not found")


def _finite_float(value: Any, name: str) -> float:
    try:
        result = float(value)
    except (TypeError, ValueError) as error:
        raise ValueError(f"FFmpeg loudnorm {name} is invalid") from error
    if not math.isfinite(result):
        raise ValueError(f"FFmpeg loudnorm {name} is not finite")
    return result
