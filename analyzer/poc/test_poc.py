from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import run
from engine import MAPPING, OMITTED, average_channels, mapped_features, mel_spectrogram
from reporting import distribution
from storage import HERE, PocCache, choose_tracks, safe_target, validate_manifest
from mymusic_analyzer.schema import make_document, validate_document


def row(index):
    entry = dict(relativePath=f"Artist/曲{index}.m4a", fileSize=100 + index,
                 duration=120.25, title=f"曲{index}", artist="Artist", album="Album",
                 features=dict(energy=.5, dark=.8, piano=.5))
    return dict(root="/synthetic/not-opened", relativePath=entry["relativePath"],
                fileSize=entry["fileSize"], mtimeNS=123, v1=entry, v1Config="v1")


def fake_result():
    return dict(features=dict(piano=.9, energy=.2), labels={"tags": {"piano": .9}},
                timing={"total": .01})


class PocTests(unittest.TestCase):
    def test_selection_is_bounded_unique(self):
        rows = [row(i) for i in range(40)]
        for count in (10, 20, 30):
            selected = choose_tracks(rows, count)
            self.assertEqual(len(selected), count)
            validate_manifest({"tracks": selected})
        for count in (0, 9, 31, 559, 20000):
            with self.assertRaises(ValueError):
                choose_tracks(rows, count)

    def test_invalid_manifest(self):
        tracks = [row(i) for i in range(10)]
        tracks[0]["relativePath"] = "../outside.m4a"
        with self.assertRaises(ValueError):
            validate_manifest({"tracks": tracks})
        with self.assertRaises(ValueError):
            validate_manifest({"tracks": [row(0)] * 10})

    def test_production_output_rejected(self):
        for target in (HERE.parent / "cache/analysis.sqlite3", HERE.parent.parent / "music_features.json"):
            with self.assertRaises(ValueError):
                safe_target(target)
        with tempfile.TemporaryDirectory(dir=HERE) as directory:
            link = Path(directory) / "link"
            link.symlink_to(HERE.parent)
            with self.assertRaises(ValueError):
                safe_target(link / "music_features.json")

    def test_direct_mapping_and_omissions(self):
        scores = {group: {} for group in ("tags", "mood", "discogs")}
        for index, (group, label) in enumerate(MAPPING.values()):
            scores[group][label] = index / 10
        result = mapped_features(scores)
        self.assertFalse(set(OMITTED) & result.keys())
        self.assertEqual(result["piano"], scores["tags"]["piano"])
        self.assertEqual(result["dark"], scores["mood"]["dark"])
        scores["tags"]["piano"] = float("nan")
        with self.assertRaises(ValueError):
            mapped_features(scores)

    def test_exact_schema_and_identity(self):
        entry = row(0)["v1"]
        identity = {key: value for key, value in entry.items() if key != "features"}
        result = {**identity, "features": {"piano": .91, "dark": .01, "tempo": 120, "energy": .2}}
        document = make_document(2, [result])
        self.assertEqual(document["schemaVersion"], 1)
        self.assertEqual(document["tracks"][0]["relativePath"], entry["relativePath"])
        self.assertNotIn("bright", document["tracks"][0]["features"])
        document["tracks"][0]["features"]["loudness"] = -20
        with self.assertRaises(ValueError):
            validate_document(document)

    def test_distribution(self):
        d = distribution([0, .5, 1])
        self.assertEqual(d["mean"], .5)
        self.assertAlmostEqual(d["std"], (1 / 6) ** .5)
        self.assertEqual(sum(d["histogram"]), 3)
        self.assertEqual(d["aboveThreshold"], 1)

    def test_frontend_silence_shape_and_reference(self):
        import librosa
        import numpy as np
        y = np.zeros(48000, dtype=np.float32)
        mel = mel_spectrogram(y)
        self.assertEqual(mel.shape, (188, 96))
        self.assertEqual(mel.dtype, np.float32)
        self.assertEqual(float(mel.max()), 0)
        y = (.1 * np.sin(np.arange(48000) * 2 * np.pi * 1000 / 16000)).astype(np.float32)
        mel = mel_spectrogram(y)
        # Independent librosa STFT formulation: same published window/filter parameters.
        spectrum = librosa.stft(y, n_fft=512, hop_length=256,
                               window=np.hanning(512), center=True, pad_mode="constant")
        filters = librosa.filters.mel(sr=16000, n_fft=512, n_mels=96, htk=False, norm="slaney")
        reference = np.log10(1 + 10000 * (filters @ (np.abs(spectrum) ** 2))).T
        np.testing.assert_allclose(mel, reference[:len(mel)], atol=2e-5)

    def test_average_mono_does_not_add_three_db(self):
        import numpy as np
        stereo = np.full((20, 2), .1, dtype=np.float32)
        np.testing.assert_allclose(average_channels(stereo.tobytes(), 2), .1)
        stereo[:, 1] = -.1
        np.testing.assert_allclose(average_channels(stereo.tobytes(), 2), 0)
        with self.assertRaises(ValueError):
            average_channels(b"", 9)

    def test_interrupt_resume_failure_and_reopen(self):
        manifest = {"tracks": [row(i) for i in range(3)]}
        with tempfile.TemporaryDirectory(dir=HERE) as directory, contextlib.redirect_stdout(io.StringIO()):
            target = Path(directory) / "test.sqlite3"
            cache = PocCache(target)
            with patch("run.verify_audio_identity", return_value=Path("/not-opened")), patch.object(run, "Engine") as fake:
                engine = fake.return_value
                engine.analyze.side_effect = [fake_result(), KeyboardInterrupt()]
                counts = run.process_rows(manifest, cache, "test-config", engine, 3)
                self.assertTrue(counts["interrupted"])
                self.assertEqual(counts["success"], 1)
                cache.close()
                cache = PocCache(target)
                self.assertIsNone(cache.success(row(0), "different-model"))
                engine.analyze.side_effect = [ValueError("bad audio"), fake_result()]
                counts = run.process_rows(manifest, cache, "test-config", engine, 3)
                self.assertEqual((counts["skipped"], counts["failed"], counts["success"]), (1, 1, 1))
                engine.analyze.side_effect = [fake_result()]
                counts = run.process_rows(manifest, cache, "test-config", engine, 3)
                self.assertEqual((counts["skipped"], counts["success"]), (2, 1))
                engine.analyze.reset_mock()
                counts = run.process_rows(manifest, cache, "test-config", engine, 3)
                engine.analyze.assert_not_called()
                self.assertEqual(counts["skipped"], 3)
                self.assertEqual(cache.connection.execute("SELECT count(*) FROM results").fetchone()[0], 3)
            cache.close()


if __name__ == "__main__":
    unittest.main()
