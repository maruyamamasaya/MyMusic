"""Portable, checked backups of the independent semantic cache (no audio reads)."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import sqlite3
import tempfile
import zipfile

from .safety import FORMAT, digest, locked_cache, safe_path


def _validate(directory):
    if json.loads((directory / 'owner.json').read_text()).get('format') != FORMAT:
        raise ValueError('Unknown semantic cache version')
    database = directory / 'index.sqlite3'
    if not database.is_file():
        raise ValueError('Missing semantic index')
    with sqlite3.connect(f'{database.as_uri()}?mode=ro&immutable=1', uri=True) as db:
        if db.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
            raise ValueError('Corrupt semantic index')
        for path, checksum in db.execute("SELECT npz_path,npz_sha256 FROM tracks WHERE state='ready'"):
            if not path or not checksum:
                raise ValueError('Missing embedding reference')
            # npz_path is relative to the cache, as written by SemanticCache.
            candidate = safe_path(directory / path, directory)
            if digest(candidate) != checksum:
                raise ValueError('Embedding checksum mismatch')


def create_backup(cache, destination):
    destination = Path(destination).absolute()
    if destination.exists():
        raise ValueError('Backup destination already exists; choose a new filename')
    with locked_cache(cache) as directory:
        if destination.is_relative_to(directory):
            raise ValueError('Backup must be outside the cache')
        with tempfile.TemporaryDirectory() as temporary:
            staging = Path(temporary).resolve()
            for source in directory.rglob('*'):
                safe_path(source, directory)
                if source.is_file() and source.name not in ('run.lock', '.DS_Store', 'index.sqlite3', 'index.sqlite3-wal', 'index.sqlite3-shm', 'index.sqlite3-journal'):
                    target = staging / source.relative_to(directory)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, target)
            with sqlite3.connect(f'{(directory / "index.sqlite3").as_uri()}?mode=ro', uri=True) as source_db:
                with sqlite3.connect(staging / 'index.sqlite3') as target_db:
                    source_db.backup(target_db)
                    target_db.execute("PRAGMA journal_mode=DELETE")
            _validate(staging)
            files = sorted(p for p in staging.rglob('*') if p.is_file())
            manifest = dict(format='mymusic-semantic-backup', version=1, files=[
                dict(path=p.relative_to(staging).as_posix(), size=p.stat().st_size,
                     sha256=digest(p)) for p in files])
            destination.parent.mkdir(parents=True, exist_ok=True)
            # Exclusive creation never overwrites a previous backup.
            created = False
            try:
                with destination.open('xb') as handle:
                    created = True
                    with zipfile.ZipFile(handle, 'w', zipfile.ZIP_DEFLATED) as archive:
                        archive.writestr('manifest.json', json.dumps(manifest, ensure_ascii=False))
                        for path in files:
                            archive.write(path, path.relative_to(staging).as_posix())
            except Exception:
                if created:
                    destination.unlink(missing_ok=True)
                raise
    return manifest


def restore_backup(backup, cache):
    cache = Path(cache).absolute()
    # Restore only to a new location; never replace a working cache.
    if cache.exists():
        raise ValueError('Restore cache must not exist; choose a new workspace')
    from .safety import CACHE_HOME, CACHE_SETS_HOME
    boundary = next((p for p in (CACHE_HOME, CACHE_SETS_HOME) if cache.is_relative_to(p)), None)
    if boundary is None:
        raise ValueError('Restore must be inside semantic_cache or semantic_workspaces')
    safe_path(cache, boundary)
    cache.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=cache.parent) as temporary:
        staging = Path(temporary).resolve() / 'payload'
        staging.mkdir()
        with zipfile.ZipFile(backup) as archive:
            manifest = json.loads(archive.read('manifest.json'))
            if manifest.get('format') != 'mymusic-semantic-backup' or manifest.get('version') != 1:
                raise ValueError('Unsupported semantic backup')
            entries = manifest['files']
            names = [entry['path'] for entry in entries]
            if len(set(names)) != len(names) or sorted(archive.namelist()) != sorted(names + ['manifest.json']):
                raise ValueError('Duplicate or unexpected archive entry')
            for entry in entries:
                relative = Path(entry['path'])
                if relative.is_absolute() or '..' in relative.parts or entry['path'] in ('manifest.json', 'run.lock'):
                    raise ValueError('Unsafe archive path')
                target = safe_path(staging / relative, staging)
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(entry['path']) as source, target.open('xb') as output:
                    shutil.copyfileobj(source, output)
                if target.stat().st_size != entry['size'] or digest(target) != entry['sha256']:
                    raise ValueError('Backup checksum mismatch')
        _validate(staging)
        staging.rename(cache)
    return manifest


def main():
    parser = argparse.ArgumentParser(description='Back up or restore semantic embeddings, index, profiles and outputs')
    parser.add_argument('operation', choices=('create', 'restore'))
    parser.add_argument('--cache-dir', type=Path, required=True)
    parser.add_argument('--archive', type=Path, required=True)
    args = parser.parse_args()
    try:
        result = (create_backup(args.cache_dir, args.archive) if args.operation == 'create'
                  else restore_backup(args.archive, args.cache_dir))
    except (ValueError, OSError, sqlite3.Error, zipfile.BadZipFile, KeyError) as error:
        parser.exit(1, f'Backup failed: {error}\n')
    print(f"{args.operation}: {len(result['files'])} files verified")


if __name__ == '__main__':
    main()
