"""Diagnostic comparison only; this does not modify selected mapping or export."""
import json
import time
import numpy as np
import benchmark
from benchmark import HERE
from heads import DIRECTORY
from prepare_models import sha256
from storage import atomic_json


def main():
    import onnxruntime as ort
    metadata_path = DIRECTORY / "mtt-discogs-effnet-1.json"
    model_path = DIRECTORY / "mtt-discogs-effnet-1.onnx"
    manifest = json.loads((DIRECTORY / "manifest.json").read_text())
    for path in (metadata_path, model_path):
        if sha256(path) != manifest[path.name]["sha256"]:
            raise ValueError("MTT checksum mismatch")
    labels = json.loads(metadata_path.read_text())["classes"]
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(model_path), options, providers=["CPUExecutionProvider"])
    results = []
    for record in json.loads((HERE / "output/before.json").read_text()):
        before = record["before"]
        path = HERE / before["embeddingFile"]
        if sha256(path) != before["embeddingSHA256"]:
            raise ValueError("Embedding checksum mismatch")
        start = time.perf_counter()
        with np.load(path, allow_pickle=False) as data:
            embedding = data["embeddings"]
            total = np.zeros(len(labels), dtype=np.float64)
            for offset in range(0, len(embedding), 8):
                scores = session.run(None, {session.get_inputs()[0].name: embedding[offset:offset + 8]})[0]
                total += scores.sum(axis=0, dtype=np.float64)
            values = dict(zip(labels, (total / len(embedding)).tolist()))
        result = dict(relativePath=record["identity"]["relativePath"], labels=values,
                      headSeconds=time.perf_counter() - start)
        results.append(result)
        print(record["identity"]["v1"]["title"], {k:round(values[k], 3) for k in
              ("vocal", "voice", "singing", "female vocal", "male vocal", "no vocal", "no vocals", "no voice")})
    atomic_json(HERE / "output/mtt-diagnostic.json", results)


if __name__ == "__main__":
    main()
