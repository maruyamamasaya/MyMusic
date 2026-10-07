import hashlib
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from mymusic_semantic.backup import create_backup, restore_backup
from mymusic_semantic.safety import FORMAT


class SemanticBackupTests(unittest.TestCase):
    def test_roundtrip_preserves_index_embedding_profiles_and_outputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            cache = root / 'workspaces' / 'source'
            cache.mkdir(parents=True)
            (cache / 'owner.json').write_text(json.dumps(dict(format=FORMAT)))
            (cache / 'embedding-profile.json').write_text('{"profile":"fixture"}')
            (cache / 'embeddings').mkdir()
            embedding = b'embedding fixture'
            (cache / 'embeddings/a.npz').write_bytes(embedding)
            with sqlite3.connect(cache / 'index.sqlite3') as db:
                db.execute('PRAGMA journal_mode=WAL')
                db.execute('CREATE TABLE tracks(relative_path TEXT, state TEXT, npz_path TEXT, npz_sha256 TEXT)')
                db.execute('INSERT INTO tracks VALUES(?,?,?,?)', ('a.flac', 'ready', 'embeddings/a.npz', hashlib.sha256(embedding).hexdigest()))
                db.commit()
                with patch('mymusic_semantic.safety.CACHE_SETS_HOME', root / 'workspaces'):
                    archive = root / 'backup.zip'
                    create_backup(cache, archive)
                    restored = root / 'workspaces/restored'
                    restore_backup(archive, restored)
                    self.assertEqual((restored / 'embeddings/a.npz').read_bytes(), embedding)
                    self.assertEqual((restored / 'embedding-profile.json').read_bytes(), (cache / 'embedding-profile.json').read_bytes())
                    with sqlite3.connect(restored / 'index.sqlite3') as copy:
                        self.assertEqual(copy.execute('SELECT * FROM tracks').fetchall(), db.execute('SELECT * FROM tracks').fetchall())
                    with self.assertRaises(ValueError):
                        restore_backup(archive, cache)
                    self.assertEqual((cache / 'embeddings/a.npz').read_bytes(), embedding)
                    with self.assertRaises(ValueError):
                        create_backup(cache, archive)

    def test_corrupt_archive_and_unsafe_paths_leave_destination_absent(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            for name in ('../escape', 'owner.json'):
                archive = root / 'bad.zip'
                with zipfile.ZipFile(archive, 'w') as output:
                    output.writestr('manifest.json', json.dumps(dict(format='mymusic-semantic-backup', version=1,
                        files=[dict(path=name, size=1, sha256='0' * 64)])))
                    output.writestr(name, b'x')
                destination = root / 'workspaces/restored'
                with patch('mymusic_semantic.safety.CACHE_SETS_HOME', root / 'workspaces'):
                    with self.assertRaises(ValueError):
                        restore_backup(archive, destination)
                self.assertFalse(destination.exists())
