from __future__ import annotations

import os
import unicodedata
from pathlib import Path


SUPPORTED_EXTENSIONS = {".m4a", ".mp3", ".flac", ".wav", ".aiff", ".aif", ".aac"}


def discover_audio_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for directory, directory_names, file_names in os.walk(root, followlinks=False):
        directory_names[:] = sorted(name for name in directory_names if not name.startswith("."))
        for name in sorted(file_names):
            if name.startswith("."):
                continue
            path = Path(directory) / name
            if path.is_symlink() or path.suffix.lower() not in SUPPORTED_EXTENSIONS:
                continue
            files.append(path)
    return sorted(files, key=lambda path: relative_path(path, root))


def relative_path(path: Path, root: Path) -> str:
    return unicodedata.normalize("NFC", path.relative_to(root).as_posix())

