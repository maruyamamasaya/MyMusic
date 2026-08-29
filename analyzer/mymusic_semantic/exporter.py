"""Merge completed per-library Semantic JSON without touching analysis caches."""
from __future__ import annotations

from contextlib import contextmanager
import fcntl
import hashlib
import json
from pathlib import Path

from mymusic_analyzer.schema import make_document,validate_document

from .safety import ANALYZER,CACHE_HOME,CACHE_SETS_HOME,FORMAT,atomic_json,fingerprint,safe_path


MERGED_OUTPUT=ANALYZER/'output'/'music_features_semantic_v2_merged.json'
MERGED_SOURCES=ANALYZER/'output'/'music_features_semantic_v2_merged.sources.json'
SEMANTIC_ANALYSIS_VERSION=2
SEMANTIC_FEATURES={
    'piano','electronic','ambient','dark','vocal','instrumental','aggressive','calm','drumAndBass'
}


@contextmanager
def export_lock(output):
    boundary=Path(output).absolute().parent
    boundary.mkdir(parents=True,exist_ok=True)
    lock=safe_path(boundary/'.semantic-export-all.lock',boundary)
    with lock.open('a+b') as handle:
        try:
            fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('Another Semantic export-all process is running') from None
        try:
            yield
        finally:
            fcntl.flock(handle,fcntl.LOCK_UN)


def _load_json(path,label):
    if path.is_symlink():
        raise ValueError(f'{label}: symlinked JSON is not accepted: {path}')
    try:
        return json.loads(path.read_text())
    except (OSError,json.JSONDecodeError) as error:
        raise ValueError(f'{label}: broken JSON: {error}') from error


def _source_directories(default_cache,workspaces):
    candidates=[]
    default=Path(default_cache).absolute()
    if default.exists():
        candidates.append(('default',default))
    workspace_home=Path(workspaces).absolute()
    if workspace_home.exists():
        if workspace_home.is_symlink() or not workspace_home.is_dir():
            raise ValueError(f'Workspace home is not a safe directory: {workspace_home}')
        for path in sorted(workspace_home.glob('library-*'),key=lambda item:item.name):
            candidates.append((path.name,path.absolute()))
    return candidates


def _update_active(directory):
    lock=directory/'run.lock'
    if not lock.exists() or lock.is_symlink():
        return False
    with lock.open('rb') as handle:
        try:
            fcntl.flock(handle,fcntl.LOCK_SH|fcntl.LOCK_NB)
        except BlockingIOError:
            return True
        fcntl.flock(handle,fcntl.LOCK_UN)
    return False


def _read_source(label,directory,report):
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError(f'{label}: workspace is not a regular directory')
    output=safe_path(directory/'output'/'music_features_semantic_v2.json',directory)
    if not output.exists():
        result=dict(source=label,status='skipped',reason='Semantic output is missing',trackCount=0)
        report(f'Source {label}: SKIP — {result["reason"]}')
        return result,None
    owner_path=safe_path(directory/'owner.json',directory)
    scope_path=safe_path(directory/'scope.json',directory)
    if not owner_path.exists() or not scope_path.exists():
        raise ValueError(f'{label}: owner.json or scope.json is missing')
    owner=_load_json(owner_path,label)
    if not isinstance(owner,dict) or owner.get('format')!=FORMAT:
        raise ValueError(f'{label}: unknown cache owner/version')
    scope=_load_json(scope_path,label)
    root=scope.get('root') if isinstance(scope,dict) else None
    if not isinstance(root,str) or not root or not Path(root).is_absolute():
        raise ValueError(f'{label}: scope root is missing or not absolute')
    library_id=f'library-{fingerprint(root)[:16]}'
    if label.startswith('library-') and label!=library_id:
        raise ValueError(f'{label}: workspace name does not match its scope root ({library_id})')
    document=_load_json(output,label)
    try:
        validate_document(document)
    except ValueError as error:
        raise ValueError(f'{label}: invalid/incomplete Semantic JSON: {error}') from error
    if document['analysisVersion']!=SEMANTIC_ANALYSIS_VERSION:
        raise ValueError(f'{label}: expected analysisVersion 2, found {document["analysisVersion"]}')
    active=_update_active(directory)
    tracks=document['tracks']
    if not tracks:
        result=dict(source=label,libraryId=library_id,root=root,status='skipped',
                    reason='Semantic output contains zero tracks',trackCount=0,activeAtExport=active)
        report(f'Source {label}: SKIP — {result["reason"]}')
        return result,None
    seen=set()
    for index,track in enumerate(tracks):
        relative=track['relativePath']
        if relative in seen:
            raise ValueError(f'{label}: duplicate relativePath inside one library: {relative}')
        seen.add(relative)
        missing=SEMANTIC_FEATURES-set(track['features'])
        if missing:
            raise ValueError(f'{label}: tracks[{index}] is missing Semantic features: {sorted(missing)}')
    result=dict(source=label,libraryId=library_id,root=root,status='included',
                trackCount=len(tracks),input=str(output),sourceGeneratedAt=document['generatedAt'],
                activeAtExport=active)
    suffix='; update active, using last completed atomic JSON' if active else ''
    report(f'Source {label}: {len(tracks):,} tracks ({library_id}){suffix}')
    return result,tracks


def _encoded_json(value):
    return (json.dumps(value,ensure_ascii=False,indent=2,allow_nan=False)+'\n').encode()


def export_all(default_cache=CACHE_HOME,workspaces=CACHE_SETS_HOME,output=MERGED_OUTPUT,
               sources_output=MERGED_SOURCES,report=print):
    """Fail closed on broken sources and atomically publish one schema-v1 document."""
    output=Path(output).absolute()
    sources_output=Path(sources_output).absolute()
    if output.parent!=sources_output.parent:
        raise ValueError('Merged JSON and source manifest must share one output directory')
    if output==sources_output:
        raise ValueError('Merged JSON and source manifest must be different files')
    boundary=output.parent
    output=safe_path(output,boundary)
    sources_output=safe_path(sources_output,boundary)
    with export_lock(output):
        source_results=[]
        included=[]
        libraries={}
        for source_index,(label,directory) in enumerate(_source_directories(default_cache,workspaces)):
            try:
                result,tracks=_read_source(label,directory,report)
            except ValueError as error:
                report(f'Source {label}: ERROR — {error}')
                raise
            source_results.append(result)
            if tracks is None:
                continue
            library_id=result['libraryId']
            if library_id in libraries:
                raise ValueError(f'{label}: duplicate music root already exported by {libraries[library_id]}')
            libraries[library_id]=label
            for track_index,track in enumerate(tracks):
                included.append((track['relativePath'],library_id,source_index,track_index,track,label))
        if not included:
            raise ValueError('No completed Semantic workspace outputs were found')
        included.sort(key=lambda row:row[:4])
        tracks=[row[4] for row in included]
        document=make_document(SEMANTIC_ANALYSIS_VERSION,tracks)
        # make_document uses a stable relativePath sort. Equal paths retain the library ordering above.
        if document['tracks']!=tracks:
            raise ValueError('Merged track order changed unexpectedly')
        path_libraries={}
        for relative,library_id,*_ in included:
            path_libraries.setdefault(relative,set()).add(library_id)
        collisions={path:sorted(ids) for path,ids in path_libraries.items() if len(ids)>1}
        merged_sha=hashlib.sha256(_encoded_json(document)).hexdigest()
        manifest={
            'format':'mymusic-semantic-merged-sources-v1',
            'generatedAt':document['generatedAt'],
            'mergedOutput':output.name,
            'mergedSHA256':merged_sha,
            'schemaVersion':document['schemaVersion'],
            'analysisVersion':document['analysisVersion'],
            'sources':source_results,
            'inputTrackCount':len(tracks),
            'outputTrackCount':len(document['tracks']),
            'crossLibraryRelativePathCollisionCount':len(collisions),
            'tracks':[
                dict(outputIndex=index,libraryId=row[1],source=row[5],relativePath=row[0])
                for index,row in enumerate(included)
            ],
        }
        # Publish the app JSON last. A failed manifest write cannot replace the previous app export.
        atomic_json(sources_output,manifest,boundary)
        atomic_json(output,document,boundary)
        report(f'Input total: {len(tracks):,}; output: {len(document["tracks"]):,}; '
               f'cross-library relativePath collisions: {len(collisions):,}')
        report(f'Merged JSON: {output}')
        return dict(stage='export-all',sources=source_results,inputTracks=len(tracks),
                    exported=len(document['tracks']),relativePathCollisions=len(collisions),
                    output=str(output),sourceManifest=str(sources_output),mergedSHA256=merged_sha,
                    audioReads=0,decodeCalls=0)
