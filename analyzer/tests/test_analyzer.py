from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
import unicodedata
from pathlib import Path

from mymusic_analyzer.cache import AnalysisCache
from mymusic_analyzer.discovery import discover_audio_files, relative_path
from mymusic_analyzer.normalization import analyze_loudness, calculate_normalization_gain_db
from mymusic_analyzer.schema import FEATURE_KEYS, TRACK_KEYS, make_document, validate_document


class DiscoveryTests(unittest.TestCase):
    def test_recursively_discovers_only_mymusic_formats(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Artist").mkdir()
            (root / ".hidden").mkdir()
            (root / "Artist" / "song.flac").write_bytes(b"audio")
            (root / "Artist" / "SONG.MP3").write_bytes(b"audio")
            (root / "Artist" / "cover.jpg").write_bytes(b"image")
            (root / ".hidden" / "hidden.wav").write_bytes(b"audio")

            paths = [relative_path(path, root) for path in discover_audio_files(root)]

            self.assertEqual(paths, ["Artist/SONG.MP3", "Artist/song.flac"])

    def test_relative_path_matches_swift_precomposed_posix_representation(self) -> None:
        root = Path("/Music")
        decomposed_name = unicodedata.normalize("NFD", "カフェ")

        result = relative_path(root / decomposed_name / "Album" / "song.flac", root)

        self.assertEqual(result, "カフェ/Album/song.flac")
        self.assertEqual(result, unicodedata.normalize("NFC", result))


class CacheTests(unittest.TestCase):
    def test_cache_reuses_only_matching_file_and_analysis_signature(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            cache = AnalysisCache(Path(directory) / "analysis.sqlite3")
            entry = _entry()
            cache.save_success("/music", "Artist/song.wav", 100, 200, 1, "config", entry)

            self.assertEqual(cache.valid_result("/music", "Artist/song.wav", 100, 200, 1, "config"), entry)
            self.assertIsNone(cache.valid_result("/music", "Artist/song.wav", 101, 200, 1, "config"))
            self.assertIsNone(cache.valid_result("/music", "Artist/song.wav", 100, 200, 2, "config"))

            loudness = {
                "integratedLUFS": -20.8,
                "truePeakDBTP": -2.4,
                "normalizationGainDB": 1.4,
            }
            cache.save_loudness_success("/music", "Artist/song.wav", 100, 200, "loudness-v1", loudness)
            self.assertEqual(
                cache.valid_loudness_result("/music", "Artist/song.wav", 100, 200, "loudness-v1"),
                loudness,
            )
            self.assertIsNone(
                cache.valid_loudness_result("/music", "Artist/song.wav", 100, 201, "loudness-v1")
            )
            cache.close()


class SchemaTests(unittest.TestCase):
    def test_analyzer_fields_follow_repository_schema(self) -> None:
        schema_path = Path(__file__).resolve().parents[2] / "Documentation" / "track-feature-schema-v1.json"
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        self.assertEqual(schema["properties"]["schemaVersion"]["const"], 1)
        self.assertEqual(set(schema["$defs"]["track"]["properties"]), TRACK_KEYS)
        self.assertEqual(set(schema["$defs"]["features"]["properties"]), FEATURE_KEYS)

    def test_output_matches_mymusic_schema_v1(self) -> None:
        document = make_document(1, [_entry()])
        validate_document(document)
        encoded = json.dumps(document, allow_nan=False)
        self.assertEqual(json.loads(encoded)["schemaVersion"], 1)
        self.assertNotIn("additional", document["tracks"][0]["features"])

    def test_rejects_score_outside_zero_to_one(self) -> None:
        entry = _entry()
        entry["features"]["energy"] = 1.1
        with self.assertRaises(ValueError):
            make_document(1, [entry])

    def test_loudness_fields_are_optional_for_backward_compatibility(self) -> None:
        validate_document(make_document(1, [_entry()]))

    def test_loudness_fields_must_be_complete_and_gain_is_bounded(self) -> None:
        entry = _entry()
        entry["features"]["integratedLUFS"] = -20.8
        with self.assertRaises(ValueError):
            make_document(1, [entry])

        entry["features"].update({"truePeakDBTP": -2.4, "normalizationGainDB": 4.1})
        with self.assertRaises(ValueError):
            make_document(1, [entry])


class NormalizationTests(unittest.TestCase):
    def test_conservative_dead_band_and_gain_limits(self) -> None:
        self.assertEqual(calculate_normalization_gain_db(-13.0, -2.0), 0.0)
        self.assertEqual(calculate_normalization_gain_db(-15.0, -2.0), 0.0)
        self.assertEqual(calculate_normalization_gain_db(-21.0, -10.0), 4.0)
        self.assertEqual(calculate_normalization_gain_db(-8.0, -0.5), -4.0)

    def test_true_peak_ceiling_reduces_boost(self) -> None:
        self.assertEqual(calculate_normalization_gain_db(-20.8, -2.4), 1.4)

    def test_ffmpeg_statistics_are_parsed_without_modifying_the_source(self) -> None:
        commands = []

        def runner(command, **kwargs):
            commands.append((command, kwargs))
            stderr = 'log\n{\n "input_i" : "-20.80",\n "input_tp" : "-2.40"\n}\n'
            return subprocess.CompletedProcess(command, 0, stdout="", stderr=stderr)

        result = analyze_loudness(Path("/Music/song.flac"), runner=runner)

        self.assertEqual(result, {
            "integratedLUFS": -20.8,
            "truePeakDBTP": -2.4,
            "normalizationGainDB": 1.4,
        })
        command, kwargs = commands[0]
        self.assertEqual(command[-3:], ("-f", "null", "-"))
        self.assertNotIn("-y", command)
        self.assertTrue(kwargs["capture_output"])


def _entry() -> dict:
    return {
        "relativePath": "Artist/song.wav",
        "fileSize": 100,
        "duration": 10.0,
        "modificationDate": "2026-08-27T00:00:00Z",
        "title": "Song",
        "artist": "Artist",
        "album": "Album",
        "features": {
            "tempo": 120.0,
            "energy": 0.5,
            "piano": 0.5,
            "ambient": 0.5,
            "electronic": 0.5,
            "drumAndBass": 0.5,
            "aggressive": 0.5,
            "calm": 0.5,
            "bright": 0.5,
            "dark": 0.5,
            "vocal": 0.5,
            "instrumental": 0.5,
        },
    }


if __name__ == "__main__":
    unittest.main()
