from __future__ import annotations

import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from uuid import uuid4

from fastapi.testclient import TestClient

from app.config import Settings
from app.database import Database
from app.main import create_app


def event(event_id: str = "event-1", track_id: str = "track-1", **overrides):
    value = {
        "eventId": event_id,
        "trackId": track_id,
        "trackTitle": "Night Drive",
        "artist": "Example Artist",
        "album": "City Lights",
        "playedAt": "2026-09-02T10:00:00+09:00",
        "playDuration": 200.0,
        "trackDuration": 210.0,
        "completed": True,
        "skipped": False,
        "playSource": "playlist",
        "selectionType": "manual",
        "sessionId": "session-1",
        "platform": "iOS",
        "schemaVersion": 1,
    }
    value.update(overrides)
    return value


def document(events):
    return {"schemaVersion": 1, "exportedAt": "2026-09-02T12:00:00Z", "events": events}


def library_document(tracks):
    return {"version": 1, "tracks": tracks}


def library_track(track_id: str = "track-1", **overrides):
    value = {
        "trackID": track_id,
        "title": "Night Drive",
        "artist": "Example Artist",
        "album": "City Lights",
        "genre": "Electronic",
        "year": 2026,
        "duration": 210.0,
        "format": "aac",
        "favorite": True,
        "playCount": 2,
        "lastPlayedAt": "2026-09-02T10:00:00Z",
    }
    value.update(overrides)
    return value


def preferences_document(tracks):
    return {"schemaVersion": 1, "exportedAt": "2026-09-02T12:00:00Z", "tracks": tracks}


class AnalyticsAPITests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.settings = Settings(root / "data", root / "imports", root / "data" / "test.sqlite3")
        self.client_context = TestClient(create_app(self.settings))
        self.client = self.client_context.__enter__()

    def tearDown(self):
        self.client_context.__exit__(None, None, None)
        self.temp.cleanup()

    def upload(self, payload, name="history.json"):
        content = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
        return self.client.post("/api/import", files={"file": (name, content, "application/json")})

    def test_json_import_and_sqlite_storage(self):
        response = self.upload(document([event()]))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["newCount"], 1)
        connection = sqlite3.connect(self.settings.database_path)
        try:
            stored = connection.execute("SELECT event_id, raw_json FROM playback_events").fetchone()
        finally:
            connection.close()
        self.assertEqual(stored[0], "event-1")
        self.assertEqual(json.loads(stored[1])["trackTitle"], "Night Drive")
        self.assertEqual(len(list(self.settings.imports_dir.glob("*.json"))), 1)

    def test_invalid_json_is_recorded_without_events(self):
        response = self.upload(b"{not-json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["newCount"], 0)
        self.assertEqual(response.json()["errorCount"], 1)
        history = self.client.get("/api/imports").json()["imports"]
        self.assertEqual(history[0]["errorCount"], 1)

    def test_duplicate_import_is_ignored(self):
        self.upload(document([event()]))
        response = self.upload(document([event()]))
        self.assertEqual(response.json()["newCount"], 0)
        self.assertEqual(response.json()["duplicateCount"], 1)
        connection = sqlite3.connect(self.settings.database_path)
        try:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM playback_events").fetchone()[0], 1)
        finally:
            connection.close()

    def test_valid_and_invalid_events_are_counted_independently(self):
        invalid = event("event-bad", playDuration=-1)
        response = self.upload(document([event(), invalid]))
        self.assertEqual(response.json()["newCount"], 1)
        self.assertEqual(response.json()["errorCount"], 1)

    def test_library_import_is_detected_saved_and_updated(self):
        fingerprint = "a" * 64
        first = self.upload(
            library_document([library_track(audioFingerprint=fingerprint)]),
            "MyMusic-Library.json",
        ).json()
        self.assertEqual(first["dataKind"], "library")
        self.assertEqual(first["newCount"], 1)

        duplicate = self.upload(
            library_document([library_track(audioFingerprint=fingerprint)]),
            "MyMusic-Library.json",
        ).json()
        self.assertEqual(duplicate["duplicateCount"], 1)

        changed = self.upload(
            library_document([library_track(
                title="Night Drive Remastered", favorite=False, audioFingerprint=fingerprint
            )]),
            "MyMusic-Library.json",
        ).json()
        self.assertEqual(changed["updatedCount"], 1)
        connection = sqlite3.connect(self.settings.database_path)
        try:
            stored = connection.execute(
                """SELECT title, favorite, genre, audio_fingerprint
                   FROM library_tracks WHERE track_id = 'track-1'"""
            ).fetchone()
        finally:
            connection.close()
        self.assertEqual(stored, ("Night Drive Remastered", 0, "Electronic", fingerprint))

    def test_library_rejects_invalid_audio_fingerprint(self):
        result = self.upload(
            library_document([library_track(audioFingerprint="not-a-sha256")]),
            "MyMusic-Library.json",
        ).json()
        self.assertEqual(result["newCount"], 0)
        self.assertEqual(result["errorCount"], 1)

    def test_new_library_snapshot_hides_removed_tracks_without_deleting_raw_row(self):
        self.upload(library_document([
            library_track("track-1"),
            library_track("track-2", title="Removed Later"),
        ]), "MyMusic-Library.json")
        self.upload(library_document([library_track("track-1")]), "MyMusic-Library.json")

        tracks = self.client.get("/api/tracks?period=all").json()["tracks"]
        self.assertEqual([item["trackId"] for item in tracks], ["track-1"])
        connection = sqlite3.connect(self.settings.database_path)
        try:
            state = connection.execute(
                "SELECT is_present FROM library_tracks WHERE track_id = 'track-2'"
            ).fetchone()[0]
        finally:
            connection.close()
        self.assertEqual(state, 0)

    def test_preferences_import_is_detected_saved_updated_and_validated(self):
        payload = preferences_document([
            {"trackId": "track-1", "playbackPreference": 4},
            {"trackId": "track-bad", "playbackPreference": 11},
        ])
        first = self.upload(payload, "MyMusic-Playback-Preferences.json").json()
        self.assertEqual(first["dataKind"], "playback_preferences")
        self.assertEqual(first["newCount"], 1)
        self.assertEqual(first["errorCount"], 1)

        changed = self.upload(
            preferences_document([{"trackId": "track-1", "playbackPreference": -3}]),
            "MyMusic-Playback-Preferences.json",
        ).json()
        self.assertEqual(changed["updatedCount"], 1)
        connection = sqlite3.connect(self.settings.database_path)
        try:
            value = connection.execute(
                "SELECT playback_preference FROM playback_preferences WHERE track_id = 'track-1'"
            ).fetchone()[0]
        finally:
            connection.close()
        self.assertEqual(value, -3)

    def test_library_preferences_and_events_are_joined_by_track_id(self):
        self.upload(library_document([
            library_track(),
            library_track("track-unplayed", title="Never Played", favorite=False, playCount=0,
                          lastPlayedAt=None),
        ]), "MyMusic-Library.json")
        preference_payload = preferences_document([
            {"trackId": "track-1", "playbackPreference": 5, "favorite": False},
            {"trackId": "track-unplayed", "playbackPreference": 0, "favorite": True},
        ])
        preference_payload["schemaVersion"] = 2
        self.upload(preference_payload, "MyMusic-Playback-Preferences.json")
        self.upload(document([event()]), "MyMusic-Playback-Events.json")

        tracks = self.client.get("/api/tracks?period=all").json()["tracks"]
        by_id = {item["trackId"]: item for item in tracks}
        self.assertEqual(len(by_id), 2)
        self.assertEqual(by_id["track-1"]["playbackPreference"], 5)
        self.assertEqual(by_id["track-1"]["favorite"], 0)
        self.assertEqual(by_id["track-1"]["playCount"], 1)
        self.assertEqual(by_id["track-unplayed"]["playCount"], 0)
        self.assertIsNone(by_id["track-unplayed"]["lastPlayedAt"])

        dashboard = self.client.get("/api/dashboard?period=all").json()
        self.assertEqual(dashboard["metrics"]["library_count"], 2)
        self.assertEqual(dashboard["metrics"]["favorite_count"], 1)
        self.assertEqual(dashboard["metrics"]["rated_count"], 1)
        distribution = {item["label"]: item["value"] for item in dashboard["preferenceDistribution"]}
        self.assertEqual(distribution, {"Good": 1, "Neutral": 1})

    def test_dashboard_and_tracks_aggregate_events(self):
        payload = document([
            event("event-1", playDuration=200, completed=True, skipped=False),
            event("event-2", playDuration=20, completed=False, skipped=True),
            event("event-3", "track-2", trackTitle="Other", artist="Second", playDuration=100),
        ])
        self.upload(payload)
        dashboard = self.client.get("/api/dashboard?period=all").json()
        self.assertEqual(dashboard["metrics"]["play_count"], 3)
        self.assertEqual(dashboard["metrics"]["total_play_time"], 320)
        self.assertAlmostEqual(dashboard["metrics"]["skip_rate"], 100 / 3)
        tracks = self.client.get("/api/tracks?period=all&search=Night").json()["tracks"]
        self.assertEqual(len(tracks), 1)
        self.assertEqual(tracks[0]["playCount"], 2)

    def test_extended_source_jsons_are_imported_and_exposed(self):
        self.upload(library_document([library_track()]), "MyMusic-Library.json")
        feature = {
            "version": 1, "exportedAt": "2026-09-02T12:00:00Z", "tracks": [{
                "trackID": "track-1", "title": "Night Drive", "artist": "Example Artist",
                "sourceIdentity": {"relativePath": "Music/night.m4a", "fileSize": 123,
                    "duration": 210, "modificationDate": None, "contentHash": None,
                    "title": "Night Drive", "artist": "Example Artist", "album": "City Lights"},
                "analysisVersion": 2, "analyzedAt": "2026-09-01T12:00:00Z",
                "importedAt": "2026-09-02T12:00:00Z", "features": {"tempo": 120, "energy": .7}
            }]
        }
        volume = {"version": 1, "exportedAt": "2026-09-02T12:00:00Z", "isEnabled": True,
            "tracks": [{"trackID": "track-1", "title": "Night Drive", "artist": "Example Artist",
                "relativePath": "Music/night.m4a", "integratedLUFS": -14.2,
                "truePeakDBTP": -1.1, "normalizationGainDB": 0.0}]}
        playlist_track = library_track()
        playlists = {"version": 1, "playlists": [{"version": 1, "name": "Favorites",
            "playlistID": "playlist-1", "createdAt": "2026-09-01T12:00:00Z",
            "updatedAt": "2026-09-02T12:00:00Z", "kind": "regular", "tags": ["夜"],
            "tracks": [playlist_track]}]}
        equalizer = {"kind": "mymusic.equalizer", "version": 1,
            "equalizer": {"isEnabled": True, "preamp": -2, "bands": [{"frequency": 31, "gain": 1}]},
            "customPresets": [{"id": "preset-1", "name": "My EQ", "preamp": -2,
                "gains": [0, 1], "isBuiltIn": False}]}
        genres = {"kind": "mymusic.genre-display-presets", "version": 1,
            "presets": [{"id": "genre-1", "name": "Focus",
                "enabledGenreNames": ["Ambient"], "includesUnassignedGenreSetting": False}]}

        for name, payload, kind in [
            ("MyMusic-Track-Features.json", feature, "track_features"),
            ("MyMusic-Volume-Normalization.json", volume, "volume_normalization"),
            ("MyMusic-Playlists.json", playlists, "playlists"),
            ("MyMusic-Equalizer.json", equalizer, "equalizer"),
            ("MyMusic-Genre-Display-Presets.json", genres, "genre_presets"),
        ]:
            result = self.upload(payload, name).json()
            self.assertEqual(result["dataKind"], kind)
            self.assertGreater(result["newCount"], 0)
            self.assertEqual(result["errorCount"], 0)

        features_api = self.client.get("/api/sources/track_features").json()
        self.assertEqual(features_api["linkedCount"], 1)
        self.assertEqual(features_api["items"][0]["data"]["features"]["tempo"], 120)
        playlists_api = self.client.get("/api/sources/playlists").json()
        self.assertEqual(playlists_api["items"][0]["linkedTrackCount"], 1)
        self.assertEqual(self.client.get("/api/sources/equalizer").json()["count"], 2)
        self.assertEqual(self.client.get("/api/sources/genre_presets").json()["count"], 1)

    def test_extended_source_reimport_updates_without_duplicate_rows(self):
        base = {"version": 1, "exportedAt": "2026-09-02T12:00:00Z", "isEnabled": True,
            "tracks": [{"trackID": "track-1", "title": "A", "artist": "B",
                "relativePath": "a.m4a", "integratedLUFS": -14,
                "truePeakDBTP": -1, "normalizationGainDB": 0}]}
        self.upload(base, "MyMusic-Volume-Normalization.json")
        changed = json.loads(json.dumps(base))
        changed["tracks"][0]["normalizationGainDB"] = -1.5
        result = self.upload(changed, "MyMusic-Volume-Normalization.json").json()
        self.assertEqual(result["updatedCount"], 1)
        self.assertEqual(self.client.get("/api/sources/volume_normalization").json()["count"], 1)

    def test_api_rejects_bad_period_and_non_json_file(self):
        self.assertEqual(self.client.get("/api/dashboard?period=year").status_code, 422)
        response = self.client.post("/api/import", files={"file": ("history.txt", b"{}", "text/plain")})
        self.assertEqual(response.status_code, 415)

    def test_preference_edit_persists_and_export_round_trips_without_mutating_sources(self):
        track_id = str(uuid4())
        missing_id = str(uuid4())
        self.upload(library_document([library_track(track_id)]), "MyMusic-Library.json")
        self.upload(preferences_document([
            {"trackId": track_id, "playbackPreference": 1, "favorite": False},
            {"trackId": missing_id, "playbackPreference": -2, "favorite": True},
        ]), "MyMusic-Playback-Preferences.json")
        before_library = self._table_rows("library_tracks")
        before_events = self._table_rows("playback_events")

        response = self.client.put(
            f"/api/preferences/{track_id}",
            json={"playbackPreference": 6, "favorite": True},
        )
        self.assertEqual(response.status_code, 200)
        exported = self.client.get("/api/preferences/export")
        self.assertEqual(exported.status_code, 200)
        self.assertIn(
            'filename="MyMusic-Playback-Preferences.json"',
            exported.headers["content-disposition"],
        )
        payload = exported.json()
        self.assertEqual(payload["schemaVersion"], 2)
        self.assertEqual(payload["tracks"], [{
            "trackId": track_id, "playbackPreference": 6, "favorite": True,
        }])
        round_trip = self.upload(payload, "MyMusic-Playback-Preferences.json").json()
        self.assertEqual(round_trip["errorCount"], 0)
        self.assertEqual(self._table_rows("library_tracks"), before_library)
        self.assertEqual(self._table_rows("playback_events"), before_events)

        connection = sqlite3.connect(self.settings.database_path)
        try:
            saved = connection.execute(
                "SELECT playback_preference, favorite FROM playback_preferences WHERE track_id=?",
                (track_id,),
            ).fetchone()
        finally:
            connection.close()
        self.assertEqual(saved, (6, 1))

    def test_preference_edit_rejects_missing_row_and_invalid_values(self):
        self.assertEqual(self.client.put(
            "/api/preferences/missing",
            json={"playbackPreference": 0, "favorite": False},
        ).status_code, 404)
        self.assertEqual(self.client.put(
            "/api/preferences/missing",
            json={"playbackPreference": 11, "favorite": False},
        ).status_code, 422)

    def _table_rows(self, table):
        connection = sqlite3.connect(self.settings.database_path)
        try:
            return connection.execute(f"SELECT * FROM {table} ORDER BY 1").fetchall()
        finally:
            connection.close()


class DatabaseMigrationTests(unittest.TestCase):
    def test_existing_v0_import_history_gains_new_columns(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "analytics.sqlite3"
            connection = sqlite3.connect(path)
            try:
                connection.execute(
                    """CREATE TABLE import_runs (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        imported_at TEXT NOT NULL,
                        source_filename TEXT NOT NULL,
                        archived_filename TEXT,
                        new_count INTEGER NOT NULL DEFAULT 0,
                        duplicate_count INTEGER NOT NULL DEFAULT 0,
                        error_count INTEGER NOT NULL DEFAULT 0,
                        error_details TEXT NOT NULL DEFAULT '[]'
                    )"""
                )
                connection.commit()
            finally:
                connection.close()

            Database(path).initialize()
            connection = sqlite3.connect(path)
            try:
                columns = {row[1] for row in connection.execute("PRAGMA table_info(import_runs)")}
            finally:
                connection.close()
            self.assertIn("data_kind", columns)
            self.assertIn("updated_count", columns)
            connection = sqlite3.connect(path)
            try:
                library_columns = {
                    row[1] for row in connection.execute("PRAGMA table_info(library_tracks)")
                }
            finally:
                connection.close()
            self.assertIn("is_present", library_columns)
            self.assertIn("audio_fingerprint", library_columns)
            connection = sqlite3.connect(path)
            try:
                preference_columns = {
                    row[1] for row in connection.execute("PRAGMA table_info(playback_preferences)")
                }
            finally:
                connection.close()
            self.assertIn("favorite", preference_columns)


if __name__ == "__main__":
    unittest.main()
