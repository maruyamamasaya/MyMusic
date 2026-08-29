import json
import unittest
from unittest.mock import patch

import benchmark
from benchmark import HERE, resolve_unique
from heads import MAPPING, remap


class HumanEvaluationTests(unittest.TestCase):
    def test_identity_is_exact_and_ambiguity_fails_closed(self):
        track = dict(artist="Artist", title="Song (Live 2024)", relativePath="A/Song.m4a")
        other = dict(artist="Artist", title="Song (Live 2023)", relativePath="B/Song.m4a")
        self.assertEqual(resolve_unique([track, other], "Artist", "Song (Live 2024)"), track)
        with self.assertRaises(ValueError):
            resolve_unique([track, {**track, "relativePath": "copy/Song.m4a"}], "Artist", "Song (Live 2024)")
        with self.assertRaises(ValueError):
            resolve_unique([track, other], "Artist", "Song")

    def test_mapping_is_direct_and_preserves_unrelated_scores(self):
        original = dict(vocal=.02, calm=.01, piano=.4, ambient=.3, energy=.7,
                        electronic=.5, drumAndBass=.1, dark=.05, tempo=120)
        predictions = {"voice_instrumental": {"voice": .9, "instrumental": .1},
                       "mood_aggressive": {"aggressive": .8, "not_aggressive": .2},
                       "mood_relaxed": {"relaxed": .7, "non_relaxed": .3}}
        updated = remap(original, predictions)
        for key in original.keys() - MAPPING.keys():
            self.assertEqual(updated[key], original[key])
        self.assertEqual(updated["vocal"], .9)
        self.assertEqual(updated["instrumental"], .1)
        self.assertEqual(updated["aggressive"], .8)
        self.assertEqual(updated["calm"], .7)  # Not 1 - aggressive.
        self.assertNotIn("bright", updated)
        self.assertEqual(original["vocal"], .02)  # Before snapshot remains unchanged.
        predictions["voice_instrumental"]["voice"] = float("nan")
        with self.assertRaises(ValueError):
            remap(original, predictions)

    def test_saved_head_stage_cannot_read_audio_or_use_backbone(self):
        if not (HERE / "output/after.json").exists():
            self.skipTest("No local evaluation artifacts")
        from heads import refine
        selection = benchmark.selection()
        records = benchmark.load_records(selection)
        with patch("benchmark.Engine.analyze", side_effect=AssertionError("audio forbidden")), \
             patch("heads.HeadBank", side_effect=AssertionError("cached heads should skip")):
            refine(selection, records)
        result = json.loads((HERE / "output/after.json").read_text())
        self.assertEqual(result["run"]["skipped"], len(records))
        self.assertEqual(result["run"]["audioReads"], 0)

    def test_saved_export_identity_and_protected_files(self):
        if not (HERE / "output/after.json").exists():
            self.skipTest("No local evaluation artifacts")
        from mymusic_analyzer.schema import validate_document
        selection = benchmark.selection()
        self.assertEqual(selection["sourceHashes"], benchmark.hashes())
        doc = json.loads((HERE / "output/music_features_human_eval.json").read_text())
        validate_document(doc)
        self.assertEqual(len(doc["tracks"]), len(selection["tracks"]))
        by_path = {row["relativePath"]: row["v1"] for row in selection["tracks"]}
        for row in doc["tracks"]:
            self.assertEqual({k:v for k,v in row.items() if k != "features"},
                             {k:v for k,v in by_path[row["relativePath"]].items() if k != "features"})


if __name__ == "__main__":
    unittest.main()
