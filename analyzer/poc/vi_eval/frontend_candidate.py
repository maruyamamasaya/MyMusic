"""Isolated terminal-frame correction; the historical baseline Engine stays frozen."""
from __future__ import annotations

import math
import numpy as np
import librosa
from engine import mel_spectrogram as baseline_mel


def corrected_mel(samples):
    # Essentia FrameCutter(startFromZero=False) includes the first frame whose
    # center reaches/passes EOF. Baseline omitted that last centered frame.
    # Prefix must remain bit-identical so existing unaffected embeddings can be reused.
    prefix = baseline_mel(samples)
    count = 1 + math.ceil(len(samples) / 256)
    if len(prefix) + 1 != count:
        raise ValueError("Unexpected legacy frame layout")
    start = len(prefix) * 256 - 256
    frame = np.zeros(512, dtype=np.float32)
    available = samples[start:start + 512]
    frame[:len(available)] = available
    power = np.abs(np.fft.rfft(frame * np.hanning(512).astype(np.float32))) ** 2
    filters = librosa.filters.mel(sr=16000,n_fft=512,n_mels=96,fmin=0,fmax=8000,htk=False,norm="slaney")
    tail = np.log10(1 + 10000 * (power @ filters.T)).astype(np.float32)
    return np.concatenate((prefix, tail[None,:]))


def patch_starts(frame_count):
    return list(range(0, frame_count - 128 + 1, 62))


def unchanged_patch_layout(samples):
    old = 1 + math.ceil((samples - 256) / 256)
    new = 1 + math.ceil(samples / 256)
    return patch_starts(old) == patch_starts(new)
