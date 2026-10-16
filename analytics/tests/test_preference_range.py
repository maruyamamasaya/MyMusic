import sqlite3
import tempfile
import unittest
from pathlib import Path
from app.database import Database, SCHEMA
from importer.schema import PlaybackPreferenceUpdate


class PreferenceRangeMigrationTests(unittest.TestCase):
    def test_old_database_preserves_all_columns_and_accepts_fifteen(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'old.sqlite3'
            with sqlite3.connect(path) as db:
                db.executescript(SCHEMA.replace('BETWEEN -10 AND 15', 'BETWEEN -10 AND 10'))
                # No live music or user database is involved.
                db.execute("INSERT INTO import_runs(id,imported_at,source_filename) VALUES(123,'imported','fixture.json')")
                db.execute("INSERT INTO playback_preferences VALUES (?,?,?,?,?,?,?)",
                           ('song', 10, 1, 'exported', 'imported', 123, '{"original":true}'))
                before = db.execute('SELECT * FROM playback_preferences').fetchall()
            database = Database(path)
            database.initialize()
            with database.connect() as db:
                self.assertEqual([tuple(r) for r in db.execute('SELECT * FROM playback_preferences')], before)
                db.execute('UPDATE playback_preferences SET playback_preference=15')
                self.assertEqual(db.execute('SELECT playback_preference FROM playback_preferences').fetchone()[0], 15)
                for invalid in (-11, 16):
                    with self.assertRaises(sqlite3.IntegrityError):
                        db.execute('UPDATE playback_preferences SET playback_preference=?', (invalid,))
            database.initialize()
            with database.connect() as db:
                self.assertEqual(db.execute('SELECT playback_preference FROM playback_preferences').fetchone()[0], 15)

    def test_api_range(self):
        for value in (-10, 0, 10, 11, 15):
            self.assertEqual(PlaybackPreferenceUpdate(playbackPreference=value, favorite=True).playbackPreference, value)
        for value in (-11, 16):
            with self.assertRaises(ValueError):
                PlaybackPreferenceUpdate(playbackPreference=value, favorite=True)
