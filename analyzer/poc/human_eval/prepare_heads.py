"""Download three small official heads; no backbone, dependency, or audio changes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import urllib.request

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from prepare_models import sha256
from storage import atomic_json, safe_target

MODELS = ("voice_instrumental", "mood_aggressive", "mood_relaxed")
DIRECTORY = HERE.parent / "models/human_eval"
CHECKSUMS = {
    "voice_instrumental-discogs-effnet-1.json": "43ac2c3b055dfaed20f6232e0f10636c287f1c5a6e5bd02c5585860031964c8f",
    "voice_instrumental-discogs-effnet-1.onnx": "20155e4c439714b0c45c08644b73c8e12d9dccb173bd4ab9934bf1e5aee837ca",
    "mood_aggressive-discogs-effnet-1.json": "81773e95d78db1b93283d73b2d06344d1ff79685b57d9428a40d47fdfcf537b8",
    "mood_aggressive-discogs-effnet-1.onnx": "de36550b5d1660791ad732ed6de6ebfdc3e65dcf50b928b2578ddf103dbfb400",
    "mood_relaxed-discogs-effnet-1.json": "86c0fe1c2c6d49bf08537bc2d3a602204feaede011ed119c1fc6c36270f60e6a",
    "mood_relaxed-discogs-effnet-1.onnx": "8ba6515a1e5943a72b3b475e3a25fc7a2ff04142c3eaa6aa0716fca371efdfff",
    "mtt-discogs-effnet-1.json": "c1b2d7df2f6b1456bdb3901d82caf941d0f9c0b606f1e3801199a915c73b8f5c",
    "mtt-discogs-effnet-1.onnx": "345fda1433f2bc46ee64c6adf0f21ffed95119172d98378a5a8301a023e25ace",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--diagnostic-mtt", action="store_true", help="Compare one alternate tag head using saved embeddings")
    args = parser.parse_args()
    directory = safe_target(DIRECTORY)
    directory.mkdir(parents=True, exist_ok=True)
    manifest_path = directory / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    for model in (*MODELS, "mtt") if args.diagnostic_mtt else MODELS:
        for extension in ("json", "onnx"):
            name = f"{model}-discogs-effnet-1.{extension}"
            target = safe_target(directory / name)
            url = f"https://essentia.upf.edu/models/classification-heads/{model}/{name}"
            if name in manifest:
                if sha256(target) != CHECKSUMS[name] or manifest[name]["sha256"] != CHECKSUMS[name]:
                    raise ValueError("Head checksum mismatch")
                print("Verified", name)
                continue
            if target.exists():
                raise ValueError(f"Unverified file exists: {target}")
            with urllib.request.urlopen(url, timeout=30) as source:
                data = source.read(3_000_001)
            if len(data) > 3_000_000:
                raise ValueError("Unexpected head size")
            if hashlib.sha256(data).hexdigest() != CHECKSUMS[name]:
                raise ValueError("Published head changed; inspect instead of silently updating")
            if extension == "json":
                json.loads(data)
            with tempfile.NamedTemporaryFile(dir=directory, delete=False) as handle:
                temporary = Path(handle.name)
                handle.write(data)
                handle.flush()
                os.fsync(handle.fileno())
            temporary.replace(target)
            manifest[name] = dict(url=url, bytes=len(data), sha256=sha256(target))
            atomic_json(manifest_path, manifest)
            print("Downloaded", name, len(data), manifest[name]["sha256"], flush=True)


if __name__ == "__main__":
    main()
