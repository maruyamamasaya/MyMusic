"""Download only the three official MTG ONNX models; never access music files."""
from __future__ import annotations

import hashlib
import json
import os
import tempfile
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
BASE = "https://essentia.upf.edu/models/"
MODELS = {
    "discogs": "music-style-classification/discogs-effnet/discogs-effnet-bsdynamic-1",
    "tags": "classification-heads/mtg_jamendo_top50tags/mtg_jamendo_top50tags-discogs-effnet-1",
    "mood": "classification-heads/mtg_jamendo_moodtheme/mtg_jamendo_moodtheme-discogs-effnet-1",
}
CHECKSUMS = {
    "discogs.json": "1e140159496f7f932e4267b478e246bd60fbd526a7a67d3e12684a2978916420",
    "discogs.onnx": "a280825b334797cf677939db8cd5762c0392aedd0ca6415dbc1cd083f045e43c",
    "tags.json": "379441a7b9a857c0b0eab0bd5115fd2c845009b25a0a6cc80494ac57eaa15d61",
    "tags.onnx": "4a02efe69b4b8e64cfcbe2025f6e7307377cae9e8b6d766b9e12148ca69beac6",
    "mood.json": "d62cd90263e4d613fa7fcce7a831e339450394794af63685f96e065c1a896ab0",
    "mood.onnx": "7d6270acaa5f4bba4b115a0d6849aca05ed6bd153dcb6d9da4f6ab9f99ef10ff",
}


def sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def main() -> None:
    directory = HERE / "models"
    if directory.is_symlink():
        raise ValueError("models must not be a symlink")
    directory.mkdir(exist_ok=True)
    manifest_path = directory / "manifest.json"
    previous = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    manifest = {}
    for key, relative in MODELS.items():
        manifest[key] = {}
        for extension in ("json", "onnx"):
            url = f"{BASE}{relative}.{extension}"
            target = directory / f"{key}.{extension}"
            if target.is_symlink():
                raise ValueError("model must not be a symlink")
            known = previous.get(key, {}).get(extension)
            if target.exists():
                if not known or sha256(target) != CHECKSUMS[target.name] or known["sha256"] != CHECKSUMS[target.name]:
                    raise ValueError(f"Unverified existing file: {target}")
                manifest[key][extension] = known
                print(f"Verified / skipped: {target.name}", flush=True)
                continue
            with tempfile.NamedTemporaryFile(dir=directory, delete=False) as dest:
                temporary = Path(dest.name)
                try:
                    with urllib.request.urlopen(url, timeout=60) as source:
                        size = 0
                        while block := source.read(1024 * 1024):
                            size += len(block)
                            if size > 25_000_000:
                                raise ValueError("Unexpectedly large model download")
                            dest.write(block)
                    dest.flush()
                    os.fsync(dest.fileno())
                    if sha256(temporary) != CHECKSUMS[target.name]:
                        raise ValueError(f"Published model changed: {url}")
                    if extension == "json":
                        json.loads(temporary.read_text())
                    os.replace(temporary, target)
                finally:
                    temporary.unlink(missing_ok=True)
            manifest[key][extension] = {"url": url, "bytes": size, "sha256": sha256(target)}
            # Record each successful download, so interrupted setup can resume.
            saved = {**previous, **manifest}
            with tempfile.NamedTemporaryFile(mode="w", dir=directory, delete=False) as handle:
                json.dump(saved, handle, indent=2)
                handle.flush()
                os.fsync(handle.fileno())
                manifest_temporary = handle.name
            os.replace(manifest_temporary, manifest_path)
            previous = saved
            print(f"Downloaded {key}.{extension}: {size:,} bytes", flush=True)
    print("Models: MTG / CC BY-NC-SA 4.0; see README for attribution and restrictions.")


if __name__ == "__main__":
    main()
