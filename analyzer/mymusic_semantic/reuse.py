"""Import compatible PoC embeddings read-only; never open a PoC cache for write."""
from __future__ import annotations

import json
import sqlite3
import zipfile

from .models import POC
from .safety import digest
from engine import config_key,model_manifest,REVISION


class PoCSeeds:
    def __init__(self):
        self.entries={}
        expected=config_key(model_manifest())
        directory=POC/'human_eval'
        db=directory/'data/baseline.sqlite3'
        manifest=directory/'data/selection.json'
        if db.exists() and manifest.exists() and not any(db.with_name(db.name+s).exists() for s in ('-wal','-journal')):
            identities={r['relativePath']:r for r in json.loads(manifest.read_text())['tracks']}
            connection=sqlite3.connect(db.as_uri()+'?mode=ro&immutable=1',uri=True)
            try:
                records=connection.execute("SELECT identity,payload FROM results WHERE status='success' AND config=?",
                    (expected+';human-eval-embedding-capture-v1',)).fetchall()
            finally:
                connection.close()
            for identity_json,payload in records:
                root,relative,size,mtime=json.loads(identity_json)
                row=identities.get(relative)
                if row and (root,size,mtime)==(row['root'],row['fileSize'],row['mtimeNS']):
                    self.entries[(root,relative)]=(row,json.loads(payload),directory)
        path=POC/'vi_eval/output/baseline.json'
        if path.exists():
            for record in json.loads(path.read_text()):
                if not record['config'].startswith(expected):
                    continue
                baseline={**record['baseline'],'embeddingFile':'data/'+record['embeddingFile'],
                          'embeddingSHA256':record['embeddingSHA256']}
                row=record['identity']
                self.entries[(row['root'],row['relativePath'])]=(row,baseline,POC/'vi_eval')

    def get(self,root,identity,mtime_ns):
        import numpy as np
        item=self.entries.get((root,identity['relativePath']))
        if item is None:
            return None
        row,before,directory=item
        old_identity={k:v for k,v in row['v1'].items() if k!='features'}
        if old_identity!=identity or row['mtimeNS']!=mtime_ns or before['revision']!=REVISION:
            return None
        path=(directory/before['embeddingFile']).resolve()
        if not path.is_relative_to(directory/'data') or digest(path)!=before['embeddingSHA256']:
            raise ValueError('PoC seed checksum/path mismatch; PoC is not modified or silently replaced')
        with zipfile.ZipFile(path) as z:
            if sum(i.file_size for i in z.infolist())>4_000_000:
                raise ValueError('PoC archive exceeds per-track size bound')
        with np.load(path,allow_pickle=False) as data:
            embedded=data['embeddings'].copy()
        offsets=before['offsets']
        # Only the existing, fully verified 3x30s / 29-patch-per-window format is migrated.
        if (embedded.shape!=(87,1280) or embedded.dtype!=np.float32 or len(offsets)!=3
                or before['patches']!=87 or not np.isfinite(embedded).all()
                or any(o+30>identity['duration'] for o in offsets)):
            return None
        labels=json.loads((POC/'models/discogs.json').read_text())['classes']
        arrays=dict(embeddings=embedded,discogs_mean=np.asarray([before['labels']['discogs'][k] for k in labels]),
                    segment_offsets=np.asarray(offsets),segment_patch_counts=np.asarray([29]*3,dtype=np.int32))
        detail=dict(timing=dict(total=0.,decode=0.,inference=0.,dsp=0.),patches=87,
                    origin='read-only PoC embedding reuse',source=str(path),sourceSHA256=before['embeddingSHA256'])
        return arrays,detail
