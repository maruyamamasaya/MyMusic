from __future__ import annotations

from datetime import datetime
import json
from pathlib import Path
import unicodedata

from mymusic_analyzer.discovery import discover_audio_files, relative_path
from mymusic_analyzer.metadata import read_metadata
from mymusic_analyzer.schema import validate_document
from .safety import atomic_json, digest, fingerprint, safe_path


def load_scope(cache):
    return json.loads(safe_path(cache/'scope.json',cache).read_text())


def dynamic_cache_name(music_root):
    """Return a stable, path-safe workspace name without exposing the source path."""
    root=Path(music_root).expanduser().resolve(strict=True)
    if not root.is_dir():
        raise ValueError("Music root is not a directory")
    return f"library-{fingerprint(str(root))[:16]}"


def prepare_dynamic_scope(cache,music_root):
    """Create or validate a live-library scope that needs no baseline feature JSON."""
    target=safe_path(cache/'scope.json',cache)
    root=Path(music_root).expanduser().resolve(strict=True)
    if not root.is_dir():
        raise ValueError("Music root is not a directory")
    if target.exists():
        scope=load_scope(cache)
        if str(root)!=scope['root']:
            raise ValueError("Root differs from saved live scope; use a new cache directory")
        if scope.get('mode')!='dynamic':
            raise ValueError("Saved cache is not an independently scanned live-library scope")
        return scope
    scope=dict(root=str(root),mode='dynamic',createdAt=datetime.now().astimezone().isoformat(),tracks=[])
    atomic_json(target,scope,cache)
    return scope


def prepare_scope(cache, music_root, source_json, expected_count):
    target = safe_path(cache/'scope.json',cache)
    if target.exists():
        scope = load_scope(cache)
        if music_root and str(Path(music_root).resolve()) != scope['root']:
            raise ValueError("Root differs from frozen scope; use a new cache directory")
        if source_json and str(Path(source_json).resolve()) != scope['sourceJSON']:
            raise ValueError("Source JSON differs from frozen scope")
        if digest(scope['sourceJSON']) != scope['sourceSHA256']:
            raise ValueError("Source JSON changed. Existing scope is frozen; no automatic expansion")
    else:
        if music_root is None:
            raise ValueError("--music-root is required for the first embed run")
        root = Path(music_root).resolve(strict=True)
        if not root.is_dir():
            raise ValueError("Music root is not a directory")
        source = Path(source_json).resolve(strict=True)
        if source.is_relative_to(cache):
            raise ValueError("Source JSON must not be inside the writable cache")
        checksum = digest(source)
        document = json.loads(source.read_text())
        validate_document(document)
        tracks = sorted(document['tracks'],key=lambda t:t['relativePath'])
        if not tracks:
            raise ValueError("Empty source scope")
        seen = set()
        for row in tracks:
            p = row['relativePath']
            if (p != unicodedata.normalize('NFC',p) or p in seen or
                    any(c in ('','.','..') for c in p.split('/')) or 'modificationDate' not in row):
                raise ValueError("Duplicate/noncanonical identity or missing modificationDate")
            seen.add(p)
        scope = dict(root=str(root),sourceJSON=str(source),sourceSHA256=checksum,tracks=tracks)
        if digest(source) != checksum:
            raise ValueError("Source JSON changed while taking snapshot")
        if expected_count is not None and len(tracks) != expected_count:
            raise ValueError(f"Expected {expected_count} tracks, found {len(tracks)}; no expansion performed")
        atomic_json(target,scope,cache)
    if expected_count is not None and len(scope['tracks']) != expected_count:
        raise ValueError("Frozen track count differs from --expect-tracks")
    return scope


def scan_scope(scope):
    root = Path(scope['root'])
    if not root.is_dir():
        raise ValueError('Music root is unavailable; cached entries are left unchanged')
    allowed = {row['relativePath'] for row in scope['tracks']}
    paths, ambiguous = {}, set()
    discovered = discover_audio_files(root)
    for path in discovered:
        relative = relative_path(path,root)
        if relative not in allowed:
            continue
        if relative in paths:
            ambiguous.add(relative)
        paths[relative] = path
    for relative in ambiguous:
        paths.pop(relative,None)
    return paths,dict(discovered=len(discovered),inScope=len(paths),ambiguous=sorted(ambiguous),
                      outsideScope=sum(relative_path(p,root) not in allowed for p in discovered))


def refresh_scope(cache, scope, records, metadata_reader=read_metadata):
    """Recursively rebuild the live scope while preserving unchanged metadata/features."""
    root=Path(scope['root'])
    if not root.is_dir():
        raise ValueError('Music root is unavailable; cached entries are left unchanged')
    discovered=discover_audio_files(root)
    grouped={}
    for path in discovered:
        grouped.setdefault(relative_path(path,root),[]).append(path)
    ambiguous=sorted(relative for relative,paths in grouped.items() if len(paths)!=1)
    paths={relative:items[0] for relative,items in grouped.items() if len(items)==1}
    old_scope={track['relativePath']:track for track in scope['tracks']}
    tracks=[];mtimes={};new=updated=unchanged=0;errors=[]
    for relative,path in sorted(paths.items()):
        try:
            if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
                raise ValueError('Source path escapes root or is symlinked')
            stat=path.stat()
            if getattr(stat,'st_flags',0) & 0x40000000:
                raise ValueError('iCloud file not locally downloaded; no implicit download')
            record=records.get(relative)
            previous=old_scope.get(relative)
            if previous is None and record is not None:
                previous={**record['identity'],'features':record['source_features']}
            same_size=previous is not None and previous['fileSize']==stat.st_size
            exact_mtime=record is not None and record['mtime_ns'] is not None and record['mtime_ns']==stat.st_mtime_ns
            legacy_mtime=(record is None or record['mtime_ns'] is None) and previous is not None \
                and int(datetime.fromisoformat(previous['modificationDate'].replace('Z','+00:00')).timestamp())==int(stat.st_mtime)
            if same_size and (exact_mtime or legacy_mtime):
                track=previous
                unchanged+=1
            else:
                metadata=metadata_reader(path,root)
                track={**metadata.identity_fields(),'features':{}}
                if previous is None:
                    new+=1
                else:
                    updated+=1
            tracks.append(track)
            mtimes[relative]=stat.st_mtime_ns
        except (OSError,ValueError) as error:
            errors.append(dict(relativePath=relative,error=f'{type(error).__name__}: {error}'))
            # Keep a changed existing path visible with its stale identity. Reconciliation will
            # invalidate it by mtime, and embed verification will fail closed until metadata works.
            previous=old_scope.get(relative)
            if previous is not None:
                tracks.append(previous)
                try:
                    mtimes[relative]=path.stat().st_mtime_ns
                except OSError:
                    tracks.pop()
    live={track['relativePath'] for track in tracks}
    deleted=sorted(relative for relative,row in records.items() if row['present'] and relative not in paths)
    refreshed={**scope,'mode':'dynamic','updatedAt':datetime.now().astimezone().isoformat(),
               'tracks':sorted(tracks,key=lambda track:track['relativePath'])}
    atomic_json(safe_path(cache/'scope.json',cache),refreshed,cache)
    report=dict(discovered=len(discovered),present=len(live),new=new,updated=updated,
                unchanged=unchanged,deleted=len(deleted),deletedPaths=deleted,
                ambiguous=ambiguous,metadataErrors=errors)
    return refreshed,paths,mtimes,report


def verify_source(path, root, identity, expected_ns=None):
    if path is None:
        raise ValueError("Missing or ambiguous source path")
    if path.is_symlink() or not path.resolve().is_relative_to(Path(root).resolve()):
        raise ValueError("Source path escapes root or is symlinked")
    stat = path.stat()
    saved = datetime.fromisoformat(identity['modificationDate'].replace('Z','+00:00')).timestamp()
    if stat.st_size != identity['fileSize'] or int(stat.st_mtime) != int(saved):
        raise ValueError("Source changed since JSON; refusing to attach embeddings to stale identity")
    if expected_ns is not None and stat.st_mtime_ns != expected_ns:
        raise ValueError("Source nanosecond timestamp changed; use a new source snapshot/cache")
    if getattr(stat,'st_flags',0) & 0x40000000:
        raise ValueError("iCloud file not locally downloaded; no implicit download")
    return stat.st_mtime_ns
