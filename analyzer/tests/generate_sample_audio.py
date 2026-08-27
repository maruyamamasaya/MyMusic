#!/usr/bin/env python3
"""Generate two short WAV files for local end-to-end Analyzer verification."""

from __future__ import annotations

import argparse
import math
import struct
import wave
from pathlib import Path


SAMPLE_RATE = 22_050
DURATION = 12.0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    calm = args.output / "Test Artist" / "Calm Album" / "Calm Tone.wav"
    rhythm = args.output / "Test Artist" / "Rhythm Album" / "Fast Rhythm.wav"
    _write(calm, _calm_sample)
    _write(rhythm, _rhythm_sample)
    print(calm)
    print(rhythm)


def _write(path: Path, sample_function) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(SAMPLE_RATE)
        for second in range(int(DURATION)):
            frames = bytearray()
            for offset in range(SAMPLE_RATE):
                index = second * SAMPLE_RATE + offset
                value = max(-1.0, min(1.0, sample_function(index)))
                frames.extend(struct.pack("<h", int(value * 32_767)))
            audio.writeframes(frames)


def _calm_sample(index: int) -> float:
    time = index / SAMPLE_RATE
    envelope = 0.55 + 0.2 * math.sin(2 * math.pi * 0.08 * time)
    return envelope * (
        0.26 * math.sin(2 * math.pi * 220 * time)
        + 0.14 * math.sin(2 * math.pi * 330 * time)
        + 0.08 * math.sin(2 * math.pi * 440 * time)
    )


def _rhythm_sample(index: int) -> float:
    time = index / SAMPLE_RATE
    beat_position = (time * 172 / 60) % 1.0
    transient = math.exp(-beat_position * 24)
    noise = math.sin(index * 12.9898) * math.sin(index * 78.233) * transient * 0.20
    bass = math.sin(2 * math.pi * 86 * time) * (0.18 + 0.32 * transient)
    high = math.sin(2 * math.pi * 4_200 * time) * transient * 0.18
    return bass + high + noise


if __name__ == "__main__":
    main()
