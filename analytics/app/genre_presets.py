from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any, Iterable
from uuid import UUID, uuid4

from app.database import Database
from importer.schema import (
    GenreDisplayPresetV1,
    GenreDisplayPresetWrite,
    GenrePresetsExportV1,
    normalized_genre_value,
)


UNASSIGNED_GENRE_ID = "maruyama.MyMusic.genre.unassigned"
FIXED_GENRE_NAMES = {"作業用BGM", "ハイレゾ"}
BACKFILL_MIGRATION = "genre-display-presets-from-source-records-v1"


def _now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


class GenrePresetService:
    def __init__(self, database: Database):
        self.database = database

    def backfill_source_records_once(self) -> None:
        with self.database.connect() as connection:
            if connection.execute(
                "SELECT 1 FROM analytics_migrations WHERE name=?", (BACKFILL_MIGRATION,)
            ).fetchone():
                return
            rows = connection.execute(
                """SELECT raw_json FROM source_records
                   WHERE data_kind='genre_presets' ORDER BY rowid"""
            ).fetchall()
            for row in rows:
                try:
                    preset = GenreDisplayPresetV1.model_validate_json(row["raw_json"])
                except ValueError:
                    continue
                self._merge_presets(connection, [preset])
            connection.execute(
                "INSERT INTO analytics_migrations(name, applied_at) VALUES (?, ?)",
                (BACKFILL_MIGRATION, _now()),
            )

    def list_presets(self) -> dict[str, Any]:
        with self.database.connect() as connection:
            rows = connection.execute(
                "SELECT * FROM genre_display_presets ORDER BY position, created_at, id"
            ).fetchall()
        presets = [self._row_to_payload(row) for row in rows]
        return {"presets": presets, "count": len(presets)}

    def create(self, value: GenreDisplayPresetWrite) -> dict[str, Any]:
        now = _now()
        preset_id = str(uuid4())
        with self.database.connect() as connection:
            self._ensure_name_available(connection, value.name)
            position = int(connection.execute(
                "SELECT COALESCE(MAX(position), -1) + 1 FROM genre_display_presets"
            ).fetchone()[0])
            connection.execute(
                """INSERT INTO genre_display_presets(
                    id,name,normalized_name,enabled_genre_names,
                    includes_unassigned_genre_setting,position,created_at,updated_at
                ) VALUES(?,?,?,?,?,?,?,?)""",
                self._values(preset_id, value, position, now, now),
            )
            row = connection.execute(
                "SELECT * FROM genre_display_presets WHERE id=?", (preset_id,)
            ).fetchone()
        return self._row_to_payload(row)

    def update(self, preset_id: str, value: GenreDisplayPresetWrite) -> dict[str, Any]:
        canonical_id = str(UUID(preset_id))
        with self.database.connect() as connection:
            existing = connection.execute(
                "SELECT * FROM genre_display_presets WHERE id=?", (canonical_id,)
            ).fetchone()
            if existing is None:
                raise LookupError("ジャンルプリセットが見つかりません。")
            self._ensure_name_available(connection, value.name, canonical_id)
            connection.execute(
                """UPDATE genre_display_presets SET name=?, normalized_name=?,
                   enabled_genre_names=?, includes_unassigned_genre_setting=?, updated_at=?
                   WHERE id=?""",
                (value.name, normalized_genre_value(value.name),
                 self._genres_json(value.enabledGenreNames), self._bool_db(
                     value.includesUnassignedGenreSetting
                 ), _now(), canonical_id),
            )
            row = connection.execute(
                "SELECT * FROM genre_display_presets WHERE id=?", (canonical_id,)
            ).fetchone()
        return self._row_to_payload(row)

    def delete(self, preset_id: str) -> None:
        canonical_id = str(UUID(preset_id))
        with self.database.connect() as connection:
            deleted = connection.execute(
                "DELETE FROM genre_display_presets WHERE id=?", (canonical_id,)
            ).rowcount
            if not deleted:
                raise LookupError("ジャンルプリセットが見つかりません。")
            self._compact_positions(connection)

    def reorder(self, ids: list[UUID]) -> dict[str, Any]:
        canonical = [str(value) for value in ids]
        with self.database.connect() as connection:
            existing = [row["id"] for row in connection.execute(
                "SELECT id FROM genre_display_presets ORDER BY position, created_at, id"
            )]
            if len(canonical) != len(existing) or set(canonical) != set(existing):
                raise ValueError("並べ替えには現在のプリセットIDをすべて指定してください。")
            now = _now()
            for position, preset_id in enumerate(canonical):
                connection.execute(
                    "UPDATE genre_display_presets SET position=?, updated_at=? WHERE id=?",
                    (position, now, preset_id),
                )
        return self.list_presets()

    def export_document(self) -> dict[str, Any]:
        return {
            "kind": "mymusic.genre-display-presets",
            "version": 1,
            "presets": [self._export_payload(item) for item in self.list_presets()["presets"]],
        }

    def merge_document(
        self, connection: Any, document: GenrePresetsExportV1
    ) -> tuple[int, int, int]:
        return self._merge_presets(connection, document.presets)

    def library_genres(self) -> dict[str, Any]:
        with self.database.connect() as connection:
            rows = connection.execute(
                "SELECT genre FROM library_tracks WHERE is_present=1 AND genre IS NOT NULL"
            ).fetchall()
        found: dict[str, str] = {}
        for row in rows:
            for raw in row["genre"].replace("\0", ";").split(";"):
                name = raw.strip()
                if not name or name in FIXED_GENRE_NAMES or name == UNASSIGNED_GENRE_ID:
                    continue
                found.setdefault(normalized_genre_value(name), name)
        genres = sorted(found.values(), key=normalized_genre_value)
        return {"genres": genres, "unassignedGenreID": UNASSIGNED_GENRE_ID}

    def _merge_presets(
        self, connection: Any, presets: Iterable[GenreDisplayPresetV1]
    ) -> tuple[int, int, int]:
        added = updated = duplicate = 0
        occupied_ids = {
            row["id"] for row in connection.execute("SELECT id FROM genre_display_presets")
        }
        next_position = int(connection.execute(
            "SELECT COALESCE(MAX(position), -1) + 1 FROM genre_display_presets"
        ).fetchone()[0])
        for preset in presets:
            normalized_name = normalized_genre_value(preset.name)
            existing = connection.execute(
                "SELECT * FROM genre_display_presets WHERE normalized_name=?",
                (normalized_name,),
            ).fetchone()
            genre_json = self._genres_json(preset.enabledGenreNames)
            flag = self._bool_db(preset.includesUnassignedGenreSetting)
            now = _now()
            if existing is not None:
                unchanged = (
                    existing["name"] == preset.name
                    and set(json.loads(existing["enabled_genre_names"]))
                    == set(preset.enabledGenreNames)
                    and existing["includes_unassigned_genre_setting"] == flag
                )
                if unchanged:
                    duplicate += 1
                    continue
                connection.execute(
                    """UPDATE genre_display_presets SET name=?, enabled_genre_names=?,
                       includes_unassigned_genre_setting=?, updated_at=? WHERE id=?""",
                    (preset.name, genre_json, flag, now, existing["id"]),
                )
                updated += 1
                continue
            requested_id = str(preset.id)
            preset_id = str(uuid4()) if requested_id in occupied_ids else requested_id
            occupied_ids.add(preset_id)
            value = GenreDisplayPresetWrite(
                name=preset.name,
                enabledGenreNames=preset.enabledGenreNames,
                includesUnassignedGenreSetting=preset.includesUnassignedGenreSetting,
            )
            connection.execute(
                """INSERT INTO genre_display_presets(
                    id,name,normalized_name,enabled_genre_names,
                    includes_unassigned_genre_setting,position,created_at,updated_at
                ) VALUES(?,?,?,?,?,?,?,?)""",
                self._values(preset_id, value, next_position, now, now),
            )
            next_position += 1
            added += 1
        return added, updated, duplicate

    @staticmethod
    def _genres_json(values: list[str]) -> str:
        return json.dumps(values, ensure_ascii=False, separators=(",", ":"))

    @staticmethod
    def _bool_db(value: bool | None) -> int | None:
        return None if value is None else int(value)

    @classmethod
    def _values(
        cls, preset_id: str, value: GenreDisplayPresetWrite, position: int,
        created_at: str, updated_at: str,
    ) -> tuple[Any, ...]:
        return (
            preset_id, value.name, normalized_genre_value(value.name),
            cls._genres_json(value.enabledGenreNames),
            cls._bool_db(value.includesUnassignedGenreSetting), position,
            created_at, updated_at,
        )

    @staticmethod
    def _ensure_name_available(connection: Any, name: str, excluding_id: str | None = None) -> None:
        row = connection.execute(
            "SELECT id FROM genre_display_presets WHERE normalized_name=?",
            (normalized_genre_value(name),),
        ).fetchone()
        if row is not None and row["id"] != excluding_id:
            raise ValueError("同じ名前のジャンルプリセットが既にあります。")

    @staticmethod
    def _compact_positions(connection: Any) -> None:
        rows = connection.execute(
            "SELECT id FROM genre_display_presets ORDER BY position, created_at, id"
        ).fetchall()
        for position, row in enumerate(rows):
            connection.execute(
                "UPDATE genre_display_presets SET position=? WHERE id=?", (position, row["id"])
            )

    @staticmethod
    def _row_to_payload(row: Any) -> dict[str, Any]:
        flag = row["includes_unassigned_genre_setting"]
        genres = json.loads(row["enabled_genre_names"])
        return {
            "id": row["id"], "name": row["name"], "enabledGenreNames": genres,
            "includesUnassignedGenreSetting": None if flag is None else bool(flag),
            "position": row["position"], "createdAt": row["created_at"],
            "updatedAt": row["updated_at"],
            "includesUnassigned": flag != 1 or UNASSIGNED_GENRE_ID in genres,
        }

    @staticmethod
    def _export_payload(item: dict[str, Any]) -> dict[str, Any]:
        payload = {
            "id": item["id"], "name": item["name"],
            "enabledGenreNames": item["enabledGenreNames"],
        }
        if item["includesUnassignedGenreSetting"] is not None:
            payload["includesUnassignedGenreSetting"] = item["includesUnassignedGenreSetting"]
        return payload
