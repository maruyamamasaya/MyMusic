from __future__ import annotations

import json
import unicodedata
from collections import defaultdict
from typing import Any


class TrackFeatureResolver:
    """Conservatively resolves Track Features to the current Library."""

    duration_tolerance = 0.5

    def resolve_all(self, connection: Any) -> None:
        tracks = connection.execute(
            """SELECT track_id, title, artist, album, duration, relative_path, file_size
               FROM library_tracks WHERE is_present=1"""
        ).fetchall()
        ids = {row["track_id"] for row in tracks}
        path_index: dict[str, list[Any]] = defaultdict(list)
        size_index: dict[int, list[Any]] = defaultdict(list)
        for track in tracks:
            path = self.normalized_relative_path(track["relative_path"])
            if path is not None:
                path_index[path].append(track)
            if track["file_size"] is not None:
                size_index[track["file_size"]].append(track)

        records = connection.execute(
            "SELECT item_key, raw_json FROM source_records WHERE data_kind='track_features'"
        ).fetchall()
        for record in records:
            raw = json.loads(record["raw_json"])
            original_id = str(raw["trackID"])
            resolved_id = original_id
            if original_id not in ids:
                resolved_id = self._fallback(
                    raw.get("sourceIdentity") or {}, path_index, size_index
                ) or original_id
            connection.execute(
                """UPDATE source_records SET track_id=?
                   WHERE data_kind='track_features' AND item_key=?""",
                (resolved_id, record["item_key"]),
            )

    def _fallback(
        self, identity: dict[str, Any], path_index: dict[str, list[Any]],
        size_index: dict[int, list[Any]],
    ) -> str | None:
        path = self.normalized_relative_path(identity.get("relativePath"))
        file_size = identity.get("fileSize")
        duration = identity.get("duration")
        if path is None or not isinstance(file_size, int) or not isinstance(duration, (int, float)):
            return None

        path_candidates = path_index.get(path, [])
        if path_candidates:
            verified = [row for row in path_candidates if self._matches_file(row, file_size, duration)]
            return verified[0]["track_id"] if len(verified) == 1 else None

        if self.trimmed(identity.get("title")) is None or self.trimmed(identity.get("artist")) is None:
            return None
        verified = [
            row for row in size_index.get(file_size, [])
            if self._matches_file(row, file_size, duration) and self._matches_metadata(row, identity)
        ]
        return verified[0]["track_id"] if len(verified) == 1 else None

    def _matches_file(self, track: Any, file_size: int, duration: float) -> bool:
        return track["file_size"] == file_size and abs(track["duration"] - duration) <= self.duration_tolerance

    def _matches_metadata(self, track: Any, identity: dict[str, Any]) -> bool:
        if self.normalized_metadata(track["title"]) != self.normalized_metadata(identity.get("title")):
            return False
        if self.normalized_metadata(track["artist"]) != self.normalized_metadata(identity.get("artist")):
            return False
        album = self.trimmed(identity.get("album"))
        return album is None or self.normalized_metadata(track["album"]) == self.normalized_metadata(album)

    @staticmethod
    def normalized_relative_path(value: Any) -> str | None:
        if not isinstance(value, str):
            return None
        value = value.strip().replace("\\", "/")
        if not value or value.startswith("/"):
            return None
        parts = [part for part in value.split("/") if part]
        if not parts or any(part in {".", ".."} for part in parts):
            return None
        return unicodedata.normalize("NFC", "/".join(parts))

    @staticmethod
    def trimmed(value: Any) -> str | None:
        if not isinstance(value, str) or not value.strip():
            return None
        return value.strip()

    @classmethod
    def normalized_metadata(cls, value: Any) -> str | None:
        value = cls.trimmed(value)
        if value is None:
            return None
        folded = unicodedata.normalize("NFKD", value).casefold()
        return "".join(character for character in folded if not unicodedata.combining(character))
