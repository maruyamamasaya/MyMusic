from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator


SCHEMA = """
CREATE TABLE IF NOT EXISTS import_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    imported_at TEXT NOT NULL,
    source_filename TEXT NOT NULL,
    archived_filename TEXT,
    data_kind TEXT NOT NULL DEFAULT 'playback_events',
    new_count INTEGER NOT NULL DEFAULT 0,
    updated_count INTEGER NOT NULL DEFAULT 0,
    duplicate_count INTEGER NOT NULL DEFAULT 0,
    error_count INTEGER NOT NULL DEFAULT 0,
    error_details TEXT NOT NULL DEFAULT '[]'
);

CREATE TABLE IF NOT EXISTS playback_events (
    event_id TEXT PRIMARY KEY,
    track_id TEXT NOT NULL,
    track_title TEXT NOT NULL,
    artist TEXT NOT NULL,
    album TEXT,
    played_at TEXT NOT NULL,
    play_duration REAL NOT NULL CHECK (play_duration >= 0),
    track_duration REAL NOT NULL CHECK (track_duration >= 0),
    completed INTEGER NOT NULL CHECK (completed IN (0, 1)),
    skipped INTEGER NOT NULL CHECK (skipped IN (0, 1)),
    play_source TEXT NOT NULL,
    selection_type TEXT NOT NULL,
    session_id TEXT,
    platform TEXT NOT NULL,
    schema_version INTEGER NOT NULL,
    imported_at TEXT NOT NULL,
    import_id INTEGER NOT NULL,
    raw_json TEXT NOT NULL,
    FOREIGN KEY(import_id) REFERENCES import_runs(id)
);
CREATE INDEX IF NOT EXISTS idx_events_played_at ON playback_events(played_at);
CREATE INDEX IF NOT EXISTS idx_events_track ON playback_events(track_id, played_at);
CREATE INDEX IF NOT EXISTS idx_events_artist ON playback_events(artist, played_at);

CREATE TABLE IF NOT EXISTS library_tracks (
    track_id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    artist TEXT NOT NULL,
    album TEXT,
    genre TEXT,
    year INTEGER,
    duration REAL NOT NULL CHECK (duration >= 0),
    format TEXT,
    favorite INTEGER CHECK (favorite IS NULL OR favorite IN (0, 1)),
    source_play_count INTEGER,
    source_last_played_at TEXT,
    audio_fingerprint TEXT,
    is_present INTEGER NOT NULL DEFAULT 1 CHECK (is_present IN (0, 1)),
    imported_at TEXT NOT NULL,
    import_id INTEGER NOT NULL,
    raw_json TEXT NOT NULL,
    FOREIGN KEY(import_id) REFERENCES import_runs(id)
);
CREATE INDEX IF NOT EXISTS idx_library_artist ON library_tracks(artist);
CREATE INDEX IF NOT EXISTS idx_library_album ON library_tracks(album);

CREATE TABLE IF NOT EXISTS playback_preferences (
    track_id TEXT PRIMARY KEY,
    playback_preference INTEGER NOT NULL CHECK (playback_preference BETWEEN -10 AND 10),
    favorite INTEGER CHECK (favorite IS NULL OR favorite IN (0, 1)),
    exported_at TEXT NOT NULL,
    imported_at TEXT NOT NULL,
    import_id INTEGER NOT NULL,
    raw_json TEXT NOT NULL,
    FOREIGN KEY(import_id) REFERENCES import_runs(id)
);

CREATE TABLE IF NOT EXISTS source_records (
    data_kind TEXT NOT NULL,
    item_key TEXT NOT NULL,
    track_id TEXT,
    title TEXT NOT NULL,
    subtitle TEXT,
    imported_at TEXT NOT NULL,
    import_id INTEGER NOT NULL,
    raw_json TEXT NOT NULL,
    PRIMARY KEY(data_kind, item_key),
    FOREIGN KEY(import_id) REFERENCES import_runs(id)
);
CREATE INDEX IF NOT EXISTS idx_source_records_track ON source_records(track_id);
CREATE INDEX IF NOT EXISTS idx_source_records_kind ON source_records(data_kind, title);
"""


class Database:
    def __init__(self, path: Path):
        self.path = Path(path)

    def initialize(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as connection:
            connection.executescript(SCHEMA)
            columns = {row[1] for row in connection.execute("PRAGMA table_info(import_runs)")}
            if "data_kind" not in columns:
                connection.execute(
                    "ALTER TABLE import_runs ADD COLUMN data_kind TEXT NOT NULL DEFAULT 'playback_events'"
                )
            if "updated_count" not in columns:
                connection.execute(
                    "ALTER TABLE import_runs ADD COLUMN updated_count INTEGER NOT NULL DEFAULT 0"
                )
            library_columns = {row[1] for row in connection.execute("PRAGMA table_info(library_tracks)")}
            if "is_present" not in library_columns:
                connection.execute(
                    "ALTER TABLE library_tracks ADD COLUMN is_present INTEGER NOT NULL DEFAULT 1"
                )
            if "audio_fingerprint" not in library_columns:
                connection.execute(
                    "ALTER TABLE library_tracks ADD COLUMN audio_fingerprint TEXT"
                )
            preference_columns = {row[1] for row in connection.execute("PRAGMA table_info(playback_preferences)")}
            if "favorite" not in preference_columns:
                connection.execute("ALTER TABLE playback_preferences ADD COLUMN favorite INTEGER")
            connection.execute(
                "CREATE INDEX IF NOT EXISTS idx_library_fingerprint ON library_tracks(audio_fingerprint)"
            )

    @contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        connection = sqlite3.connect(self.path, timeout=10)
        connection.row_factory = sqlite3.Row
        connection.create_function(
            "normalize_genre_delimiters", 1,
            lambda value: (value or "").replace("\0", ";"),
            deterministic=True,
        )
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA journal_mode = WAL")
        connection.execute("PRAGMA busy_timeout = 5000")
        try:
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()
