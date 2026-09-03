from __future__ import annotations

import json
import sqlite3
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .audio import AnalysisConfig
from .discovery import discover_audio_files, relative_path
from .metadata import file_signature
from .schema import atomic_write_document, make_document


@dataclass(frozen=True)
class LibraryRoot:
    name: str
    path: Path


def load_roots(manifest_path: Path) -> list[LibraryRoot]:
    raw = json.loads(manifest_path.read_text(encoding="utf-8"))
    if set(raw) != {"version", "roots"} or raw["version"] != 1 or not isinstance(raw["roots"], list):
        raise ValueError("manifest must contain version: 1 and roots")
    roots: list[LibraryRoot] = []
    names: set[str] = set()
    paths: set[str] = set()
    for index, item in enumerate(raw["roots"]):
        if not isinstance(item, dict) or set(item) != {"name", "path"}:
            raise ValueError(f"roots[{index}] must contain only name and path")
        name = str(item["name"]).strip()
        path = Path(item["path"]).expanduser().resolve()
        normalized = unicodedata.normalize("NFC", str(path))
        if not name or name in names or normalized in paths:
            raise ValueError(f"roots[{index}] has a duplicate or empty name/path")
        if not path.is_dir():
            raise ValueError(f"Music Root not found: {path}")
        names.add(name)
        paths.add(normalized)
        roots.append(LibraryRoot(name, path))
    return roots


def inventory(cache_path: Path, roots: list[LibraryRoot], analysis_version: int = 1) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    config_key = AnalysisConfig().cache_key()
    connection = sqlite3.connect(f"file:{cache_path.resolve()}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    all_entries: list[tuple[str, dict[str, Any]]] = []
    root_reports: list[dict[str, Any]] = []
    seen_roots: set[str] = set()
    try:
        cached_roots = [row[0] for row in connection.execute("SELECT DISTINCT root_path FROM track_analysis")]
        for library in roots:
            root_key = unicodedata.normalize("NFC", str(library.path))
            equivalent = [value for value in cached_roots if unicodedata.normalize("NFC", value) == root_key]
            seen_roots.update(equivalent)
            cached_rows = _rows_by_path(connection, equivalent)
            counts = {"discovered": 0, "cacheReusable": 0, "analysisFailed": 0,
                      "notAnalyzed": 0, "changedNeedsAnalysis": 0,
                      "incompatibleCache": 0, "needsAnalysis": 0, "missingFromDisk": 0}
            current_paths: set[str] = set()
            for path in discover_audio_files(library.path):
                relative = relative_path(path, library.path)
                current_paths.add(relative)
                counts["discovered"] += 1
                size, mtime_ns = file_signature(path)
                rows = cached_rows.get(relative, [])
                reusable = next((row for row in rows if row["status"] == "success"
                    and row["file_size"] == size and row["modification_time_ns"] == mtime_ns
                    and row["analysis_version"] == analysis_version
                    and row["config_key"] == config_key), None)
                if reusable is not None:
                    counts["cacheReusable"] += 1
                    all_entries.append((root_key, json.loads(reusable["result_json"])))
                elif not rows:
                    counts["notAnalyzed"] += 1
                    counts["needsAnalysis"] += 1
                elif all(row["status"] != "success" for row in rows):
                    counts["analysisFailed"] += 1
                else:
                    same_file = [row for row in rows if row["status"] == "success"
                        and row["file_size"] == size and row["modification_time_ns"] == mtime_ns]
                    if same_file:
                        counts["incompatibleCache"] += 1
                    else:
                        counts["changedNeedsAnalysis"] += 1
                    counts["needsAnalysis"] += 1
            counts["missingFromDisk"] = len(set(cached_rows) - current_paths)
            root_reports.append({"name": library.name, "path": str(library.path),
                                 "cacheRootAliases": equivalent, **counts})
        unconfigured = [root for root in cached_roots if root not in seen_roots]
    finally:
        connection.close()

    duplicates: dict[str, tuple[str, dict[str, Any]]] = {}
    conflicts: set[str] = set()
    for root_key, entry in all_entries:
        relative = entry["relativePath"]
        previous = duplicates.get(relative)
        if previous is not None and previous[0] != root_key:
            conflicts.add(relative)
        else:
            duplicates[relative] = (root_key, entry)
    report = {
        "version": 1, "cache": str(cache_path.resolve()), "analysisVersion": analysis_version,
        "configKey": config_key, "roots": root_reports, "unconfiguredCacheRoots": unconfigured,
        "masterCandidateCount": len(duplicates), "relativePathConflicts": sorted(conflicts),
    }
    return report, [entry for _, entry in duplicates.values()]


def export_master(cache_path: Path, roots: list[LibraryRoot], output_path: Path,
                  report_path: Path, analysis_version: int = 1) -> dict[str, Any]:
    report, entries = inventory(cache_path, roots, analysis_version)
    if report["relativePathConflicts"]:
        raise ValueError("relativePath conflicts prevent a safe master export")
    atomic_write_document(make_document(analysis_version, entries), output_path)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def _rows_by_path(connection: sqlite3.Connection, roots: list[str]) -> dict[str, list[sqlite3.Row]]:
    rows_by_path: dict[str, list[sqlite3.Row]] = {}
    for root in roots:
        for row in connection.execute("SELECT * FROM track_analysis WHERE root_path = ?", (root,)):
            rows_by_path.setdefault(row["relative_path"], []).append(row)
    return rows_by_path
