from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Settings:
    data_dir: Path
    imports_dir: Path
    database_path: Path
    max_import_bytes: int = 20 * 1024 * 1024

    @classmethod
    def from_environment(cls) -> "Settings":
        data_dir = Path(os.environ.get("MYMUSIC_ANALYTICS_DATA_DIR", ROOT_DIR / "data"))
        imports_dir = Path(os.environ.get("MYMUSIC_ANALYTICS_IMPORTS_DIR", ROOT_DIR / "imports"))
        return cls(data_dir, imports_dir, data_dir / "analytics.sqlite3")

    def ensure_directories(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.imports_dir.mkdir(parents=True, exist_ok=True)
