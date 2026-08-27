from __future__ import annotations

import unicodedata
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .discovery import relative_path


@dataclass(frozen=True)
class TrackMetadata:
    relative_path: str
    file_size: int
    modification_date: str
    modification_time_ns: int
    duration: float
    title: str
    artist: str
    album: str

    def identity_fields(self) -> dict[str, Any]:
        return {
            "relativePath": self.relative_path,
            "fileSize": self.file_size,
            "duration": round(self.duration, 6),
            "modificationDate": self.modification_date,
            "title": self.title,
            "artist": self.artist,
            "album": self.album,
        }


def read_metadata(path: Path, root: Path) -> TrackMetadata:
    from mutagen import File as MutagenFile

    stat = path.stat()
    audio = MutagenFile(path, easy=True)
    duration = float(getattr(getattr(audio, "info", None), "length", 0.0) or 0.0)
    if not duration > 0:
        raise ValueError("durationを取得できませんでした")

    relative = relative_path(path, root)
    relative_parts = Path(relative).parts
    tags = getattr(audio, "tags", None)
    title = _tag(tags, "title") or path.stem
    artist = _tag(tags, "artist") or (relative_parts[0] if len(relative_parts) > 1 else "Unknown Artist")
    album = _tag(tags, "album") or (relative_parts[-2] if len(relative_parts) > 1 else "Unknown Album")

    return TrackMetadata(
        relative_path=relative,
        file_size=stat.st_size,
        modification_date=_rfc3339(stat.st_mtime),
        modification_time_ns=stat.st_mtime_ns,
        duration=duration,
        title=_normalized(title),
        artist=_normalized(artist),
        album=_normalized(album),
    )


def file_signature(path: Path) -> tuple[int, int]:
    stat = path.stat()
    return stat.st_size, stat.st_mtime_ns


def _tag(tags: Any, key: str) -> str | None:
    if tags is None:
        return None
    value = tags.get(key)
    if isinstance(value, (list, tuple)):
        value = value[0] if value else None
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _normalized(value: str) -> str:
    return unicodedata.normalize("NFC", value.strip())


def _rfc3339(timestamp: float) -> str:
    return datetime.fromtimestamp(timestamp, timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
