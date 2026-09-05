from __future__ import annotations

import json
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from pydantic import ValidationError

from app.database import Database
from importer.schema import (
    LibraryExportV1,
    LibraryTrackV1,
    PlaybackEventV1,
    PlaybackExportV1,
    PlaybackPreferenceV1,
    PlaybackPreferencesExportV1,
    TrackFeaturesExportV1, VolumeExportV1, PlaylistsExportV1,
    EqualizerExportV1, GenrePresetsExportV1,
)
from importer.track_feature_resolver import TrackFeatureResolver


def _now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _utc(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _safe_filename(filename: str) -> str:
    name = Path(filename or "import.json").name
    stem = re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip(".-") or "import.json"
    return stem[:120]


def _canonical(raw: Any) -> str:
    return json.dumps(raw, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


class ImportService:
    def __init__(self, database: Database, imports_dir: Path):
        self.database = database
        self.imports_dir = Path(imports_dir)
        self.track_feature_resolver = TrackFeatureResolver()

    def import_bytes(self, content: bytes, source_filename: str) -> dict[str, Any]:
        imported_at = _now()
        errors: list[str] = []
        data_kind = "unknown"
        items: list[Any] = []
        exported_at: datetime | None = None
        try:
            decoded = json.loads(content.decode("utf-8-sig"))
            data_kind, items, exported_at = self._detect_document(decoded)
        except (UnicodeDecodeError, json.JSONDecodeError, ValidationError, ValueError, TypeError) as exc:
            errors.append(self._error_text(exc))

        archive_name = None
        if not errors:
            archive_name = (
                f"{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}-{uuid.uuid4().hex[:8]}-"
                f"{_safe_filename(source_filename)}"
            )
            (self.imports_dir / archive_name).write_bytes(content)

        with self.database.connect() as connection:
            cursor = connection.execute(
                """INSERT INTO import_runs(
                    imported_at, source_filename, archived_filename, data_kind
                ) VALUES (?, ?, ?, ?)""",
                (imported_at, _safe_filename(source_filename), archive_name, data_kind),
            )
            import_id = int(cursor.lastrowid)
            new_count = updated_count = duplicate_count = 0
            for index, raw_item in enumerate(items):
                try:
                    outcome = self._import_item(
                        connection, data_kind, raw_item, exported_at, imported_at, import_id
                    )
                    if outcome == "new":
                        new_count += 1
                    elif outcome == "updated":
                        updated_count += 1
                    else:
                        duplicate_count += 1
                except ValidationError as exc:
                    errors.append(f"{self._item_label(data_kind)}[{index}]: {self._error_text(exc)}")
                except (TypeError, ValueError) as exc:
                    errors.append(f"{self._item_label(data_kind)}[{index}]: {exc}")
            if data_kind == "library" and not errors:
                connection.execute(
                    "UPDATE library_tracks SET is_present = 0 WHERE import_id <> ?", (import_id,)
                )
            if data_kind in {"library", "track_features"} and not errors:
                self.track_feature_resolver.resolve_all(connection)
            if data_kind in {"volume_normalization", "playlists", "equalizer", "genre_presets"} and not errors:
                connection.execute(
                    "DELETE FROM source_records WHERE data_kind = ? AND import_id <> ?",
                    (data_kind, import_id),
                )
            connection.execute(
                """UPDATE import_runs SET new_count = ?, updated_count = ?, duplicate_count = ?,
                   error_count = ?, error_details = ? WHERE id = ?""",
                (new_count, updated_count, duplicate_count, len(errors),
                 json.dumps(errors, ensure_ascii=False), import_id),
            )
        return {
            "id": import_id,
            "dataKind": data_kind,
            "importedAt": imported_at,
            "sourceFilename": _safe_filename(source_filename),
            "newCount": new_count,
            "updatedCount": updated_count,
            "duplicateCount": duplicate_count,
            "errorCount": len(errors),
            "errors": errors[:20],
        }

    @staticmethod
    def _detect_document(decoded: Any) -> tuple[str, list[Any], datetime | None]:
        if not isinstance(decoded, dict):
            raise ValueError("JSON root must be an object")
        if "events" in decoded:
            document = PlaybackExportV1.model_validate(decoded)
            return "playback_events", document.events, document.exportedAt
        if decoded.get("kind") == "mymusic.equalizer":
            document = EqualizerExportV1.model_validate(decoded)
            items = [{"recordType": "current", **document.equalizer}]
            items += [{"recordType": "preset", **item} for item in document.customPresets]
            return "equalizer", items, None
        if decoded.get("kind") == "mymusic.genre-display-presets":
            document = GenrePresetsExportV1.model_validate(decoded)
            return "genre_presets", document.presets, None
        if "playlists" in decoded:
            document = PlaylistsExportV1.model_validate(decoded)
            return "playlists", [item.model_dump(mode="json", by_alias=True) for item in document.playlists], None
        if "tracks" in decoded and "schemaVersion" in decoded:
            document = PlaybackPreferencesExportV1.model_validate(decoded)
            return "playback_preferences", document.tracks, document.exportedAt
        if "tracks" in decoded and "version" in decoded:
            filename_markers = set(decoded.get("tracks", [{}])[0].keys()) if decoded.get("tracks") else set()
            if "features" in filename_markers or "sourceIdentity" in filename_markers or ("exportedAt" in decoded and "isEnabled" not in decoded):
                document = TrackFeaturesExportV1.model_validate(decoded)
                return "track_features", [item.model_dump(mode="json") for item in document.tracks], document.exportedAt
            if "integratedLUFS" in filename_markers or "normalizationGainDB" in filename_markers or "isEnabled" in decoded:
                document = VolumeExportV1.model_validate(decoded)
                return "volume_normalization", [item.model_dump(mode="json") for item in document.tracks], document.exportedAt
            document = LibraryExportV1.model_validate(decoded)
            return "library", document.tracks, None
        raise ValueError("対応しているMyMusic JSONではありません")

    def _import_item(
        self, connection: Any, data_kind: str, raw: Any, exported_at: datetime | None,
        imported_at: str, import_id: int,
    ) -> str:
        if data_kind == "playback_events":
            return self._import_event(connection, raw, imported_at, import_id)
        if data_kind == "library":
            return self._import_library_track(connection, raw, imported_at, import_id)
        if data_kind == "playback_preferences":
            assert exported_at is not None
            return self._import_preference(connection, raw, exported_at, imported_at, import_id)
        if data_kind in {"track_features", "volume_normalization", "playlists", "equalizer", "genre_presets"}:
            return self._import_source_record(connection, data_kind, raw, imported_at, import_id)
        raise ValueError("unsupported data kind")

    @staticmethod
    def _import_event(connection: Any, raw: Any, imported_at: str, import_id: int) -> str:
        event = PlaybackEventV1.model_validate(raw)
        values = (
            event.event_id, event.track_id, event.track_title, event.artist, event.album,
            _utc(event.played_at), event.play_duration, event.track_duration,
            int(event.completed), int(event.skipped), event.play_source,
            event.selection_type, event.session_id, event.platform, event.schema_version,
            imported_at, import_id, _canonical(raw),
        )
        inserted = connection.execute(
            """INSERT OR IGNORE INTO playback_events (
                event_id, track_id, track_title, artist, album, played_at,
                play_duration, track_duration, completed, skipped,
                play_source, selection_type, session_id, platform,
                schema_version, imported_at, import_id, raw_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            values,
        ).rowcount
        return "new" if inserted else "duplicate"

    @staticmethod
    def _import_library_track(connection: Any, raw: Any, imported_at: str, import_id: int) -> str:
        track = LibraryTrackV1.model_validate(raw)
        raw_json = _canonical(raw)
        existing = connection.execute(
            "SELECT raw_json FROM library_tracks WHERE track_id = ?", (track.track_id,)
        ).fetchone()
        if existing is not None and existing["raw_json"] == raw_json:
            connection.execute(
                """UPDATE library_tracks SET is_present = 1, imported_at = ?, import_id = ?
                   WHERE track_id = ?""",
                (imported_at, import_id, track.track_id),
            )
            return "duplicate"
        connection.execute(
            """INSERT INTO library_tracks (
                track_id, title, artist, album, genre, year, duration, format, favorite,
                source_play_count, source_last_played_at, audio_fingerprint, relative_path, file_size,
                first_seen_at, is_present, imported_at, import_id, raw_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
            ON CONFLICT(track_id) DO UPDATE SET
                title=excluded.title, artist=excluded.artist, album=excluded.album,
                genre=excluded.genre, year=excluded.year, duration=excluded.duration,
                format=excluded.format, favorite=excluded.favorite,
                source_play_count=excluded.source_play_count,
                source_last_played_at=excluded.source_last_played_at,
                audio_fingerprint=excluded.audio_fingerprint,
                relative_path=excluded.relative_path, file_size=excluded.file_size,
                first_seen_at=excluded.first_seen_at,
                is_present=1,
                imported_at=excluded.imported_at, import_id=excluded.import_id,
                raw_json=excluded.raw_json""",
            (track.track_id, track.title, track.artist, track.album, track.genre, track.year,
             track.duration, track.format, None if track.favorite is None else int(track.favorite),
             track.play_count, _utc(track.last_played_at), track.audio_fingerprint,
             TrackFeatureResolver.normalized_relative_path(track.relative_path), track.file_size,
             _utc(track.first_seen_at),
             imported_at, import_id, raw_json),
        )
        return "new" if existing is None else "updated"

    @staticmethod
    def _import_source_record(connection: Any, data_kind: str, raw: dict[str, Any], imported_at: str, import_id: int) -> str:
        if data_kind in {"track_features", "volume_normalization"}:
            item_key = track_id = str(raw["trackID"])
            title = raw.get("title") or track_id
            subtitle = raw.get("artist")
        elif data_kind == "playlists":
            item_key, track_id = str(raw["playlistID"]), None
            title, subtitle = raw["name"], raw.get("kind")
        elif data_kind == "equalizer":
            item_key = "current" if raw.get("recordType") == "current" else "preset:" + str(raw.get("id", raw.get("name", "preset")))
            track_id = None
            title = "現在の設定" if item_key == "current" else str(raw.get("name", "名称なし"))
            subtitle = raw.get("recordType")
        else:
            item_key = "preset:" + str(raw.get("id", raw.get("name", "preset")))
            track_id = None
            title, subtitle = str(raw.get("name", "名称なし")), "genre preset"
        raw_json = _canonical(raw)
        existing = connection.execute(
            "SELECT raw_json FROM source_records WHERE data_kind=? AND item_key=?", (data_kind, item_key)
        ).fetchone()
        if existing is not None and existing["raw_json"] == raw_json:
            connection.execute(
                "UPDATE source_records SET imported_at=?, import_id=? WHERE data_kind=? AND item_key=?",
                (imported_at, import_id, data_kind, item_key),
            )
            return "duplicate"
        connection.execute(
            """INSERT INTO source_records(data_kind,item_key,track_id,title,subtitle,imported_at,import_id,raw_json)
               VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(data_kind,item_key) DO UPDATE SET
               track_id=excluded.track_id,title=excluded.title,subtitle=excluded.subtitle,
               imported_at=excluded.imported_at,import_id=excluded.import_id,raw_json=excluded.raw_json""",
            (data_kind, item_key, track_id, title, subtitle, imported_at, import_id, raw_json),
        )
        return "new" if existing is None else "updated"

    @staticmethod
    def _import_preference(
        connection: Any, raw: Any, exported_at: datetime, imported_at: str, import_id: int,
    ) -> str:
        preference = PlaybackPreferenceV1.model_validate(raw)
        raw_json = _canonical(raw)
        existing = connection.execute(
            "SELECT raw_json FROM playback_preferences WHERE track_id = ?", (preference.track_id,)
        ).fetchone()
        if existing is not None and existing["raw_json"] == raw_json:
            return "duplicate"
        connection.execute(
            """INSERT INTO playback_preferences (
                track_id, playback_preference, favorite, exported_at, imported_at, import_id, raw_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(track_id) DO UPDATE SET
                playback_preference=excluded.playback_preference,
                favorite=excluded.favorite,
                exported_at=excluded.exported_at, imported_at=excluded.imported_at,
                import_id=excluded.import_id, raw_json=excluded.raw_json""",
            (preference.track_id, preference.playback_preference,
             None if preference.favorite is None else int(preference.favorite), _utc(exported_at),
             imported_at, import_id, raw_json),
        )
        return "new" if existing is None else "updated"

    @staticmethod
    def _item_label(data_kind: str) -> str:
        return "events" if data_kind == "playback_events" else "items"

    @staticmethod
    def _error_text(exc: Exception) -> str:
        if isinstance(exc, ValidationError):
            parts = []
            for error in exc.errors(include_url=False):
                location = ".".join(str(item) for item in error["loc"])
                parts.append(f"{location}: {error['msg']}" if location else error["msg"])
            return "; ".join(parts)
        return str(exc)
