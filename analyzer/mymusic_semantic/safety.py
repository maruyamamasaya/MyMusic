from __future__ import annotations

from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import tempfile

ANALYZER = Path(__file__).resolve().parents[1]
CACHE_HOME = ANALYZER / "semantic_cache"
CACHE_SETS_HOME = ANALYZER / "semantic_workspaces"
FORMAT = "mymusic-semantic-cache-v1"


def digest(path):
    with Path(path).open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def fingerprint(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,ensure_ascii=False,allow_nan=False).encode()).hexdigest()


def safe_path(path, boundary):
    path, boundary = Path(path).absolute(), Path(boundary).absolute()
    if not path.is_relative_to(boundary):
        raise ValueError(f"Write is outside the independent cache: {path}")
    # Check every existing ancestor, including the cache root itself.
    for part in (path, *path.parents):
        if part.is_symlink():
            raise ValueError(f"Symlink is not a writable cache target: {part}")
    if path.is_file() and path.stat().st_nlink != 1:
        raise ValueError(f"Hard-linked cache file forbidden: {path}")
    if not path.resolve().is_relative_to(boundary.resolve()):
        raise ValueError("Resolved output escapes cache")
    return path


def atomic_json(path, value, boundary):
    data = json.dumps(value,ensure_ascii=False,indent=2,allow_nan=False)+'\n'
    atomic_file(path,boundary,lambda handle:handle.write(data.encode()))


def atomic_file(path, boundary, write):
    path = safe_path(path,boundary)
    path.parent.mkdir(parents=True,exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent,delete=False) as handle:
            temporary = Path(handle.name)
            write(handle)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary,path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)  # Only this invocation's temp file.


@contextmanager
def locked_cache(path, create=False):
    path = Path(path).absolute()
    boundaries=(CACHE_HOME,CACHE_SETS_HOME)
    boundary=next((candidate for candidate in boundaries if path.is_relative_to(candidate.absolute())),None)
    if boundary is None:
        raise ValueError(f"Cache must be inside {CACHE_HOME} or {CACHE_SETS_HOME}")
    path = safe_path(path,boundary)
    if not path.exists() and not create:
        raise ValueError("Cache does not exist; initialize semantic embeddings before --update")
    path.mkdir(parents=True,exist_ok=True)
    marker = safe_path(path/'owner.json',path)
    lock = safe_path(path/'run.lock',path)
    # Never adopt a non-empty user directory as a writable cache.
    if not marker.exists() and any(p.name not in ('run.lock','.DS_Store') for p in path.iterdir()):
        raise ValueError("Refusing non-empty, unowned cache directory")
    with lock.open('a+b') as handle:
        try:
            fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError("Another semantic process is using this cache") from None
        try:
            if marker.exists():
                if json.loads(marker.read_text()).get('format') != FORMAT:
                    raise ValueError("Unknown cache owner/version")
            elif create:
                atomic_json(marker,dict(format=FORMAT),path)
            else:
                raise ValueError("No semantic cache owner marker")
            yield path
        finally:
            fcntl.flock(handle,fcntl.LOCK_UN)
