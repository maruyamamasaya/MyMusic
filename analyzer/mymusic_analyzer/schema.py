from __future__ import annotations

import json
import math
import os
import re
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any


SCHEMA_VERSION = 1
STANDARD_SCORES = {
    "energy", "piano", "ambient", "electronic", "drumAndBass", "aggressive",
    "calm", "bright", "dark", "vocal", "instrumental",
}
FEATURE_KEYS = STANDARD_SCORES | {"tempo", "additional"}
TRACK_KEYS = {
    "relativePath", "fileSize", "duration", "modificationDate", "contentHash",
    "title", "artist", "album", "features",
}


def make_document(analysis_version: int, tracks: list[dict[str, Any]]) -> dict[str, Any]:
    document = {
        "schemaVersion": SCHEMA_VERSION,
        "analysisVersion": analysis_version,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "tracks": sorted(tracks, key=lambda track: track["relativePath"]),
    }
    validate_document(document)
    return document


def validate_document(document: dict[str, Any]) -> None:
    if set(document) != {"schemaVersion", "analysisVersion", "generatedAt", "tracks"}:
        raise ValueError("JSON root fields do not match MyMusic schema v1")
    if document["schemaVersion"] != 1:
        raise ValueError("schemaVersion must be 1")
    if not isinstance(document["analysisVersion"], int) or isinstance(document["analysisVersion"], bool) or document["analysisVersion"] < 1:
        raise ValueError("analysisVersion must be an integer >= 1")
    _parse_date(document["generatedAt"])
    if not isinstance(document["tracks"], list):
        raise ValueError("tracks must be an array")
    for index, track in enumerate(document["tracks"]):
        _validate_track(track, index)


def atomic_write_document(document: dict[str, Any], output_path: Path) -> None:
    validate_document(document)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = output_path.with_name(f".{output_path.name}.tmp")
    with temporary_path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(document, handle, ensure_ascii=False, indent=2, sort_keys=False, allow_nan=False)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary_path, output_path)


def _validate_track(track: Any, index: int) -> None:
    if not isinstance(track, dict) or not set(track).issubset(TRACK_KEYS):
        raise ValueError(f"tracks[{index}] has unsupported fields")
    for required in ("relativePath", "fileSize", "duration", "features"):
        if required not in track:
            raise ValueError(f"tracks[{index}].{required} is required")

    relative = track["relativePath"]
    if not isinstance(relative, str) or not relative or relative.startswith("/"):
        raise ValueError(f"tracks[{index}].relativePath is invalid")
    components = PurePosixPath(relative).parts
    if any(component in {".", ".."} for component in components):
        raise ValueError(f"tracks[{index}].relativePath contains a dot component")
    if not isinstance(track["fileSize"], int) or isinstance(track["fileSize"], bool) or track["fileSize"] < 1:
        raise ValueError(f"tracks[{index}].fileSize is invalid")
    if not _finite_number(track["duration"]) or track["duration"] <= 0:
        raise ValueError(f"tracks[{index}].duration is invalid")
    if "modificationDate" in track:
        _parse_date(track["modificationDate"])
    if "contentHash" in track and not re.fullmatch(r"[0-9a-fA-F]{64}", track["contentHash"]):
        raise ValueError(f"tracks[{index}].contentHash is invalid")
    for field in ("title", "artist", "album"):
        if field in track and not isinstance(track[field], str):
            raise ValueError(f"tracks[{index}].{field} must be a string")
    _validate_features(track["features"], index)


def _validate_features(features: Any, index: int) -> None:
    if not isinstance(features, dict) or not features or not set(features).issubset(FEATURE_KEYS):
        raise ValueError(f"tracks[{index}].features is invalid")
    if "tempo" in features and (not _finite_number(features["tempo"]) or features["tempo"] <= 0):
        raise ValueError(f"tracks[{index}].features.tempo is invalid")
    for name in STANDARD_SCORES:
        if name in features and not _score(features[name]):
            raise ValueError(f"tracks[{index}].features.{name} is outside 0...1")
    if "additional" in features:
        additional = features["additional"]
        if not isinstance(additional, dict) or not additional:
            raise ValueError(f"tracks[{index}].features.additional is empty")
        if STANDARD_SCORES.intersection(additional):
            raise ValueError(f"tracks[{index}].features.additional duplicates a standard score")
        if any(not isinstance(name, str) or not name.strip() or not _score(value) for name, value in additional.items()):
            raise ValueError(f"tracks[{index}].features.additional is invalid")


def _score(value: Any) -> bool:
    return _finite_number(value) and 0.0 <= value <= 1.0


def _finite_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _parse_date(value: Any) -> datetime:
    if not isinstance(value, str):
        raise ValueError("date-time must be a string")
    return datetime.fromisoformat(value.replace("Z", "+00:00"))
