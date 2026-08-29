from __future__ import annotations

import json
from pathlib import Path
import sqlite3

from .safety import atomic_file, digest, fingerprint, safe_path


class SemanticCache:
    def __init__(self, directory):
        self.directory = directory
        path = safe_path(directory/'index.sqlite3',directory)
        for suffix in ('-wal','-shm','-journal'):
            safe_path(Path(str(path)+suffix),directory)
        self.db = sqlite3.connect(path)
        self.db.row_factory = sqlite3.Row
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.execute('PRAGMA synchronous=FULL')
        self.db.executescript('''
          CREATE TABLE IF NOT EXISTS tracks (
            relative_path TEXT PRIMARY KEY, identity_json TEXT NOT NULL,
            mtime_ns INTEGER, embed_profile TEXT, state TEXT NOT NULL DEFAULT 'pending',
            npz_path TEXT, npz_sha256 TEXT, error TEXT, detail_json TEXT,
            present INTEGER NOT NULL DEFAULT 1, source_features_json TEXT);
          CREATE INDEX IF NOT EXISTS tracks_state ON tracks(state,relative_path);
          CREATE TABLE IF NOT EXISTS heads (
            relative_path TEXT NOT NULL, profile TEXT NOT NULL, embedding_sha TEXT NOT NULL,
            state TEXT NOT NULL, features_json TEXT, labels_json TEXT, error TEXT,
            PRIMARY KEY(relative_path,profile));
          CREATE INDEX IF NOT EXISTS heads_profile ON heads(profile,state);
          CREATE TABLE IF NOT EXISTS runs (id INTEGER PRIMARY KEY, summary_json TEXT NOT NULL);
        ''')
        columns={row['name'] for row in self.db.execute('PRAGMA table_info(tracks)')}
        # In-place migration of the existing frozen 3,552-track semantic cache.
        if 'present' not in columns:
            self.db.execute("ALTER TABLE tracks ADD COLUMN present INTEGER NOT NULL DEFAULT 1")
        if 'source_features_json' not in columns:
            self.db.execute("ALTER TABLE tracks ADD COLUMN source_features_json TEXT")
        self.db.execute('CREATE INDEX IF NOT EXISTS tracks_present ON tracks(present,state,relative_path)')
        self.db.commit()

    def register_scope(self, scope):
        with self.db:
            for track in scope['tracks']:
                identity = {k:v for k,v in track.items() if k!='features'}
                self.db.execute('INSERT OR IGNORE INTO tracks(relative_path,identity_json) VALUES (?,?)',
                                (track['relativePath'],json.dumps(identity,ensure_ascii=False,sort_keys=True)))
                self.db.execute('''UPDATE tracks SET source_features_json=COALESCE(source_features_json,?)
                                   WHERE relative_path=?''',
                                (json.dumps(track.get('features',{}),ensure_ascii=False,sort_keys=True),
                                 track['relativePath']))

    def track_records(self):
        records={}
        for row in self.db.execute('SELECT * FROM tracks'):
            item=dict(row)
            item['identity']=json.loads(item['identity_json'])
            item['source_features']=json.loads(item['source_features_json'] or '{}')
            records[item['relative_path']]=item
        return records

    def reconcile_scope(self, scope, mtimes):
        """Atomically mark presence and invalidate only identities whose source changed."""
        inserted=updated=unchanged=0
        active={track['relativePath'] for track in scope['tracks']}
        records=self.track_records()
        deleted=sum(1 for relative,row in records.items() if row['present'] and relative not in active)
        with self.db:
            self.db.execute('UPDATE tracks SET present=0')
            for track in scope['tracks']:
                relative=track['relativePath']
                identity={k:v for k,v in track.items() if k!='features'}
                identity_json=json.dumps(identity,ensure_ascii=False,sort_keys=True)
                features_json=json.dumps(track.get('features',{}),ensure_ascii=False,sort_keys=True)
                mtime_ns=mtimes[relative]
                row=records.get(relative)
                if row is None:
                    self.db.execute('''INSERT INTO tracks
                      (relative_path,identity_json,mtime_ns,state,present,source_features_json)
                      VALUES (?,?,?,'pending',1,?)''',
                      (relative,identity_json,mtime_ns,features_json))
                    inserted+=1
                elif row['identity_json']!=identity_json or (row['mtime_ns'] is not None and row['mtime_ns']!=mtime_ns):
                    self.db.execute('''UPDATE tracks SET identity_json=?,mtime_ns=?,state='pending',
                      embed_profile=NULL,npz_path=NULL,npz_sha256=NULL,error=NULL,detail_json=NULL,
                      present=1,source_features_json=? WHERE relative_path=?''',
                      (identity_json,mtime_ns,features_json,relative))
                    # The old immutable NPZ may remain as a safe historical/orphan file, but its
                    # head result must never be joined to this new identity.
                    self.db.execute('DELETE FROM heads WHERE relative_path=?',(relative,))
                    updated+=1
                else:
                    self.db.execute('''UPDATE tracks SET present=1,mtime_ns=COALESCE(mtime_ns,?),
                      source_features_json=? WHERE relative_path=?''',(mtime_ns,features_json,relative))
                    unchanged+=1
        return dict(inserted=inserted,updated=updated,unchanged=unchanged,deleted=deleted)

    def get(self, relative):
        row = self.db.execute('SELECT * FROM tracks WHERE relative_path=?',(relative,)).fetchone()
        return dict(row) if row else None

    def embedding_path(self, root, identity, mtime_ns, profile):
        key = fingerprint(dict(root=root,identity=identity,mtimeNS=mtime_ns,profile=profile))
        return safe_path(self.directory/'embeddings'/profile[:16]/key[:2]/(key+'.npz'),self.directory)

    def write_embedding(self, path, metadata, arrays):
        import numpy as np
        if path.exists():
            raise ValueError("Do not overwrite an existing embedding; validate/recover it")
        payload = dict(arrays,metadata_json=np.asarray(json.dumps(metadata,sort_keys=True,ensure_ascii=False)))
        atomic_file(path,self.directory,lambda handle:np.savez_compressed(handle,**payload))

    def load_embedding(self, path, checksum=None):
        import numpy as np
        import zipfile
        path = safe_path(path,self.directory)
        if checksum and digest(path)!=checksum:
            raise ValueError("Embedding checksum mismatch; never silently reanalyze corrupted cache")
        if path.stat().st_size>4_000_000:
            raise ValueError("Embedding archive exceeds bounded per-track size")
        with zipfile.ZipFile(path) as archive:
            if sum(info.file_size for info in archive.infolist())>4_000_000:
                raise ValueError("Expanded embedding archive exceeds size limit")
        with np.load(path,allow_pickle=False) as data:
            required={'embeddings','discogs_mean','segment_offsets','segment_patch_counts','metadata_json'}
            if set(data.files)!=required:
                raise ValueError("Unknown embedding archive format")
            metadata=json.loads(str(data['metadata_json']))
            arrays={key:data[key].copy() for key in required-{'metadata_json'}}
        e=arrays['embeddings'];scores=arrays['discogs_mean']
        counts=arrays['segment_patch_counts'];offsets=arrays['segment_offsets']
        if (e.dtype!=np.float32 or e.ndim!=2 or e.shape[1]!=1280 or not 1<=len(e)<=256
                or scores.shape!=(400,) or not np.isfinite(e).all() or not np.isfinite(scores).all()
                or np.any(scores<0) or np.any(scores>1) or counts.ndim!=1 or not 1<=len(counts)<=3
                or counts.dtype.kind not in 'iu' or np.any(counts<=0) or int(counts.sum())!=len(e)
                or offsets.shape!=counts.shape or not np.isfinite(offsets).all() or np.any(offsets<0)):
            raise ValueError("Invalid embedding dimensions/probabilities/segment boundaries")
        return metadata,arrays

    def ready(self, identity, mtime_ns, profile, path, detail):
        with self.db:
            self.db.execute('''UPDATE tracks SET state='ready',mtime_ns=?,embed_profile=?,npz_path=?,
                npz_sha256=?,error=NULL,detail_json=? WHERE relative_path=?''',
                (mtime_ns,profile,str(path.relative_to(self.directory)),digest(path),
                 json.dumps(detail,ensure_ascii=False),identity['relativePath']))

    def fail_embedding(self, relative, error):
        with self.db:
            self.db.execute("UPDATE tracks SET state='error',error=? WHERE relative_path=?",(str(error),relative))

    def embedded_rows(self):
        for row in self.db.execute("SELECT * FROM tracks WHERE present=1 AND state='ready' ORDER BY relative_path"):
            yield dict(row)

    def head_result(self, relative, profile):
        row=self.db.execute('SELECT * FROM heads WHERE relative_path=? AND profile=?',(relative,profile)).fetchone()
        return dict(row) if row else None

    def save_head(self, row, profile, features=None, labels=None, error=None):
        with self.db:
            self.db.execute('INSERT OR REPLACE INTO heads VALUES (?,?,?,?,?,?,?)',
                (row['relative_path'],profile,row['npz_sha256'],'error' if error else 'ready',
                 json.dumps(features,ensure_ascii=False,allow_nan=False) if features else None,
                 json.dumps(labels,ensure_ascii=False,allow_nan=False) if labels else None,
                 str(error) if error else None))

    def export_rows(self, profile):
        rows=self.db.execute('''SELECT t.identity_json,h.features_json FROM tracks t JOIN heads h
          ON t.relative_path=h.relative_path AND t.npz_sha256=h.embedding_sha
          WHERE t.present=1 AND t.state='ready' AND h.state='ready' AND h.profile=?
          ORDER BY t.relative_path''',(profile,))
        return [{**json.loads(r[0]),'features':json.loads(r[1])} for r in rows]

    def save_run(self, summary):
        with self.db:
            self.db.execute('INSERT INTO runs(summary_json) VALUES (?)',(json.dumps(summary,ensure_ascii=False),))

    def close(self):
        self.db.close()
