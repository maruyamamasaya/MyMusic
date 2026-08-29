"""PoC-only persistence and frozen, bounded selection from the v1 metadata cache."""
from __future__ import annotations

import json
import os
import sqlite3
import tempfile
import unicodedata
from pathlib import Path

from prepare_models import HERE, sha256

REPO = HERE.parent.parent
PRODUCTION = (REPO / "analyzer/cache/analysis.sqlite3", REPO / "music_features.json")
MAX_TRACKS = 30


def safe_target(path: Path) -> Path:
    resolved = path.resolve()
    if not resolved.is_relative_to(HERE) or path.is_symlink():
        raise ValueError(f"Writes are restricted to the isolated PoC directory: {path}")
    if path.exists() and path.is_file() and path.stat().st_nlink != 1:
        raise ValueError("Hard-linked output is not allowed")
    return resolved


def atomic_json(path: Path, value: object) -> None:
    atomic_text(path, json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n")


def atomic_text(path: Path, value: str) -> None:
    target = safe_target(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=target.parent, delete=False) as handle:
        handle.write(value)
        handle.flush()
        os.fsync(handle.fileno())
        temporary = handle.name
    os.replace(temporary, target)


def production_hashes() -> dict[str, str]:
    for suffix in ("-wal", "-journal"):
        if Path(str(PRODUCTION[0]) + suffix).exists():
            raise ValueError("v1 cache may be active; stop v1 before taking a read-only snapshot")
    return {str(path.relative_to(REPO)): sha256(path) for path in PRODUCTION}


def read_v1() -> list[dict]:
    # Never use the v1 AnalysisCache constructor (it enables WAL and can write).
    connection = sqlite3.connect(PRODUCTION[0].as_uri() + "?mode=ro&immutable=1", uri=True)
    try:
        rows = connection.execute(
            "SELECT root_path, relative_path, file_size, modification_time_ns, "
            "result_json, config_key FROM track_analysis "
            "WHERE status='success' AND analysis_version=1 ORDER BY relative_path"
        ).fetchall()
    finally:
        connection.close()
    return [dict(root=root, relativePath=path, fileSize=size, mtimeNS=mtime,
                 v1=json.loads(result), v1Config=config)
            for root, path, size, mtime, result, config in rows]


def choose_tracks(rows: list[dict], count: int) -> list[dict]:
    if not 10 <= count <= MAX_TRACKS:
        raise ValueError("Selection must contain 10–30 tracks")
    chosen = []
    seen = set()

    def add(row: dict, reason: str) -> None:
        key = (row["root"], row["relativePath"])
        if key not in seen and len(chosen) < count:
            chosen.append({**row, "selectionReason": reason})
            seen.add(key)

    # Metadata hints, NOT ground-truth labels. No filesystem traversal or decoding.
    hints = ["Chopin Nocturne", "Chopin Ballade", "Ave Maria (Schubert)",
             "Augustin Hadelich", "Just Be Friends -piano", "Alan Walker - Faded",
             "INTERNET YAMERO", "メズマライザー(大漠波新", "Adele/Hello",
             "Billie Eilish, Khalid - lovely", "東京テディベア", "Cö shu Nie/Hollow"]
    for hint in hints:
        match = next((row for row in rows if hint.casefold() in row["relativePath"].casefold()), None)
        if match:
            add(match, f"metadata hint: {hint}; not a verified genre label")
    for feature in ("energy", "ambient", "drumAndBass", "dark"):
        ordered = sorted(rows, key=lambda row: row["v1"]["features"].get(feature, 0))
        if ordered:
            add(ordered[0], f"v1 {feature} minimum; not ground truth")
            add(ordered[-1], f"v1 {feature} maximum; not ground truth")
    for row in rows:
        add(row, "deterministic cache order fallback")
    if len(chosen) < 10:
        raise ValueError("Fewer than ten cached tracks available")
    return chosen


def validate_manifest(manifest: dict) -> None:
    tracks = manifest["tracks"]
    if not 10 <= len(tracks) <= MAX_TRACKS:
        raise ValueError("Manifest is restricted to 10–30 tracks")
    identities = [(row["root"], row["relativePath"]) for row in tracks]
    if len(set(identities)) != len(identities):
        raise ValueError("Duplicate manifest identity")
    for row in tracks:
        relative = row["relativePath"]
        if (Path(relative).is_absolute() or ".." in Path(relative).parts
                or unicodedata.normalize("NFC", relative) != relative):
            raise ValueError("Invalid or non-NFC relativePath")
        if row["v1"]["relativePath"] != relative or row["v1"]["fileSize"] != row["fileSize"]:
            raise ValueError("Cached identity mismatch")


def verify_audio_identity(row: dict) -> Path:
    root = Path(row["root"]).resolve()
    path = (root / row["relativePath"]).resolve()
    if not path.is_relative_to(root):
        raise ValueError("Audio path escapes cached root")
    stat = path.stat()
    if (stat.st_size, stat.st_mtime_ns) != (row["fileSize"], row["mtimeNS"]):
        raise ValueError("Audio changed since v1; refusing a misleading comparison")
    # macOS UF_DATALESS: avoid an implicit iCloud download during a timed PoC.
    if getattr(stat, "st_flags", 0) & 0x40000000:
        raise ValueError("iCloud dataless file; not locally downloaded")
    return path


class PocCache:
    def __init__(self, path: Path):
        target = safe_target(path)
        target.parent.mkdir(parents=True, exist_ok=True)
        self.connection = sqlite3.connect(target)
        self.connection.execute("PRAGMA synchronous=FULL")
        self.connection.execute(
            "CREATE TABLE IF NOT EXISTS results (identity TEXT PRIMARY KEY, "
            "config TEXT NOT NULL, status TEXT NOT NULL, payload TEXT NOT NULL)"
        )
        self.connection.commit()

    @staticmethod
    def key(row: dict) -> str:
        return json.dumps([row["root"], row["relativePath"], row["fileSize"], row["mtimeNS"]], ensure_ascii=False)

    def success(self, row: dict, config: str) -> dict | None:
        value = self.connection.execute(
            "SELECT payload FROM results WHERE identity=? AND config=? AND status='success'",
            (self.key(row), config),
        ).fetchone()
        return json.loads(value[0]) if value else None

    def save(self, row: dict, config: str, status: str, result: dict) -> None:
        with self.connection:
            self.connection.execute(
                "INSERT OR REPLACE INTO results VALUES (?, ?, ?, ?)",
                (self.key(row), config, status, json.dumps(result, ensure_ascii=False, allow_nan=False)),
            )

    def close(self) -> None:
        self.connection.close()
