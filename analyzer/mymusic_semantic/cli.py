from __future__ import annotations

import argparse
from datetime import datetime,timezone
import json
import os
from pathlib import Path
import signal
import sys
import time

from .safety import ANALYZER,CACHE_HOME,CACHE_SETS_HOME,atomic_json,digest,fingerprint,locked_cache,safe_path
from .scope import (dynamic_cache_name,prepare_dynamic_scope,prepare_scope,load_scope,
                    refresh_scope,scan_scope,verify_source)
from .cache import SemanticCache
from mymusic_analyzer.schema import make_document


def runtime(cache):
    for name,suffix in (('NUMBA_CACHE_DIR','numba'),('MPLCONFIGDIR','matplotlib'),('XDG_CACHE_HOME','cache')):
        os.environ[name]=str(safe_path(cache/'.runtime'/suffix,cache))
    os.environ['ORT_DISABLE_TELEMETRY']='1'
    os.environ['OMP_NUM_THREADS']='2'
    os.environ['OPENBLAS_NUM_THREADS']='2'


def targets(scope,limit):
    # A fixed prefix makes repeating --limit 5 safe: it never advances to another five.
    return scope['tracks'] if limit is None else scope['tracks'][:limit]


def summary(stage,total):
    return dict(stage=stage,total=total,attempted=0,success=0,skipped=0,recovered=0,reusedPoC=0,
                failed=0,audioReads=0,decodeCalls=0,interrupted=False)


def embed(cache,scope,limit,backend_factory=None,reuse_factory=None,scan_result=None):
    from .models import Backbone,embedding_spec
    spec=embedding_spec();profile=fingerprint(spec)
    spec_file=safe_path(cache.directory/'embedding-profile.json',cache.directory)
    if spec_file.exists() and json.loads(spec_file.read_text())!=spec:
        raise ValueError('Backbone/frontend profile changed; use a new cache, not an overwrite')
    if not spec_file.exists():
        atomic_json(spec_file,spec,cache.directory)
    rows=targets(scope,limit);result=summary('embed',len(rows))
    backend=None
    seeds=None
    paths,scan=scan_result or scan_scope(scope)
    result['scan']=scan
    print(f"Scan: {scan['discovered']:,} files; scope={len(scope['tracks']):,}; selected={len(rows):,}",flush=True)
    try:
        for index,track in enumerate(rows,1):
            relative=track['relativePath'];existing=cache.get(relative)
            identity={k:v for k,v in track.items() if k!='features'}
            try:
                ns=verify_source(paths.get(relative),scope['root'],identity,existing['mtime_ns'])
                path=cache.embedding_path(scope['root'],identity,ns,profile)
                if existing['state']=='ready':
                    if existing['embed_profile']!=profile or existing['npz_path']!=str(path.relative_to(cache.directory)):
                        raise ValueError('Embedding profile/identity mismatch')
                    cache.load_embedding(path,existing['npz_sha256'])
                    result['skipped']+=1
                    print(f'[{index}/{len(rows)}] Skip {relative}',flush=True)
                    continue
                expected=dict(format=1,root=scope['root'],identity=identity,mtimeNS=ns,embeddingProfile=profile)
                # Recover a fully written NPZ if interruption occurred before SQLite commit.
                if path.exists():
                    metadata,arrays=cache.load_embedding(path)
                    if any(metadata.get(k)!=v for k,v in expected.items()):
                        raise ValueError('Orphan embedding metadata mismatch; refusing overwrite')
                    cache.ready(identity,ns,profile,path,metadata['detail'])
                    del arrays
                    result['recovered']+=1
                    continue
                if seeds is None:
                    from .reuse import PoCSeeds
                    seeds=(reuse_factory or PoCSeeds)()
                reused=seeds.get(scope['root'],identity,ns)
                if reused is not None:
                    arrays,detail=reused
                    cache.write_embedding(path,{**expected,'detail':detail},arrays)
                    del arrays
                    cache.ready(identity,ns,profile,path,detail)
                    result['reusedPoC']+=1
                    print(f'[{index}/{len(rows)}] Reuse PoC embedding {relative}',flush=True)
                    continue
                result['attempted']+=1
                print(f'[{index}/{len(rows)}] Embed {relative}',flush=True)
                backend=backend or (backend_factory or Backbone)()
                arrays,detail=backend.extract(paths[relative],identity['duration'])
                verify_source(paths[relative],scope['root'],identity,ns)
                cache.write_embedding(path,{**expected,'detail':detail},arrays)
                del arrays
                cache.ready(identity,ns,profile,path,detail)
                result['success']+=1
                print(f"  Saved {detail['patches']} × 1280, {detail['timing']['total']:.2f}s",flush=True)
            except Exception as error:
                cache.fail_embedding(relative,error)
                result['failed']+=1
                print(f'  ERROR {relative}: {error}',flush=True)
    except KeyboardInterrupt:
        result['interrupted']=True
        print('Interrupted; committed tracks/NPZs are preserved. Resume with the same command.',flush=True)
    if backend:
        result.update(audioReads=backend.audio_reads,decodeCalls=backend.decode_calls)
    return result


def heads(cache,scope,limit,force=False,runner_factory=None):
    from .models import HeadRunner,heads_spec
    spec=heads_spec();profile=fingerprint(spec)
    cached_spec=json.loads(safe_path(cache.directory/'embedding-profile.json',cache.directory).read_text())
    if cached_spec['backbone']['discogs.onnx']!=spec['expectedBackbone'] or cached_spec['dimension']!=1280:
        raise ValueError('Saved embedding backbone is incompatible with the selected heads')
    atomic_json(safe_path(cache.directory/'head-profiles'/f'{profile}.json',cache.directory),spec,cache.directory)
    rows=targets(scope,limit);allowed={t['relativePath']:t for t in rows}
    result=summary('heads',len(rows));result['headProfile']=profile
    result['notEmbedded']=0
    runner=None
    # No scan, audio stat, metadata reader, decoder, or backbone in this stage.
    try:
        for index,track in enumerate(rows,1):
            relative=track['relativePath'];row=cache.get(relative)
            if row['state']!='ready':
                result['notEmbedded']+=1
                continue
            try:
                path=safe_path(cache.directory/row['npz_path'],cache.directory)
                metadata,arrays=cache.load_embedding(path,row['npz_sha256'])
                if (metadata['identity']!=json.loads(row['identity_json'])
                        or metadata['embeddingProfile']!=row['embed_profile']):
                    raise ValueError('Embedding does not match cached identity/profile')
                saved=cache.head_result(relative,profile)
                if (not force and saved and saved['state']=='ready' and saved['embedding_sha']==row['npz_sha256']):
                    result['skipped']+=1
                    del arrays
                    continue
                result['attempted']+=1
                runner=runner or (runner_factory or HeadRunner)()
                features,labels=runner.predict(arrays,allowed[relative]['features'])
                # Reuse MyMusic's actual schema validator before committing results.
                make_document(2,[{**metadata['identity'],'features':features}])
                cache.save_head(row,profile,features,labels)
                del arrays
                result['success']+=1
                print(f"[{index}/{len(rows)}] Heads {relative} | V={features['vocal']:.3f} I={features['instrumental']:.3f}",flush=True)
            except Exception as error:
                cache.save_head(row,profile,error=error)
                result['failed']+=1
                print(f'  ERROR {relative}: {error}',flush=True)
    except KeyboardInterrupt:
        result['interrupted']=True
        print('Interrupted; saved head results preserved.',flush=True)
    return result,profile


def update(cache,scope,directory,output,backend_factory=None,reuse_factory=None,
           runner_factory=None,metadata_reader=None,force_heads=False):
    """One normal-operation pass: refresh, embed the delta, apply heads, export."""
    kwargs={} if metadata_reader is None else {'metadata_reader':metadata_reader}
    refreshed,paths,mtimes,scan=refresh_scope(directory,scope,cache.track_records(),**kwargs)
    reconciliation=cache.reconcile_scope(refreshed,mtimes)
    print(f"Library: {scan['discovered']:,} discovered; {scan['new']:,} new; "
          f"{scan['updated']:,} updated; {scan['deleted']:,} deleted",flush=True)
    embedded=embed(cache,refreshed,None,backend_factory,reuse_factory,(paths,scan))
    result=dict(stage='update',scan=scan,reconciliation=reconciliation,embed=embedded,
                audioReads=embedded['audioReads'],decodeCalls=embedded['decodeCalls'],
                interrupted=embedded['interrupted'],failed=len(scan['metadataErrors'])+embedded['failed'])
    if embedded['interrupted']:
        return result,refreshed
    classified,profile=heads(cache,refreshed,None,force_heads,runner_factory)
    result.update(heads=classified,headProfile=profile,
                  interrupted=classified['interrupted'],failed=result['failed']+classified['failed'])
    if classified['interrupted']:
        return result,refreshed
    document=make_document(2,cache.export_rows(profile))
    atomic_json(output,document,directory)
    result.update(output=str(output),exported=len(document['tracks']))
    return result,refreshed


def main(argv=None):
    parser=argparse.ArgumentParser(description='Independent full-library semantic cache; never writes production/PoC data.')
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--update',action='store_true',help='Rescan library, analyze only changes, apply heads, export')
    mode.add_argument('--stage',choices=('embed','heads'),help='Advanced: run one legacy stage only')
    parser.add_argument('--music-root',type=Path,
                        help='Audio root. With --update, initialize/resume an isolated live-library workspace')
    parser.add_argument('--source-json',type=Path,help='Frozen allowlist + existing DSP; default repository music_features.json')
    parser.add_argument('--cache-dir',type=Path,
                        help='Dedicated cache. --update with --music-root defaults to a root-specific semantic_workspaces child')
    parser.add_argument('--output',type=Path,help='Heads JSON; must be inside this cache/output')
    parser.add_argument('--limit',type=int,help='Restrict to first N frozen tracks, including already completed ones')
    parser.add_argument('--expect-tracks',type=int,help='Fail closed if frozen source count differs, e.g. 3552')
    parser.add_argument('--force-heads',action='store_true',help='Re-run heads only; never re-read audio')
    args=parser.parse_args(argv)
    if args.limit is not None and args.limit<1:
        parser.error('--limit must be positive')
    if args.update and (args.source_json is not None or args.limit is not None or args.expect_tracks is not None):
        parser.error('--update scans the full live library; omit source/limit/expected count')
    if args.stage=='heads' and (args.music_root is not None or args.source_json is not None):
        parser.error('heads uses the saved snapshot only; omit --music-root/--source-json')
    if args.stage=='embed' and (args.force_heads or args.output):
        parser.error('--force-heads/--output belong to heads stage')
    if args.cache_dir is None:
        if args.update and args.music_root is not None:
            try:
                args.cache_dir=CACHE_SETS_HOME/dynamic_cache_name(args.music_root)
            except (ValueError,OSError) as error:
                parser.error(str(error))
        else:
            args.cache_dir=CACHE_HOME
    def interrupted(_sig,_frame):
        raise KeyboardInterrupt()
    signal.signal(signal.SIGTERM,interrupted)
    try:
        with locked_cache(args.cache_dir,create=args.stage=='embed' or (args.update and args.music_root is not None)) as directory:
            runtime(directory)
            if args.update:
                scope=(prepare_dynamic_scope(directory,args.music_root)
                       if args.music_root is not None else load_scope(directory))
            elif args.stage=='embed':
                source=args.source_json
                if source is None and not (directory/'scope.json').exists():
                    source=ANALYZER.parent/'music_features.json'
                scope=prepare_scope(directory,args.music_root,source,args.expect_tracks)
            else:
                scope=load_scope(directory)
                if args.expect_tracks is not None and len(scope['tracks'])!=args.expect_tracks:
                    raise ValueError('Frozen track count differs')
            cache=SemanticCache(directory)
            cache.register_scope(scope)
            started=time.perf_counter()
            try:
                if args.update or args.stage=='heads':
                    output=safe_path(args.output or directory/'output/music_features_semantic_v2.json',directory/'output')
                from threadpoolctl import threadpool_limits
                with threadpool_limits(limits=2):
                    if args.update:
                        result,scope=update(cache,scope,directory,output,force_heads=args.force_heads)
                    elif args.stage=='embed':
                        result=embed(cache,scope,args.limit)
                    else:
                        result,profile=heads(cache,scope,args.limit,args.force_heads)
                        document=make_document(2,cache.export_rows(profile))
                        atomic_json(output,document,directory)
                        result.update(output=str(output),exported=len(document['tracks']))
                result.update(wallSeconds=time.perf_counter()-started,
                              completedAt=datetime.now(timezone.utc).isoformat(),scopeCount=len(scope['tracks']))
                cache.save_run(result)
                stage='update' if args.update else args.stage
                atomic_json(directory/f'last-{stage}-run.json',result,directory)
                print(json.dumps(result,ensure_ascii=False,indent=2),flush=True)
                return 130 if result['interrupted'] else (1 if result['failed'] else 0)
            finally:
                cache.close()
    except KeyboardInterrupt:
        print('Interrupted outside a track; completed cache records remain intact.',file=sys.stderr)
        return 130
    except (ValueError,OSError) as error:
        print(f'ERROR: {error}',file=sys.stderr)
        return 2


if __name__=='__main__':
    raise SystemExit(main())
