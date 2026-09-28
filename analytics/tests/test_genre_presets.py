from __future__ import annotations

import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from uuid import UUID

from fastapi.testclient import TestClient

from app.config import Settings
from app.database import Database
from app.main import create_app


ID_A = "10000000-0000-0000-0000-000000000001"
ID_B = "10000000-0000-0000-0000-000000000002"
ID_C = "10000000-0000-0000-0000-000000000003"
UNASSIGNED = "maruyama.MyMusic.genre.unassigned"


def preset(preset_id=ID_A, name="集中", genres=None, **extra):
    value = {"id": preset_id, "name": name,
             "enabledGenreNames": genres if genres is not None else ["Ambient"]}
    value.update(extra)
    return value


def document(presets):
    return {"kind": "mymusic.genre-display-presets", "version": 1, "presets": presets}


class GenrePresetAPITests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.settings = Settings(root / "data", root / "imports", root / "data" / "test.sqlite3")
        self.context = TestClient(create_app(self.settings))
        self.client = self.context.__enter__()

    def tearDown(self):
        self.context.__exit__(None, None, None)
        self.temp.cleanup()

    def upload(self, payload):
        return self.client.post("/api/import", files={
            "file": ("MyMusic-Genre-Display-Presets.json", json.dumps(payload).encode(),
                     "application/json")
        })

    def rows(self, table):
        connection = sqlite3.connect(self.settings.database_path)
        try:
            return connection.execute(f"SELECT * FROM {table} ORDER BY rowid").fetchall()
        finally:
            connection.close()

    def test_iphone_import_export_reimport_preserves_order_flags_and_missing_genres(self):
        payload = document([
            preset(ID_A, "集中", ["Ambient", UNASSIGNED],
                   includesUnassignedGenreSetting=True),
            preset(ID_B, "静か", ["Libraryにないジャンル"],
                   includesUnassignedGenreSetting=False),
            preset(ID_C, "旧形式", ["Classical"]),
        ])
        result = self.upload(payload).json()
        self.assertEqual((result["newCount"], result["updatedCount"], result["errorCount"]),
                         (3, 0, 0))

        exported = self.client.get("/api/genre-presets/export")
        self.assertIn('filename="MyMusic-Genre-Display-Presets.json"',
                      exported.headers["content-disposition"])
        body = exported.json()
        self.assertEqual(body["kind"], "mymusic.genre-display-presets")
        self.assertEqual(body["version"], 1)
        self.assertEqual([item["name"] for item in body["presets"]], ["集中", "静か", "旧形式"])
        self.assertTrue(body["presets"][0]["includesUnassignedGenreSetting"])
        self.assertFalse(body["presets"][1]["includesUnassignedGenreSetting"])
        self.assertNotIn("includesUnassignedGenreSetting", body["presets"][2])
        self.assertIn("Libraryにないジャンル", body["presets"][1]["enabledGenreNames"])

        round_trip = self.upload(body).json()
        self.assertEqual((round_trip["newCount"], round_trip["updatedCount"],
                          round_trip["duplicateCount"]), (0, 0, 3))
        listed = self.client.get("/api/genre-presets").json()["presets"]
        self.assertEqual([item["id"] for item in listed], [ID_A, ID_B, ID_C])
        self.assertTrue(listed[2]["includesUnassigned"])

    def test_import_merges_by_normalized_name_appends_and_regenerates_colliding_id(self):
        self.upload(document([preset(ID_A, "Ｆócus", ["Rock"])]))
        merged = self.upload(document([
            preset(ID_B, "focus", ["Jazz"], includesUnassignedGenreSetting=True),
            preset(ID_A, "新規", ["Ambient"], includesUnassignedGenreSetting=True),
        ])).json()
        self.assertEqual((merged["newCount"], merged["updatedCount"]), (1, 1))
        items = self.client.get("/api/genre-presets").json()["presets"]
        self.assertEqual([item["name"] for item in items], ["focus", "新規"])
        self.assertEqual(items[0]["id"], ID_A)
        self.assertNotEqual(items[1]["id"], ID_A)
        UUID(items[1]["id"])

        omitted = self.upload(document([preset(ID_B, "focus", ["Blues"])])).json()
        self.assertEqual(omitted["updatedCount"], 1)
        self.assertEqual([item["name"] for item in self.client.get(
            "/api/genre-presets").json()["presets"]], ["focus", "新規"])

    def test_invalid_documents_are_atomic_and_rejected_before_source_or_canonical_update(self):
        self.upload(document([preset()]))
        baseline_presets = self.rows("genre_display_presets")
        baseline_sources = self.rows("source_records")
        invalid_documents = [
            document([preset(name="   ")]),
            document([preset(preset_id="not-a-uuid")]),
            document([preset(), preset(ID_A, "別名")]),
            document([preset(name="Ｆócus"), preset(ID_B, "focus")]),
            document([preset(genres=["Ambient", "Ａmbient"])]),
            document([preset(genres=[" "])]),
            document([preset(includesUnassignedGenreSetting="true")]),
            document([{**preset(), "enabledGenreNames": "Ambient"}]),
            {**document([preset()]), "unknown": 1},
            document([{**preset(), "unknown": 1}]),
        ]
        for payload in invalid_documents:
            with self.subTest(payload=payload):
                result = self.upload(payload).json()
                self.assertGreater(result["errorCount"], 0)
                self.assertEqual(self.rows("genre_display_presets"), baseline_presets)
                self.assertEqual(self.rows("source_records"), baseline_sources)

    def test_crud_reorder_persist_and_leave_other_data_untouched(self):
        library = {"version": 1, "tracks": [{"trackID": "track-1", "title": "Song",
            "artist": "Artist", "album": None, "genre": "Rock; 作業用BGM\0Jazz",
            "year": None, "duration": 12, "format": "aac", "favorite": False,
            "playCount": 0, "lastPlayedAt": None}]}
        self.client.post("/api/import", files={"file": (
            "MyMusic-Library.json", json.dumps(library).encode(), "application/json")})
        other_before = {table: self.rows(table) for table in (
            "library_tracks", "playback_events", "playback_preferences"
        )}
        first = self.client.post("/api/genre-presets", json={
            "name": "一つ", "enabledGenreNames": ["Rock"],
            "includesUnassignedGenreSetting": True,
        })
        second = self.client.post("/api/genre-presets", json={
            "name": "二つ", "enabledGenreNames": ["存在しない"],
            "includesUnassignedGenreSetting": True,
        })
        self.assertEqual((first.status_code, second.status_code), (201, 201))
        first_id, second_id = first.json()["id"], second.json()["id"]
        updated = self.client.put(f"/api/genre-presets/{first_id}", json={
            "name": "一つ 編集", "enabledGenreNames": ["Jazz", UNASSIGNED],
            "includesUnassignedGenreSetting": True,
        })
        self.assertEqual(updated.status_code, 200)
        order = self.client.put("/api/genre-presets/order", json={"ids": [second_id, first_id]})
        self.assertEqual([item["id"] for item in order.json()["presets"]], [second_id, first_id])
        genres = self.client.get("/api/genre-presets/genres").json()["genres"]
        self.assertEqual(genres, ["Jazz", "Rock"])
        self.assertNotIn("作業用BGM", genres)
        self.assertEqual(self.client.delete(f"/api/genre-presets/{second_id}").status_code, 200)
        self.assertEqual([item["name"] for item in self.client.get(
            "/api/genre-presets").json()["presets"]], ["一つ 編集"])
        for table, rows in other_before.items():
            self.assertEqual(self.rows(table), rows, table)

        self.context.__exit__(None, None, None)
        with TestClient(create_app(self.settings)) as restarted:
            items = restarted.get("/api/genre-presets").json()["presets"]
            self.assertEqual([(item["id"], item["name"], item["position"])
                              for item in items], [(first_id, "一つ 編集", 0)])
        self.context = TestClient(create_app(self.settings))
        self.client = self.context.__enter__()

    def test_import_provenance_and_data_sources_remain_available(self):
        result = self.upload(document([preset()])).json()
        self.assertEqual(result["errorCount"], 0)
        sources = self.client.get("/api/sources/genre_presets").json()
        self.assertEqual((sources["count"], sources["items"][0]["data"]["name"]), (1, "集中"))
        history = self.client.get("/api/imports").json()["imports"]
        self.assertEqual((history[0]["dataKind"], history[0]["newCount"]),
                         ("genre_presets", 1))
        self.assertEqual(len(list(self.settings.imports_dir.glob("*.json"))), 1)
        self.client.delete("/api/imports")
        self.assertEqual(self.client.get("/api/genre-presets").json()["count"], 1)

    def test_track_list_applies_preset_with_exact_genres_fixed_and_unassigned(self):
        def track(track_id, title, genre):
            return {"trackID": track_id, "title": title, "artist": "Artist",
                    "album": None, "genre": genre, "year": None, "duration": 12,
                    "format": "aac", "favorite": False, "playCount": 0,
                    "lastPlayedAt": None}

        library = {"version": 1, "tracks": [
            track("rock", "Rock", "Rock; Live"),
            track("hard-rock", "Hard Rock", "Hard Rock"),
            track("missing", "No Genre", None),
            track("work", "Work", "作業用BGM"),
            track("hires", "Hi-Res", "ハイレゾ"),
            track("pop", "Pop", "Pop"),
        ]}
        imported = self.client.post("/api/import", files={"file": (
            "MyMusic-Library.json", json.dumps(library).encode(), "application/json")})
        self.assertEqual(imported.json()["errorCount"], 0)
        created = self.client.post("/api/genre-presets", json={
            "name": "Rock と未分類", "enabledGenreNames": ["Rock", UNASSIGNED],
            "includesUnassignedGenreSetting": True,
        }).json()

        response = self.client.get("/api/tracks", params={"presetId": created["id"]})
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["appliedPreset"]["name"], "Rock と未分類")
        self.assertEqual({item["trackId"] for item in body["tracks"]},
                         {"rock", "missing", "work", "hires"})

        without_unassigned = self.client.post("/api/genre-presets", json={
            "name": "Rock のみ", "enabledGenreNames": ["Rock"],
            "includesUnassignedGenreSetting": True,
        }).json()
        filtered = self.client.get("/api/tracks", params={
            "presetId": without_unassigned["id"]
        }).json()["tracks"]
        self.assertEqual({item["trackId"] for item in filtered}, {"rock", "work", "hires"})

        legacy = self.client.post("/api/genre-presets", json={
            "name": "旧形式相当", "enabledGenreNames": ["Pop"],
            "includesUnassignedGenreSetting": False,
        }).json()
        legacy_tracks = self.client.get("/api/tracks", params={
            "presetId": legacy["id"]
        }).json()["tracks"]
        self.assertEqual({item["trackId"] for item in legacy_tracks},
                         {"pop", "missing", "work", "hires"})

        self.assertEqual(self.client.get("/api/tracks", params={
            "presetId": ID_C
        }).status_code, 404)
        self.assertEqual(self.client.get("/api/tracks", params={
            "presetId": "not-a-uuid"
        }).status_code, 422)

    def test_legacy_source_records_backfill_once(self):
        self.context.__exit__(None, None, None)
        database = Database(self.settings.database_path)
        with database.connect() as connection:
            connection.execute("DELETE FROM analytics_migrations")
            connection.execute("DELETE FROM genre_display_presets")
            cursor = connection.execute(
                "INSERT INTO import_runs(imported_at,source_filename,data_kind) VALUES(?,?,?)",
                ("2026-09-01T00:00:00Z", "old.json", "genre_presets"),
            )
            connection.execute(
                """INSERT OR REPLACE INTO source_records(
                   data_kind,item_key,title,subtitle,imported_at,import_id,raw_json
                   ) VALUES(?,?,?,?,?,?,?)""",
                ("genre_presets", f"preset:{ID_A}", "旧データ", "genre preset",
                 "2026-09-01T00:00:00Z", cursor.lastrowid,
                 json.dumps(preset(ID_A, "旧データ", ["Ambient"]))),
            )
        for _ in range(2):
            with TestClient(create_app(self.settings)) as restarted:
                items = restarted.get("/api/genre-presets").json()["presets"]
                self.assertEqual([(item["id"], item["name"]) for item in items],
                                 [(ID_A, "旧データ")])
        self.context = TestClient(create_app(self.settings))
        self.client = self.context.__enter__()


if __name__ == "__main__":
    unittest.main()
