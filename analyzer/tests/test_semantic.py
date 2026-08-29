from __future__ import annotations

import contextlib
import io
import json
from pathlib import Path
import sqlite3
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from mymusic_analyzer.metadata import TrackMetadata,_rfc3339
from mymusic_analyzer.discovery import relative_path
from mymusic_analyzer.schema import make_document,validate_document
from mymusic_semantic import cli,models
from mymusic_semantic.cache import SemanticCache
from mymusic_semantic.safety import CACHE_HOME,CACHE_SETS_HOME,locked_cache,safe_path,digest
from mymusic_semantic.scope import (dynamic_cache_name,prepare_dynamic_scope,prepare_scope,
                                    refresh_scope,scan_scope)


class FakeBackbone:
    def __init__(self):
        self.audio_reads=0
        self.decode_calls=0

    def extract(self,path,duration):
        import numpy as np
        self.audio_reads+=1
        self.decode_calls+=3
        arrays=dict(embeddings=np.full((87,1280),.125,dtype=np.float32),
                    discogs_mean=np.full(400,.01),segment_offsets=np.asarray([0.,35.,70.]),
                    segment_patch_counts=np.asarray([29,29,29],dtype=np.int32))
        return arrays,dict(patches=87,timing=dict(total=.01))


class FakeHeads:
    def predict(self,arrays,dsp):
        features=dict(vocal=.9,instrumental=.1,aggressive=.3,calm=.6,piano=.2,electronic=.1,
                      ambient=.1,drumAndBass=.01)
        features.update({key:dsp[key] for key in ('energy','tempo') if key in dsp})
        return features,{'synthetic':.9}


class SemanticTests(unittest.TestCase):
    def setUp(self):
        CACHE_HOME.mkdir(parents=True,exist_ok=True)
        self.tmp=tempfile.TemporaryDirectory(dir=CACHE_HOME)
        self.parent=Path(self.tmp.name)
        self.root=self.parent/'music'
        self.root.mkdir()
        self.directory=self.parent/'cache'
        self.source=self.parent/'source.json'
        self.tracks=[]
        for i in range(3):
            path=self.root/f'track{i}.m4a'
            path.write_bytes(b'synthetic fixture, not decoded')
            stat=path.stat()
            self.tracks.append(dict(relativePath=path.name,fileSize=stat.st_size,duration=120.,
                modificationDate=_rfc3339(stat.st_mtime),title=f'Track {i}',artist='Test',album='Test',
                features=dict(energy=.42,tempo=123.)))
        self.source.write_text(json.dumps(make_document(1,self.tracks)))
        self.lock=locked_cache(self.directory,create=True)
        self.lock.__enter__()
        cli.runtime(self.directory)
        self.scope=prepare_scope(self.directory,self.root,self.source,3)
        self.cache=SemanticCache(self.directory)
        self.cache.register_scope(self.scope)
        self.no_reuse=lambda:SimpleNamespace(get=lambda *_:None)

    def tearDown(self):
        self.cache.close()
        self.lock.__exit__(None,None,None)
        self.tmp.cleanup()

    def embed(self,limit=None,factory=FakeBackbone):
        with contextlib.redirect_stdout(io.StringIO()):
            return cli.embed(self.cache,self.scope,limit,factory,self.no_reuse)

    def test_cache_and_output_escape_rejected(self):
        for target in (CACHE_HOME.parent/'cache',CACHE_HOME.parent/'poc',CACHE_HOME.parent.parent):
            with self.assertRaises(ValueError):
                with locked_cache(target,create=True): pass
        link=self.directory/'link';link.symlink_to(self.root)
        with self.assertRaises(ValueError): safe_path(link/'bad.json',self.directory)
        original=self.directory/'original';original.write_text('keep')
        hard=self.directory/'hard';hard.hardlink_to(original)
        with self.assertRaises(ValueError):safe_path(hard,self.directory)
        with self.assertRaises(ValueError):safe_path(CACHE_HOME.parent.parent/'music_features.json',self.directory/'output')

    def test_concurrent_writer_rejected(self):
        with self.assertRaises(ValueError):
                with locked_cache(self.directory): pass

    def test_existing_frozen_sqlite_migrates_without_losing_rows(self):
        legacy=self.parent/'legacy-cache'
        with locked_cache(legacy,create=True):
            connection=sqlite3.connect(legacy/'index.sqlite3')
            connection.execute('''CREATE TABLE tracks (
              relative_path TEXT PRIMARY KEY, identity_json TEXT NOT NULL,
              mtime_ns INTEGER, embed_profile TEXT, state TEXT NOT NULL DEFAULT 'pending',
              npz_path TEXT, npz_sha256 TEXT, error TEXT, detail_json TEXT)''')
            connection.execute("INSERT INTO tracks(relative_path,identity_json,state) VALUES ('old.m4a','{}','pending')")
            connection.commit();connection.close()
            migrated=SemanticCache(legacy)
            try:
                columns={row['name'] for row in migrated.db.execute('PRAGMA table_info(tracks)')}
                self.assertTrue({'present','source_features_json'}.issubset(columns))
                self.assertEqual(migrated.get('old.m4a')['present'],1)
            finally:
                migrated.close()

    def test_reconciliation_handles_twenty_thousand_tracks_in_linear_batches(self):
        timestamp='2026-08-29T00:00:00Z'
        tracks=[dict(relativePath=f'Artist {index//10}/track{index}.m4a',fileSize=100+index,
                     duration=120.,modificationDate=timestamp,title=f'Track {index}',
                     artist='Scale',album='Scale',features={'energy':.5}) for index in range(20_000)]
        scope=dict(root=str(self.root),mode='dynamic',tracks=tracks)
        mtimes={track['relativePath']:1_000_000+index for index,track in enumerate(tracks)}
        scale_directory=self.parent/'scale-cache'
        with locked_cache(scale_directory,create=True):
            scale=SemanticCache(scale_directory)
            try:
                first=scale.reconcile_scope(scope,mtimes)
                second=scale.reconcile_scope(scope,mtimes)
            finally:
                scale.close()
        self.assertEqual((first['inserted'],first['updated'],first['deleted']),(20_000,0,0))
        self.assertEqual((second['unchanged'],second['deleted']),(20_000,0))

    def test_scope_frozen_count_and_no_implicit_expansion(self):
        with self.assertRaises(ValueError):prepare_scope(self.directory,None,None,4)
        self.source.write_text(json.dumps(make_document(1,self.tracks[:2])))
        with self.assertRaises(ValueError):prepare_scope(self.directory,None,None,3)
        self.assertEqual(len(self.scope['tracks']),3)

    def test_dynamic_root_uses_independent_resumable_cache_and_output(self):
        live_directory=self.parent/'live-cache'
        before={path.relative_to(self.directory):digest(path)
                for path in self.directory.rglob('*') if path.is_file()}
        metadata={track['relativePath']:track for track in self.tracks}
        def reader(path,_root):
            row=metadata[path.name]
            return SimpleNamespace(identity_fields=lambda:{k:v for k,v in row.items() if k!='features'})
        with locked_cache(live_directory,create=True) as directory:
            scope=prepare_dynamic_scope(directory,self.root)
            self.assertEqual(scope['tracks'],[])
            cache=SemanticCache(directory)
            try:
                output=directory/'output/music_features_semantic_v2.json'
                with contextlib.redirect_stdout(io.StringIO()):
                    result,scope=cli.update(cache,scope,directory,output,FakeBackbone,self.no_reuse,
                                            FakeHeads,reader)
                self.assertEqual((result['exported'],result['embed']['success']),(3,3))
                self.assertEqual(len(json.loads(output.read_text())['tracks']),3)
                with contextlib.redirect_stdout(io.StringIO()):
                    repeated,_=cli.update(
                        cache,scope,directory,output,
                        lambda:(_ for _ in ()).throw(AssertionError('must resume')),
                        self.no_reuse,
                        lambda:(_ for _ in ()).throw(AssertionError('heads must resume')),
                        reader,
                    )
                self.assertEqual((repeated['embed']['skipped'],repeated['exported']),(3,3))
            finally:
                cache.close()
        after={path.relative_to(self.directory):digest(path)
               for path in self.directory.rglob('*') if path.is_file()}
        self.assertEqual(before,after)
        self.assertEqual(dynamic_cache_name(self.root),dynamic_cache_name(self.root))
        self.assertTrue((CACHE_SETS_HOME/dynamic_cache_name(self.root)).is_relative_to(CACHE_SETS_HOME))

    def test_scan_ignores_outside_scope_and_detects_unicode_collisions(self):
        (self.root/'extra.m4a').write_bytes(b'never analyze')
        paths,report=scan_scope(self.scope)
        self.assertEqual(len(paths),3)
        self.assertEqual(report['outsideScope'],1)
        p1=self.root/'é.m4a';p2=self.root/'e\u0301.m4a'
        with patch('mymusic_semantic.scope.discover_audio_files',return_value=[p1,p2]):
            paths,report=scan_scope(dict(root=str(self.root),tracks=[dict(relativePath='é.m4a')]))
            self.assertEqual(paths,{})
            self.assertEqual(report['ambiguous'],['é.m4a'])

    def test_limit_repeat_skips_same_tracks_not_next_batch(self):
        first=self.embed(2)
        self.assertEqual((first['success'],first['audioReads']),(2,2))
        with patch('mymusic_semantic.models.Backbone',side_effect=AssertionError('must skip')):
            again=self.embed(2,factory=lambda:(_ for _ in ()).throw(AssertionError('must skip')))
        self.assertEqual((again['skipped'],again['audioReads']),(2,0))
        full=self.embed()
        self.assertEqual((full['skipped'],full['success']),(2,1))

    def test_failure_continues_and_only_failed_track_retries(self):
        backend=FakeBackbone();extract=backend.extract
        def failing(path,duration):
            if path.name=='track0.m4a':raise ValueError('bad synthetic audio')
            return extract(path,duration)
        backend.extract=failing
        first=self.embed(factory=lambda:backend)
        self.assertEqual((first['failed'],first['success']),(1,2))
        retry=self.embed()
        self.assertEqual((retry['success'],retry['skipped']),(1,2))

    def test_interrupt_after_npz_recovers_without_audio(self):
        with patch.object(self.cache,'ready',side_effect=KeyboardInterrupt()):
            first=self.embed(1)
        self.assertTrue(first['interrupted'])
        second=self.embed(1,factory=lambda:(_ for _ in ()).throw(AssertionError('no decode')))
        self.assertEqual((second['recovered'],second['audioReads']),(1,0))

    def test_update_command_resumes_after_interrupt_and_exports_when_complete(self):
        output=self.directory/'output/music_features_semantic_v2.json'
        with patch.object(self.cache,'ready',side_effect=KeyboardInterrupt()), \
             contextlib.redirect_stdout(io.StringIO()):
            interrupted,scope=cli.update(
                self.cache,self.scope,self.directory,output,FakeBackbone,self.no_reuse,FakeHeads)
        self.assertTrue(interrupted['interrupted'])
        self.assertFalse(output.exists())
        with contextlib.redirect_stdout(io.StringIO()):
            resumed,_=cli.update(
                self.cache,scope,self.directory,output,FakeBackbone,self.no_reuse,FakeHeads)
        self.assertEqual((resumed['embed']['recovered'],resumed['embed']['success'],
                          resumed['embed']['audioReads'],resumed['exported']),(1,2,2,3))
        validate_document(json.loads(output.read_text()))

        previous_output=output.read_bytes()
        spec=models.heads_spec();spec['revision']='interrupt-head-profile'
        class InterruptHeads:
            def predict(self,_arrays,_dsp): raise KeyboardInterrupt()
        with patch('mymusic_semantic.models.heads_spec',return_value=spec), \
             contextlib.redirect_stdout(io.StringIO()):
            interrupted,scope=cli.update(
                self.cache,scope,self.directory,output,
                lambda:(_ for _ in ()).throw(AssertionError('embeddings must skip')),
                self.no_reuse,InterruptHeads)
        self.assertTrue(interrupted['interrupted'])
        self.assertEqual(output.read_bytes(),previous_output)
        with patch('mymusic_semantic.models.heads_spec',return_value=spec), \
             contextlib.redirect_stdout(io.StringIO()):
            resumed,_=cli.update(
                self.cache,scope,self.directory,output,
                lambda:(_ for _ in ()).throw(AssertionError('embeddings must skip')),
                self.no_reuse,FakeHeads)
        self.assertEqual((resumed['embed']['audioReads'],resumed['heads']['success'],resumed['exported']),(0,3,3))

    def test_compatible_seed_is_copied_without_backbone(self):
        arrays,detail=FakeBackbone().extract(None,120)
        with contextlib.redirect_stdout(io.StringIO()):
            result=cli.embed(self.cache,self.scope,1,
                backend_factory=lambda:(_ for _ in ()).throw(AssertionError('seed must avoid audio')),
                reuse_factory=lambda:SimpleNamespace(get=lambda *_:(arrays,detail)))
        self.assertEqual((result['reusedPoC'],result['audioReads']),(1,0))
        row=self.cache.get('track0.m4a')
        self.assertEqual(row['state'],'ready')
        _,saved=self.cache.load_embedding(self.directory/row['npz_path'],row['npz_sha256'])
        self.assertEqual(saved['embeddings'].shape,(87,1280))

    def test_changed_source_and_corrupt_npz_never_silently_overwrite(self):
        self.embed(2)
        row=self.cache.get('track0.m4a');path=self.directory/row['npz_path']
        path.write_bytes(b'corrupt')
        changed=self.root/'track1.m4a';changed.write_bytes(b'different size')
        again=self.embed(2,factory=lambda:(_ for _ in ()).throw(AssertionError('no decode')))
        self.assertEqual((again['failed'],again['audioReads']),(2,0))
        self.assertEqual(path.read_bytes(),b'corrupt')

    def test_heads_offline_no_audio_paths_and_schema(self):
        self.embed()
        # Remove source availability to prove heads uses only the cache snapshot.
        self.root.rename(self.parent/'offline')
        self.source.unlink()
        before={r['relative_path']:r['npz_sha256'] for r in self.cache.embedded_rows()}
        with patch('mymusic_semantic.cli.scan_scope',side_effect=AssertionError('no scan')), \
             patch('mymusic_semantic.cli.verify_source',side_effect=AssertionError('no audio stat')), \
             patch('mymusic_semantic.models.Backbone',side_effect=AssertionError('no backbone')), \
             patch('subprocess.run',side_effect=AssertionError('no ffmpeg/ffprobe')), \
             contextlib.redirect_stdout(io.StringIO()):
            result,profile=cli.heads(self.cache,self.scope,None,runner_factory=FakeHeads)
            self.assertEqual((result['success'],result['audioReads']),(3,0))
            result,_=cli.heads(self.cache,self.scope,None,runner_factory=lambda:(_ for _ in ()).throw(AssertionError('skip')))
            self.assertEqual(result['skipped'],3)
            result,_=cli.heads(self.cache,self.scope,None,True,FakeHeads)
            self.assertEqual((result['success'],result['audioReads']),(3,0))
        doc=make_document(2,self.cache.export_rows(profile));validate_document(doc)
        self.assertEqual(len(doc['tracks']),3)
        self.assertEqual(doc['tracks'][0]['features']['energy'],.42)
        for row in doc['tracks']:
            source=next(t for t in self.tracks if t['relativePath']==row['relativePath'])
            self.assertEqual({k:v for k,v in row.items() if k!='features'},
                             {k:v for k,v in source.items() if k!='features'})
        self.assertEqual(before,{r['relative_path']:digest(self.directory/r['npz_path']) for r in self.cache.embedded_rows()})

    def test_new_head_profile_does_not_invalidate_embeddings(self):
        self.embed(1)
        with contextlib.redirect_stdout(io.StringIO()):
            _,old=cli.heads(self.cache,self.scope,1,runner_factory=FakeHeads)
            spec=models.heads_spec();spec['revision']='synthetic-new-head'
            with patch('mymusic_semantic.models.heads_spec',return_value=spec):
                result,new=cli.heads(self.cache,self.scope,1,runner_factory=FakeHeads)
        self.assertNotEqual(old,new)
        self.assertEqual((result['success'],result['audioReads']),(1,0))
        self.assertEqual(len(self.cache.export_rows(old)),1)
        self.assertEqual(len(self.cache.export_rows(new)),1)
        self.assertEqual(len(list(self.cache.embedded_rows())),1)

    def test_live_update_detects_new_track_and_new_nested_folder_then_all_skip(self):
        initial=self.embed()
        self.assertEqual(initial['success'],3)
        new_file=self.root/'new.m4a';new_file.write_bytes(b'new synthetic audio')
        nested=self.root/'New Artist'/'New Album'/'nested.flac'
        nested.parent.mkdir(parents=True);nested.write_bytes(b'nested synthetic audio')
        metadata_reads=[]

        def metadata(path,root):
            metadata_reads.append(relative_path(path,root))
            stat=path.stat()
            return TrackMetadata(relative_path(path,root),stat.st_size,_rfc3339(stat.st_mtime),
                                 stat.st_mtime_ns,180.,path.stem,'New Artist',path.parent.name)

        output=self.directory/'output/music_features_semantic_v2.json'
        with contextlib.redirect_stdout(io.StringIO()):
            result,refreshed=cli.update(
                self.cache,self.scope,self.directory,output,FakeBackbone,self.no_reuse,FakeHeads,metadata)
        scan=result['scan'];reconciliation=result['reconciliation'];embedded=result['embed']
        self.assertEqual((scan['new'],scan['updated'],scan['deleted']),(2,0,0))
        self.assertEqual(set(metadata_reads),{'new.m4a','New Artist/New Album/nested.flac'})
        self.assertEqual((reconciliation['inserted'],reconciliation['unchanged']),(2,3))
        self.assertEqual((embedded['success'],embedded['skipped'],embedded['audioReads']),(2,3,2))
        classified=result['heads'];profile=result['headProfile']
        self.assertEqual((classified['success'],classified['audioReads']),(5,0))
        self.assertEqual(result['exported'],5)
        validate_document(json.loads(output.read_text()))
        self.assertEqual(len(self.cache.export_rows(profile)),5)
        new_rows=[row for row in self.cache.export_rows(profile) if row['relativePath'] in metadata_reads]
        self.assertTrue(all('energy' not in row['features'] and 'tempo' not in row['features'] for row in new_rows))

        metadata_reads.clear()
        with contextlib.redirect_stdout(io.StringIO()):
            result,again=cli.update(self.cache,refreshed,self.directory,output,
                lambda:(_ for _ in ()).throw(AssertionError('all tracks must skip')),
                self.no_reuse,lambda:(_ for _ in ()).throw(AssertionError('all heads must skip')),metadata)
        embedded=result['embed'];scan=result['scan']
        self.assertEqual((embedded['skipped'],embedded['audioReads'],scan['unchanged']),(5,0,5))
        self.assertEqual((result['heads']['skipped'],result['audioReads']),(5,0))
        self.assertEqual(metadata_reads,[])

        with patch('mymusic_semantic.cli.scan_scope',side_effect=AssertionError('no scan')), \
             patch('mymusic_semantic.cli.verify_source',side_effect=AssertionError('no stat')), \
             patch('mymusic_semantic.models.Backbone',side_effect=AssertionError('no audio')), \
             patch('subprocess.run',side_effect=AssertionError('no subprocess')), \
             contextlib.redirect_stdout(io.StringIO()):
            classified,_=cli.heads(self.cache,again,None,True,FakeHeads)
        self.assertEqual((classified['success'],classified['audioReads']),(5,0))

    def test_updated_track_reembeds_and_deleted_track_is_safely_excluded(self):
        self.embed()
        before=self.cache.get('track0.m4a')['npz_sha256']
        changed=self.root/'track0.m4a'
        changed.write_bytes(b'updated synthetic audio with a different size')

        def metadata(path,root):
            stat=path.stat()
            return TrackMetadata(relative_path(path,root),stat.st_size,_rfc3339(stat.st_mtime),
                                 stat.st_mtime_ns,181.,'Updated','Test','Test')

        refreshed,paths,mtimes,scan=refresh_scope(
            self.directory,self.scope,self.cache.track_records(),metadata_reader=metadata)
        reconciliation=self.cache.reconcile_scope(refreshed,mtimes)
        self.assertEqual((scan['updated'],reconciliation['updated']),(1,1))
        with contextlib.redirect_stdout(io.StringIO()):
            result=cli.embed(self.cache,refreshed,None,FakeBackbone,self.no_reuse,(paths,scan))
        self.assertEqual((result['success'],result['skipped'],result['audioReads']),(1,2,1))
        self.assertNotEqual(before,self.cache.get('track0.m4a')['npz_sha256'])

        (self.root/'track1.m4a').unlink()
        refreshed,paths,mtimes,scan=refresh_scope(
            self.directory,refreshed,self.cache.track_records(),metadata_reader=metadata)
        reconciliation=self.cache.reconcile_scope(refreshed,mtimes)
        self.assertEqual((scan['deleted'],reconciliation['deleted']),(1,1))
        self.assertEqual(self.cache.get('track1.m4a')['present'],0)
        repeated,_,mtimes,repeated_scan=refresh_scope(
            self.directory,refreshed,self.cache.track_records(),metadata_reader=metadata)
        repeated_reconciliation=self.cache.reconcile_scope(repeated,mtimes)
        self.assertEqual((repeated_scan['deleted'],repeated_reconciliation['deleted']),(0,0))
        with contextlib.redirect_stdout(io.StringIO()):
            _,profile=cli.heads(self.cache,repeated,None,runner_factory=FakeHeads)
        self.assertNotIn('track1.m4a',{row['relativePath'] for row in self.cache.export_rows(profile)})


if __name__=='__main__':
    unittest.main()
