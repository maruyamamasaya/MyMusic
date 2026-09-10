from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path


def _resource_root() -> Path:
    candidates = []
    bundle_root = getattr(sys, "_MEIPASS", None)
    if bundle_root:
        candidates.append(Path(bundle_root))
    if getattr(sys, "frozen", False):
        candidates.append(Path(sys.executable).resolve().parents[1] / "Resources")
    candidates.append(Path(__file__).resolve().parents[1])
    return next((path for path in candidates if (path / "web" / "index.html").is_file()), candidates[-1])


ROOT_DIR = _resource_root()


@dataclass(frozen=True)
class Settings:
    data_dir: Path
    imports_dir: Path
    database_path: Path
    max_import_bytes: int = 20 * 1024 * 1024
    desktop_token: str | None = None

    @classmethod
    def from_environment(cls) -> "Settings":
        data_dir = Path(os.environ.get("MYMUSIC_ANALYTICS_DATA_DIR", ROOT_DIR / "data"))
        imports_dir = Path(os.environ.get("MYMUSIC_ANALYTICS_IMPORTS_DIR", ROOT_DIR / "imports"))
        return cls(data_dir, imports_dir, data_dir / "analytics.sqlite3")

    def ensure_directories(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.imports_dir.mkdir(parents=True, exist_ok=True)
