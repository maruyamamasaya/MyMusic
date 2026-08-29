from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class AnalysisCache:
    def __init__(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self.connection = sqlite3.connect(path)
        self.connection.execute("PRAGMA journal_mode=WAL")
        self.connection.execute("PRAGMA synchronous=NORMAL")
        self.connection.execute(
            """
            CREATE TABLE IF NOT EXISTS track_analysis (
                root_path TEXT NOT NULL,
                relative_path TEXT NOT NULL,
                file_size INTEGER NOT NULL,
                modification_time_ns INTEGER NOT NULL,
                analysis_version INTEGER NOT NULL,
                config_key TEXT NOT NULL,
                status TEXT NOT NULL,
                result_json TEXT,
                error_message TEXT,
                updated_at TEXT NOT NULL,
                PRIMARY KEY (root_path, relative_path)
            )
            """
        )
        self.connection.execute(
            """
            CREATE TABLE IF NOT EXISTS track_loudness (
                root_path TEXT NOT NULL,
                relative_path TEXT NOT NULL,
                file_size INTEGER NOT NULL,
                modification_time_ns INTEGER NOT NULL,
                analysis_revision TEXT NOT NULL,
                status TEXT NOT NULL,
                result_json TEXT,
                error_message TEXT,
                updated_at TEXT NOT NULL,
                PRIMARY KEY (root_path, relative_path)
            )
            """
        )
        self.connection.commit()

    def valid_result(
        self,
        root_path: str,
        relative_path: str,
        file_size: int,
        modification_time_ns: int,
        analysis_version: int,
        config_key: str,
    ) -> dict[str, Any] | None:
        row = self.connection.execute(
            """
            SELECT result_json FROM track_analysis
            WHERE root_path = ? AND relative_path = ? AND file_size = ?
              AND modification_time_ns = ? AND analysis_version = ?
              AND config_key = ? AND status = 'success'
            """,
            (root_path, relative_path, file_size, modification_time_ns, analysis_version, config_key),
        ).fetchone()
        return json.loads(row[0]) if row and row[0] else None

    def save_success(
        self,
        root_path: str,
        relative_path: str,
        file_size: int,
        modification_time_ns: int,
        analysis_version: int,
        config_key: str,
        result: dict[str, Any],
    ) -> None:
        self._upsert(
            root_path, relative_path, file_size, modification_time_ns,
            analysis_version, config_key, "success", json.dumps(result, ensure_ascii=False), None,
        )

    def save_error(
        self,
        root_path: str,
        relative_path: str,
        file_size: int,
        modification_time_ns: int,
        analysis_version: int,
        config_key: str,
        message: str,
    ) -> None:
        self._upsert(
            root_path, relative_path, file_size, modification_time_ns,
            analysis_version, config_key, "error", None, message,
        )

    def valid_loudness_result(
        self,
        root_path: str,
        relative_path: str,
        file_size: int,
        modification_time_ns: int,
        analysis_revision: str,
    ) -> dict[str, float] | None:
        row = self.connection.execute(
            """
            SELECT result_json FROM track_loudness
            WHERE root_path = ? AND relative_path = ? AND file_size = ?
              AND modification_time_ns = ? AND analysis_revision = ?
              AND status = 'success'
            """,
            (root_path, relative_path, file_size, modification_time_ns, analysis_revision),
        ).fetchone()
        return json.loads(row[0]) if row and row[0] else None

    def save_loudness_success(
        self,
        root_path: str,
        relative_path: str,
        file_size: int,
        modification_time_ns: int,
        analysis_revision: str,
        result: dict[str, float],
    ) -> None:
        self._upsert_loudness(
            root_path, relative_path, file_size, modification_time_ns,
            analysis_revision, "success", json.dumps(result, ensure_ascii=False), None,
        )

    def save_loudness_error(
        self,
        root_path: str,
        relative_path: str,
        file_size: int,
        modification_time_ns: int,
        analysis_revision: str,
        message: str,
    ) -> None:
        self._upsert_loudness(
            root_path, relative_path, file_size, modification_time_ns,
            analysis_revision, "error", None, message,
        )

    def close(self) -> None:
        self.connection.close()

    def _upsert(
        self,
        root_path: str,
        relative_path: str,
        file_size: int,
        modification_time_ns: int,
        analysis_version: int,
        config_key: str,
        status: str,
        result_json: str | None,
        error_message: str | None,
    ) -> None:
        self.connection.execute(
            """
            INSERT INTO track_analysis (
                root_path, relative_path, file_size, modification_time_ns,
                analysis_version, config_key, status, result_json, error_message, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(root_path, relative_path) DO UPDATE SET
                file_size = excluded.file_size,
                modification_time_ns = excluded.modification_time_ns,
                analysis_version = excluded.analysis_version,
                config_key = excluded.config_key,
                status = excluded.status,
                result_json = excluded.result_json,
                error_message = excluded.error_message,
                updated_at = excluded.updated_at
            """,
            (
                root_path, relative_path, file_size, modification_time_ns,
                analysis_version, config_key, status, result_json, error_message,
                datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
            ),
        )
        self.connection.commit()

    def _upsert_loudness(
        self,
        root_path: str,
        relative_path: str,
        file_size: int,
        modification_time_ns: int,
        analysis_revision: str,
        status: str,
        result_json: str | None,
        error_message: str | None,
    ) -> None:
        self.connection.execute(
            """
            INSERT INTO track_loudness (
                root_path, relative_path, file_size, modification_time_ns,
                analysis_revision, status, result_json, error_message, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(root_path, relative_path) DO UPDATE SET
                file_size = excluded.file_size,
                modification_time_ns = excluded.modification_time_ns,
                analysis_revision = excluded.analysis_revision,
                status = excluded.status,
                result_json = excluded.result_json,
                error_message = excluded.error_message,
                updated_at = excluded.updated_at
            """,
            (
                root_path, relative_path, file_size, modification_time_ns,
                analysis_revision, status, result_json, error_message,
                datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
            ),
        )
        self.connection.commit()
