from __future__ import annotations

import json
import sqlite3
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
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

    def test_music_history_and_period_rankings(self):
        self.upload(library_document([
            library_track("track-1", title="Night", artist="First", album="Moon", genre="Rock"),
            library_track("track-2", title="Day", artist="Second", album="Sun", genre="Pop"),
        ]), "MyMusic-Library.json")
        self.upload(document([
            event("aug-1", trackTitle="Night", artist="First", album="Moon",
                  playedAt="2026-08-31T12:00:00+09:00", playDuration=40),
            event("sep-1", trackTitle="Night", artist="First", album="Moon",
                  playedAt="2026-09-01T12:00:00+09:00", playDuration=100),
            event("sep-2", trackTitle="Night", artist="First", album="Moon",
                  playedAt="2026-09-02T12:00:00+09:00", playDuration=120),
            event("sep-3", "track-2", trackTitle="Day", artist="Second", album="Sun",
                  playedAt="2026-09-02T13:00:00+09:00", playDuration=60),
        ]))

        history = self.client.get("/api/music-history").json()["months"]
        self.assertEqual([item["month"] for item in history], ["2026-09", "2026-08"])
        self.assertEqual(history[0]["playCount"], 3)
        self.assertEqual(history[0]["totalPlayTime"], 280)
        self.assertEqual(history[0]["topTrack"]["title"], "Night")
        self.assertEqual(history[1]["detailEventCount"], 0)

        tracks = self.client.get(
            "/api/rankings?period=custom&startDate=2026-09-01&endDate=2026-09-02"
            "&dimension=tracks&metric=plays"
        ).json()["items"]
        self.assertEqual([(item["label"], item["value"]) for item in tracks],
                         [("Night", 2), ("Day", 1)])
        genres = self.client.get(
            "/api/rankings?period=all&dimension=genres&metric=duration"
        ).json()["items"]
        self.assertEqual([(item["label"], item["value"]) for item in genres],
                         [("Rock", 220), ("Pop", 60)])
        self.assertEqual(self.client.get(
            "/api/rankings?period=all&dimension=composers&metric=plays"
        ).status_code, 422)

    def test_dashboard_custom_period_and_legacy_detail_metrics(self):
        self.upload(document([
            event("legacy", playedAt="2026-08-31T10:00:00+09:00", playDuration=0,
                  completed=False, skipped=False),
            event("current", playedAt="2026-09-01T10:00:00+09:00", playDuration=90,
                  completed=True, skipped=False),
        ]))
        crossing = self.client.get(
            "/api/dashboard?period=custom&startDate=2026-08-31&endDate=2026-09-01"
        ).json()
        self.assertEqual(crossing["metrics"]["play_count"], 2)
        self.assertEqual(crossing["metrics"]["detail_event_count"], 1)
        self.assertEqual(crossing["metrics"]["total_play_time"], 90)
        self.assertEqual(crossing["metrics"]["completion_rate"], 100)
        legacy = self.client.get(
            "/api/dashboard?period=custom&startDate=2026-08-31&endDate=2026-08-31"
        ).json()["metrics"]
        self.assertEqual(legacy["play_count"], 1)
        self.assertIsNone(legacy["total_play_time"])
        self.assertIsNone(legacy["completion_rate"])
        self.assertEqual(self.client.get(
            "/api/dashboard?period=custom&startDate=2026-09-02&endDate=2026-09-01"
        ).status_code, 422)

    def test_today_and_dashboard_buckets_use_japan_time(self):
        japan = timezone(timedelta(hours=9))
        today = datetime.now(japan).date()
        today_at_midnight = datetime.combine(today, datetime.min.time(), japan)
        self.upload(document([
            event("today-early", playedAt=(today_at_midnight + timedelta(minutes=30))
                  .astimezone(timezone.utc).isoformat()),
            event("yesterday-late", playedAt=(today_at_midnight - timedelta(minutes=1))
                  .astimezone(timezone.utc).isoformat()),
        ]))

        dashboard = self.client.get("/api/dashboard?period=today").json()
        self.assertEqual(dashboard["metrics"]["play_count"], 1)
        self.assertEqual(dashboard["daily"], [{"label": today.isoformat(), "value": 1}])
        self.assertEqual(dashboard["hourly"], [{"label": 0, "value": 1}])
        custom = self.client.get(
            f"/api/dashboard?period=custom&startDate={today}&endDate={today}"
        ).json()
        self.assertEqual(custom["metrics"]["play_count"], 1)

    def test_tracks_periods_custom_dates_and_unplayed_library_tracks(self):
        now = datetime.now(timezone(timedelta(hours=9)))
        dates = [now, now - timedelta(days=10), now - timedelta(days=40)]
        self.upload(library_document([
            library_track("track-1"),
            library_track("track-unplayed", title="Never Played", artist="Quiet Artist"),
        ]), "MyMusic-Library.json")
        self.upload(document([
            event(f"event-{index}", playedAt=value.isoformat(), playDuration=10 * index,
                  completed=index == 1, skipped=index == 2)
            for index, value in enumerate(dates, 1)
        ]))

        self.assertEqual(self.client.get("/api/tracks?period=7d").json()["tracks"][0]["playCount"], 1)
        self.assertEqual(self.client.get("/api/tracks?period=30d").json()["tracks"][0]["playCount"], 2)
        self.assertEqual(self.client.get("/api/tracks?period=all").json()["tracks"][0]["playCount"], 3)
        day = dates[1].date().isoformat()
        custom = self.client.get(
            f"/api/tracks?period=custom&startDate={day}&endDate={day}"
        ).json()["tracks"]
        by_id = {item["trackId"]: item for item in custom}
        self.assertEqual(by_id["track-1"]["playCount"], 1)
        self.assertIsNone(by_id["track-1"]["totalPlayTime"])
        self.assertIsNone(by_id["track-1"]["skipRate"])
        self.assertIsNone(by_id["track-unplayed"]["lastPlayedAt"])
        self.assertEqual(self.client.get(
            "/api/tracks?period=custom&startDate=2026-09-02&endDate=2026-09-01"
        ).status_code, 422)
        self.assertEqual(self.client.get("/api/tracks?period=custom").status_code, 422)

    def test_tracks_field_filters_are_partial_and_combined_with_and(self):
        self.upload(library_document([
            library_track("one", title="Brave Shine", artist="Aimer", album="Sun Dance", genre="Rock"),
            library_track("two", title="Sunset", artist="Aimer", album="Other", genre="Pop"),
            library_track("three", title="Brave", artist="Other", album="Sun Dance", genre="Rock"),
        ]), "MyMusic-Library.json")
        cases = {
            "title=Shine": ["one"], "artist=aimer": ["one", "two"],
            "album=Sun%20Dan": ["one", "three"], "genre=rock": ["one", "three"],
            "artist=Aimer&album=Sun%20Dance&genre=Rock": ["one"],
        }
        for query, expected in cases.items():
            with self.subTest(query=query):
                rows = self.client.get(f"/api/tracks?period=all&{query}").json()["tracks"]
                self.assertEqual(sorted(row["trackId"] for row in rows), expected)

    def test_tracks_are_paginated_at_two_hundred_rows(self):
        self.upload(library_document([
            library_track(f"track-{index:03}", title=f"Track {index:03}")
            for index in range(201)
        ]), "MyMusic-Library.json")
        first = self.client.get("/api/tracks?period=all&sort=title&order=asc").json()
        second = self.client.get("/api/tracks?period=all&sort=title&order=asc&page=2").json()
        self.assertEqual((first["total"], first["pageSize"], len(first["tracks"])), (201, 200, 200))
        self.assertEqual((second["page"], len(second["tracks"])), (2, 1))
        self.assertEqual(second["tracks"][0]["trackId"], "track-200")

    def test_tracks_all_allowed_sorts_and_orders(self):
        self.upload(library_document([
            library_track("one", title="Alpha", artist="Zulu", album="Beta"),
            library_track("two", title="Beta", artist="Alpha", album="Alpha"),
        ]), "MyMusic-Library.json")
        self.upload(preferences_document([
            {"trackId": "one", "playbackPreference": 5},
            {"trackId": "two", "playbackPreference": -2},
        ]), "MyMusic-Playback-Preferences.json")
        self.upload(document([
            event("one-a", "one", trackTitle="Alpha", artist="Zulu", album="Beta",
                  playedAt="2026-09-01T10:00:00+09:00", playDuration=100,
                  completed=True, skipped=False),
            event("one-b", "one", trackTitle="Alpha", artist="Zulu", album="Beta",
                  playedAt="2026-09-02T10:00:00+09:00", playDuration=50,
                  completed=False, skipped=True),
            event("two-a", "two", trackTitle="Beta", artist="Alpha", album="Alpha",
                  playedAt="2026-09-03T10:00:00+09:00", playDuration=25,
                  completed=False, skipped=False),
        ]))
        sorts = ["title", "artist", "album", "preference", "playCount", "totalPlayTime",
                 "completionRate", "skipRate", "lastPlayedAt"]
        for sort in sorts:
            asc = self.client.get(f"/api/tracks?period=all&sort={sort}&order=asc")
            desc = self.client.get(f"/api/tracks?period=all&sort={sort}&order=desc")
            with self.subTest(sort=sort):
                self.assertEqual(asc.status_code, 200)
                self.assertEqual(desc.status_code, 200)
                self.assertNotEqual(asc.json()["tracks"][0]["trackId"], desc.json()["tracks"][0]["trackId"])
        combined = self.client.get(
            "/api/tracks?period=custom&startDate=2026-09-01&endDate=2026-09-02"
            "&artist=Zulu&sort=totalPlayTime&order=desc"
        ).json()["tracks"]
        self.assertEqual([(row["trackId"], row["playCount"]) for row in combined], [("one", 2)])
        self.assertEqual(self.client.get("/api/tracks?sort=drop_table").status_code, 422)
        self.assertEqual(self.client.get("/api/tracks?order=sideways").status_code, 422)

    def test_legacy_events_count_plays_but_do_not_supply_detail_metrics(self):
        self.upload(library_document([library_track()]), "MyMusic-Library.json")
        self.upload(document([
            event("legacy-1", playedAt="2026-08-20T10:00:00+09:00", playDuration=0,
                  trackDuration=0, completed=False, skipped=False),
            event("legacy-2", playedAt="2026-08-31T23:59:59+09:00", playDuration=0,
                  trackDuration=0, completed=False, skipped=False),
            event("current-1", playedAt="2026-09-01T00:00:00+09:00", playDuration=120,
                  completed=True, skipped=False),
            event("current-2", playedAt="2026-09-02T10:00:00+09:00", playDuration=30,
                  completed=False, skipped=True),
        ]))

        legacy_only = self.client.get(
            "/api/tracks?period=custom&startDate=2026-08-01&endDate=2026-08-31"
        ).json()["tracks"][0]
        self.assertEqual(legacy_only["playCount"], 2)
        self.assertEqual(legacy_only["detailEventCount"], 0)
        self.assertIsNone(legacy_only["totalPlayTime"])
        self.assertIsNone(legacy_only["completionRate"])
        self.assertIsNone(legacy_only["skipRate"])
        self.assertIsNone(legacy_only["lastPlayedAt"])

        crossing = self.client.get(
            "/api/tracks?period=custom&startDate=2026-08-01&endDate=2026-09-30"
        ).json()["tracks"][0]
        self.assertEqual(crossing["playCount"], 4)
        self.assertEqual(crossing["detailEventCount"], 2)
        self.assertEqual(crossing["totalPlayTime"], 150)
        self.assertEqual(crossing["completionRate"], 50)
        self.assertEqual(crossing["skipRate"], 50)
        self.assertIn("2026-09-02", crossing["lastPlayedAt"])

        current_only = self.client.get(
            "/api/tracks?period=custom&startDate=2026-09-01&endDate=2026-09-30"
        ).json()["tracks"][0]
        self.assertEqual(current_only["playCount"], 2)
        self.assertEqual(current_only["detailEventCount"], 2)
        self.assertEqual(current_only["totalPlayTime"], 150)

    def test_early_skip_boundaries_cutoff_periods_and_track_sorts(self):
        self.upload(document([
            event("ten", "one", trackTitle="Alpha", playedAt="2026-09-01T10:00:00+09:00", playDuration=10, completed=False, skipped=True),
            event("thirty", "one", trackTitle="Alpha", playedAt="2026-09-02T10:00:00+09:00", playDuration=30, completed=False, skipped=True),
            event("thirty-one", "one", trackTitle="Alpha", playedAt="2026-09-02T11:00:00+09:00", playDuration=31, completed=False, skipped=True),
            event("completed", "one", trackTitle="Alpha", playedAt="2026-09-02T12:00:00+09:00", playDuration=20, completed=True, skipped=False),
            event("legacy", "one", trackTitle="Alpha", playedAt="2026-08-31T12:00:00+09:00", playDuration=10, completed=False, skipped=True),
            event("other-early", "two", trackTitle="Beta", playedAt="2026-09-02T13:00:00+09:00", playDuration=15, completed=False, skipped=True),
            event("other-full", "two", trackTitle="Beta", playedAt="2026-09-02T14:00:00+09:00", playDuration=100, completed=True, skipped=False),
            event("legacy-only", "legacy-only", trackTitle="Legacy", playedAt="2026-08-30T12:00:00+09:00", playDuration=5, completed=False, skipped=True),
        ]))
        dashboard = self.client.get("/api/dashboard?period=custom&startDate=2026-08-01&endDate=2026-09-30").json()
        self.assertEqual((dashboard["metrics"]["early_skip_count"], dashboard["metrics"]["early_skip_rate"]), (3, 50))
        ranking = dashboard["earlySkippedTracks"]
        self.assertEqual((ranking[0]["trackId"], ranking[0]["earlySkipCount"], ranking[0]["totalPlayCount"], ranking[0]["earlySkipRate"]), ("one", 2, 5, 50))
        september = self.client.get("/api/tracks?period=custom&startDate=2026-09-01&endDate=2026-09-30").json()["tracks"]
        by_id = {item["trackId"]: item for item in september}
        self.assertEqual((by_id["one"]["playCount"], by_id["one"]["earlySkipCount"], by_id["one"]["earlySkipRate"]), (4, 2, 50))
        legacy = self.client.get("/api/tracks?period=custom&startDate=2026-08-01&endDate=2026-08-31").json()["tracks"]
        legacy_by_id = {item["trackId"]: item for item in legacy}
        self.assertEqual(legacy_by_id["legacy-only"]["earlySkipCount"], 0)
        self.assertIsNone(legacy_by_id["legacy-only"]["earlySkipRate"])
        for sort in ("earlySkipCount", "earlySkipRate"):
            asc = self.client.get(f"/api/tracks?period=all&sort={sort}&order=asc").json()["tracks"]
            desc = self.client.get(f"/api/tracks?period=all&sort={sort}&order=desc").json()["tracks"]
            with self.subTest(sort=sort):
                self.assertNotEqual(asc[0]["trackId"], desc[0]["trackId"])
        one_day = self.client.get("/api/dashboard?period=custom&startDate=2026-09-01&endDate=2026-09-01").json()["metrics"]
        self.assertEqual((one_day["early_skip_count"], one_day["early_skip_rate"]), (1, 100))

    def test_insights_group_unknown_sources_types_cutoff_and_period(self):
        self.upload(document([
            event("legacy", playedAt="2026-08-31T10:00:00+09:00", playDuration=10,
                  completed=False, skipped=True, playSource="surprise_radio",
                  selectionType="contextual"),
            event("early", playedAt="2026-09-01T10:00:00+09:00", playDuration=10,
                  completed=False, skipped=True, playSource="surprise_radio",
                  selectionType="contextual"),
            event("long-skip", playedAt="2026-09-02T10:00:00+09:00", playDuration=31,
                  completed=False, skipped=True, playSource="surprise_radio",
                  selectionType="automatic_v2"),
            event("complete", playedAt="2026-09-02T11:00:00+09:00", playDuration=100,
                  completed=True, skipped=False, playSource="playlist",
                  selectionType="automatic_v2"),
            event("unknown-current", playedAt="2026-09-02T12:00:00+09:00", playDuration=80,
                  completed=True, skipped=False, playSource="unknown",
                  selectionType="unknown"),
            event("legacy-only", playedAt="2026-08-30T10:00:00+09:00", playDuration=5,
                  completed=False, skipped=True, playSource="legacy_source",
                  selectionType="legacy_type"),
        ]))

        payload = self.client.get(
            "/api/insights?period=custom&startDate=2026-08-01&endDate=2026-09-30&quality=all"
        ).json()
        self.assertEqual(payload["quality"], "all")
        sources = {row["playSource"]: row for row in payload["byPlaySource"]}
        radio = sources["surprise_radio"]
        self.assertEqual(radio["playCount"], 3)
        self.assertEqual(radio["totalPlayTime"], 41)
        self.assertEqual((radio["completionRate"], radio["skipRate"]), (0, 100))
        self.assertEqual((radio["earlySkipCount"], radio["earlySkipRate"]), (1, 50))
        self.assertIn("unknown", sources)
        self.assertEqual(sources["legacy_source"]["playCount"], 1)
        self.assertIsNone(sources["legacy_source"]["totalPlayTime"])
        self.assertIsNone(sources["legacy_source"]["completionRate"])
        self.assertIsNone(sources["legacy_source"]["skipRate"])
        self.assertIsNone(sources["legacy_source"]["earlySkipCount"])
        self.assertIsNone(sources["legacy_source"]["earlySkipRate"])
        selections = {row["selectionType"]: row for row in payload["bySelectionType"]}
        self.assertEqual(selections["contextual"]["playCount"], 2)
        self.assertEqual(selections["contextual"]["detailEventCount"], 1)
        combinations = {(row["playSource"], row["selectionType"]): row
                        for row in payload["combinations"]}
        self.assertEqual(combinations[("playlist", "automatic_v2")]["completionRate"], 100)
        self.assertEqual(combinations[("surprise_radio", "automatic_v2")]["earlySkipCount"], 0)

        one_day = self.client.get(
            "/api/insights?period=custom&startDate=2026-09-02&endDate=2026-09-02"
        ).json()
        self.assertEqual(one_day["quality"], "analyzable")
        self.assertEqual(sum(row["playCount"] for row in one_day["byPlaySource"]), 3)
        self.assertIn("unknown", {row["playSource"] for row in one_day["byPlaySource"]})
        analyzable = self.client.get(
            "/api/insights?period=custom&startDate=2026-08-01&endDate=2026-09-30"
        ).json()
        self.assertEqual(sum(row["playCount"] for row in analyzable["byPlaySource"]), 4)
        self.assertNotIn("legacy_source", {row["playSource"] for row in analyzable["byPlaySource"]})
        self.assertEqual(self.client.get("/api/insights?period=year").status_code, 422)
        self.assertEqual(self.client.get("/api/insights?quality=trustedish").status_code, 422)

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

    def test_feature_insights_ranges_join_quality_version_and_invalid_values(self):
        def feature_track(track_id, version, features):
            return {
                "trackID": track_id, "title": track_id, "artist": "Artist",
                "sourceIdentity": {"relativePath": f"{track_id}.m4a", "fileSize": 1,
                    "duration": 100, "modificationDate": None, "contentHash": None,
                    "title": track_id, "artist": "Artist", "album": None},
                "analysisVersion": version, "analyzedAt": "2026-09-02T00:00:00Z",
                "importedAt": "2026-09-02T00:00:00Z", "features": features,
            }

        feature_names = ["dark", "calm", "aggressive", "piano", "electronic",
                         "ambient", "drumAndBass", "vocal", "instrumental"]
        tracks = []
        for track_id, score in (("zero", 0.0), ("two", 0.2), ("four", 0.4),
                                ("six", 0.6), ("eight", 0.8), ("one", 1.0)):
            tracks.append(feature_track(track_id, 2, {name: score for name in feature_names}))
        tracks.extend([
            feature_track("missing", 2, {"calm": 0.5}),
            feature_track("negative", 2, {"dark": -0.1}),
            feature_track("too-high", 2, {"dark": 1.1}),
            feature_track("not-number", 2, {"dark": "0.5"}),
            feature_track("old-version", 1, {"dark": 0.9}),
        ])
        self.upload({"version": 1, "exportedAt": "2026-09-02T00:00:00Z",
                     "tracks": tracks}, "MyMusic-Track-Features.json")
        self.upload(document([
            event("zero-current", "zero", playedAt="2026-09-01T10:00:00+09:00",
                  completed=True, skipped=False, playDuration=80),
            event("two-current", "two", playedAt="2026-09-01T11:00:00+09:00",
                  completed=False, skipped=True, playDuration=10),
            event("four-current", "four", playedAt="2026-09-01T12:00:00+09:00",
                  completed=False, skipped=True, playDuration=31),
            event("six-current", "six", playedAt="2026-09-02T10:00:00+09:00",
                  completed=False, skipped=False, playDuration=50),
            event("eight-current", "eight", playedAt="2026-09-02T11:00:00+09:00",
                  completed=True, skipped=False, playDuration=90),
            event("one-current", "one", playedAt="2026-09-02T12:00:00+09:00",
                  completed=False, skipped=True, playDuration=30),
            event("zero-legacy", "zero", playedAt="2026-08-31T10:00:00+09:00",
                  completed=False, skipped=True, playDuration=5),
            event("old-version-event", "old-version", playedAt="2026-09-02T13:00:00+09:00"),
            event("unmatched", "no-features", playedAt="2026-09-02T14:00:00+09:00"),
        ]))

        result = self.client.get(
            "/api/insights/features?period=all&quality=analyzable&feature=dark"
        ).json()
        self.assertEqual(result["analysisVersion"], 2)
        self.assertEqual([row["trackCount"] for row in result["bins"]], [1, 1, 1, 1, 2])
        self.assertEqual([row["playCount"] for row in result["bins"]], [1, 1, 1, 1, 2])
        self.assertEqual(result["bins"][0]["completionRate"], 100)
        self.assertEqual(result["bins"][1]["skipRate"], 100)
        self.assertEqual(result["bins"][1]["earlySkipRate"], 100)
        self.assertEqual(result["bins"][2]["earlySkipRate"], 0)
        self.assertEqual(result["bins"][4]["earlySkipRate"], 50)

        all_data = self.client.get(
            "/api/insights/features?period=all&quality=all&feature=dark"
        ).json()
        self.assertEqual(all_data["bins"][0]["playCount"], 2)
        self.assertEqual(all_data["bins"][0]["completionRate"], 100)
        custom = self.client.get(
            "/api/insights/features?period=custom&startDate=2026-09-02&endDate=2026-09-02"
            "&quality=analyzable&feature=dark"
        ).json()
        self.assertEqual([row["playCount"] for row in custom["bins"]], [0, 0, 0, 1, 2])
        self.assertIsNone(custom["bins"][0]["completionRate"])
        self.assertIsNone(custom["bins"][0]["skipRate"])
        self.assertIsNone(custom["bins"][0]["earlySkipRate"])
        for feature in feature_names:
            with self.subTest(feature=feature):
                response = self.client.get(
                    f"/api/insights/features?period=all&quality=analyzable&feature={feature}"
                )
                self.assertEqual(response.status_code, 200)
                self.assertEqual(len(response.json()["bins"]), 5)
        self.assertEqual(self.client.get(
            "/api/insights/features?feature=bright"
        ).status_code, 422)

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

    def test_recent_changes_advanced_insights_and_recommendations(self):
        feature_names = ["dark", "calm", "aggressive", "piano", "electronic",
                         "ambient", "drumAndBass", "vocal", "instrumental"]
        track_ids = ["hook", "bored", "rediscover", "taste", "favorite", "unplayed",
                     "overplayed", "insufficient"]
        self.upload(library_document([
            library_track(track_id, title=track_id.title(), artist=("Hook Artist" if track_id == "hook" else "Other Artist"),
                          album=("Rise" if track_id == "hook" else "Other"), genre=("Rock" if track_id == "hook" else "Pop"), favorite=False)
            for track_id in track_ids
        ]), "MyMusic-Library.json")
        self.upload(preferences_document([
            {"trackId": "favorite", "playbackPreference": 5, "favorite": True},
        ]), "MyMusic-Playback-Preferences.json")

        feature_tracks = []
        for track_id in track_ids:
            scores = {name: 0.1 for name in feature_names}
            if track_id in {"taste", "favorite", "unplayed", "overplayed"}:
                scores["calm"] = {"taste": .9, "favorite": .8,
                                  "unplayed": .9, "overplayed": 1.0}[track_id]
            feature_tracks.append({
                "trackID": track_id, "title": track_id, "artist": "Artist",
                "sourceIdentity": {"relativePath": f"{track_id}.m4a", "fileSize": 1,
                    "duration": 100, "modificationDate": None, "contentHash": None,
                    "title": track_id, "artist": "Artist", "album": None},
                "analysisVersion": 2, "analyzedAt": "2026-09-14T00:00:00Z",
                "importedAt": "2026-09-14T00:00:00Z", "features": scores,
            })
        self.upload({"version": 1, "exportedAt": "2026-09-14T00:00:00Z",
                     "tracks": feature_tracks}, "MyMusic-Track-Features.json")

        events = []
        def add_many(prefix, track_id, dates, completed, skipped, duration,
                     artist="Other Artist", album="Other"):
            for index, played_at in enumerate(dates):
                events.append(event(f"{prefix}-{index}", track_id, trackTitle=track_id.title(),
                                    artist=artist, album=album, playedAt=played_at,
                                    completed=completed, skipped=skipped,
                                    playDuration=duration))
        baseline = [f"2026-09-0{day}T06:00:00+09:00" for day in (1, 2, 3)]
        recent = [f"2026-09-{day:02}T06:00:00+09:00" for day in (8, 9, 10)]
        add_many("taste-old", "taste", baseline, False, True, 10)
        add_many("taste-new", "taste", recent, True, False, 90)
        add_many("bored-old", "bored", baseline, True, False, 90)
        add_many("bored-new", "bored", recent, False, True, 10)
        add_many("rediscover", "rediscover", baseline, True, False, 90)
        add_many("hook-new", "hook", recent + ["2026-09-11T06:00:00+09:00"],
                 True, False, 90, "Hook Artist", "Rise")
        add_many("hook-old", "hook", ["2026-09-01T07:00:00+09:00"],
                 True, False, 90, "Hook Artist", "Rise")
        add_many("overplayed", "overplayed",
                 recent + [f"2026-09-{day:02}T07:00:00+09:00" for day in (11, 12, 13, 14)],
                 True, False, 90)
        add_many("insufficient", "insufficient", ["2026-09-10T06:00:00+09:00"],
                 True, False, 90)
        events.append(event("legacy-noise", "insufficient",
                            playedAt="2026-08-20T06:00:00+09:00",
                            completed=False, skipped=True, playDuration=5))
        self.upload(document(events))

        query = "period=custom&startDate=2026-09-08&endDate=2026-09-14&quality=analyzable"
        changes = self.client.get(f"/api/insights/recent-changes?{query}").json()
        self.assertIn("hook", {row["trackId"] for row in changes["hookedTracks"]})
        self.assertIn("bored", {row["trackId"] for row in changes["boredTracks"]})
        self.assertIn("rediscover", {row["trackId"] for row in changes["rediscoveryTracks"]})
        self.assertIn("calm", {row["feature"] for row in changes["newTastes"]})
        self.assertNotIn("insufficient", {row["trackId"] for row in changes["hookedTracks"]})

        advanced = self.client.get(f"/api/insights/advanced?{query}").json()
        morning_calm = next(row for row in advanced["timeFeatureAffinity"]
                            if row["timeBand"] == "朝" and row["feature"] == "calm")
        self.assertTrue(morning_calm["isReliable"])
        profile = {row["feature"]: row for row in advanced["listeningProfile"]}
        self.assertEqual(profile["calm"]["level"], "強いプラス傾向")
        self.assertEqual(profile["dark"]["level"], "データ不足")
        self.assertTrue(advanced["entityChanges"]["artists"])

        recommendations = self.client.get(f"/api/insights/recommendations?{query}").json()
        self.assertEqual(recommendations["recommendations"][0]["trackId"], "favorite")
        overplayed_rank = next(index for index, row in enumerate(recommendations["recommendations"])
                               if row["trackId"] == "overplayed")
        self.assertGreater(overplayed_rank, 0)
        unplayed = next(row for row in recommendations["lowPlayDiscoveries"]
                        if row["trackId"] == "unplayed")
        self.assertEqual(unplayed["playCount"], 0)
        self.assertIsNone(unplayed["completionRate"])
        self.assertLessEqual(len(recommendations["insightCards"]), 5)
        self.assertFalse(any(card.get("trackId") == "insufficient"
                             for card in recommendations["insightCards"]))

    def test_data_sources_are_paginated_at_two_hundred_rows(self):
        payload = {
            "version": 1, "exportedAt": "2026-09-02T12:00:00Z", "isEnabled": True,
            "tracks": [{
                "trackID": f"track-{index:03}", "title": f"Track {index:03}",
                "artist": "Artist", "relativePath": f"music/{index}.m4a",
                "integratedLUFS": -14, "truePeakDBTP": -1, "normalizationGainDB": 0,
            } for index in range(201)],
        }
        self.upload(payload, "MyMusic-Volume-Normalization.json")
        first = self.client.get("/api/sources/volume_normalization").json()
        second = self.client.get("/api/sources/volume_normalization?page=2").json()
        self.assertEqual((first["count"], first["pageSize"], len(first["items"])), (201, 200, 200))
        self.assertEqual((second["page"], len(second["items"])), (2, 1))
        descending = self.client.get(
            "/api/sources/volume_normalization?sort=title&order=desc"
        ).json()["items"]
        self.assertEqual(descending[0]["title"], "Track 200")
        self.assertEqual(self.client.get(
            "/api/sources/volume_normalization?sort=unknown"
        ).status_code, 404)

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
