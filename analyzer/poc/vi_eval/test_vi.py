import contextlib
import copy
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import evaluate as ev
from frontend_candidate import corrected_mel, unchanged_patch_layout
from engine import mel_spectrogram
from report_vi import decision, score_count


class EvaluationTests(unittest.TestCase):
    def test_exact_identity_no_cover_substitution(self):
        rows=[dict(artist='A',title='Song',relativePath='A/Song'),
              dict(artist='B',title='Song',relativePath='B/Song')]
        self.assertEqual(len(ev.resolve_candidates(rows,dict(artist='A',title='Song'))),1)
        self.assertEqual(ev.resolve_candidates(rows,dict(artist='C',title='Song')),[])
        self.assertEqual(len(ev.resolve_candidates(rows+rows[:1],dict(artist='A',title='Song'))),2)

    def test_explicit_collaboration_metadata(self):
        row=dict(artist='natsumi',title='イージーゲーム',album='和ぬか',relativePath='n/feat. 和ぬか_natsumi.m4a')
        spec=dict(artist='natsumi',title='イージーゲーム',requiredAlbum='和ぬか',requiredPathText='feat. 和ぬか_natsumi')
        self.assertEqual(ev.resolve_candidates([row],spec),[row])
        self.assertEqual(ev.resolve_candidates([{**row,'album':'Other'}],spec),[])

    def test_target_rejects_parent_and_links(self):
        with self.assertRaises(ValueError):
            ev.target('../human_eval/output/after.json')
        with tempfile.TemporaryDirectory(dir=ev.HERE) as directory:
            link=Path(directory)/'link'
            link.symlink_to(ev.POC)
            with self.assertRaises(ValueError):
                ev.target(link/'output/file.json')

    def test_aggregation_preserves_sparse_voice_not_max(self):
        raw={'voice_instrumental':{'voice':[.1,.1,.9],'instrumental':[.9,.9,.1]}}
        segments=[dict(offset=i*30,patchStart=i,patchEnd=i+1) for i in range(3)]
        result=ev.summarize(raw,segments)
        self.assertAlmostEqual(result['aggregation']['mean'],1.1/3)
        self.assertEqual(result['aggregation']['median'],.1)
        self.assertEqual(result['aggregation']['max'],.9)
        self.assertEqual(result['aggregation']['voicePatchRatio'],1/3)
        self.assertEqual(decision(result['aggregation']['mean']),'instrumental')
        self.assertEqual(decision(.5),'tie')

    def test_hard_case_stays_in_instrumental_denominator(self):
        rows=[dict(identity=dict(evaluation=dict(truth='instrumental',hardCase=hard)),
                   baseline=dict(aggregation=dict(mean=v))) for hard,v in [(False,.1),(True,.8)]]
        self.assertEqual(score_count(rows,'instrumental'),dict(correct=1,total=2))
        self.assertEqual(score_count(rows,'instrumental',exclude_hard=True),dict(correct=1,total=1))

    def test_terminal_correction_keeps_prefix_and_changes_boundary_only(self):
        import numpy as np
        y=np.random.default_rng(1).normal(0,.05,48384).astype(np.float32)
        before,after=mel_spectrogram(y),corrected_mel(y)
        np.testing.assert_array_equal(before,after[:-1])
        self.assertEqual((len(before),len(after)),(189,190))
        self.assertFalse(unchanged_patch_layout(len(y)))
        self.assertTrue(unchanged_patch_layout(480000))

    def test_interrupt_resume_preserves_success(self):
        import numpy as np
        rows=[dict(root='/synthetic',relativePath=f'{i}.m4a',fileSize=1,mtimeNS=1,
                   v1=dict(title=str(i),artist='Synthetic',duration=90)) for i in range(2)]
        output=dict(features=dict(energy=.5),segments=[dict(offset=0,patchStart=0,patchEnd=1)])
        raw={'voice_instrumental':{'voice':[.9],'instrumental':[.1]},
             'mood_aggressive':{'aggressive':[.2],'not_aggressive':[.8]},
             'mood_relaxed':{'relaxed':[.6],'non_relaxed':[.4]}}
        model=SimpleNamespace()
        calls=[]
        def analyze(*_):
            calls.append(1)
            if len(calls)==2:
                raise KeyboardInterrupt()
            model.last_embeddings=np.zeros((1,1280),dtype=np.float32)
            return copy.deepcopy(output)
        model.analyze=analyze
        with tempfile.TemporaryDirectory(dir=ev.HERE) as directory, contextlib.redirect_stdout(io.StringIO()), \
             patch.object(ev,'HERE',Path(directory)), patch.object(ev,'model_manifest',return_value={}), \
             patch.object(ev,'config_key',return_value='test'), patch.object(ev,'head_manifest',return_value={}), \
             patch.object(ev,'verify_audio_identity',return_value=Path('/not-opened')), \
             patch.object(ev,'TraceEngine',return_value=model), \
             patch.object(ev,'PatchHeads',return_value=SimpleNamespace(predict_patches=lambda _:raw)):
            self.assertEqual(ev.baseline({'tracks':rows},2),130)
            self.assertEqual(ev.baseline({'tracks':rows},2),0)
            self.assertEqual(ev.baseline({'tracks':rows},2),0)
            self.assertEqual(len(calls),3)
            runs=json.loads((Path(directory)/'data/runs.json').read_text())
            self.assertEqual(runs[-1]['skipped'],2)
            self.assertEqual(runs[-1]['audioTracks'],0)

    def test_frozen_results_reuse_and_protection(self):
        if not ev.target('output/comparison.json').exists():
            self.skipTest('No local evaluation artifacts')
        selection=ev.selection()
        self.assertEqual(ev.protected_hashes(),selection['protectedHashes'])
        with patch.object(ev,'TraceEngine',side_effect=AssertionError('No audio/backbone allowed')), \
             patch.object(ev,'PatchHeads',side_effect=AssertionError('Cached baseline should skip')), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(ev.baseline(selection,16),0)
        comparison=json.loads(ev.target('output/comparison.json').read_text())
        regression=json.loads(ev.target('output/regression.json').read_text())
        self.assertEqual((len(comparison['tracks']),comparison['audioReads'],comparison['maxFeatureDelta']),(15,0,0))
        self.assertEqual((len(regression['tracks']),regression['audioReads'],regression['maxFeatureDelta']),(11,0,0))


if __name__=='__main__':
    unittest.main()
