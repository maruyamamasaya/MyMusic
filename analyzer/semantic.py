#!/usr/bin/env python3
"""Independent, resumable Discogs-EffNet embedding cache and semantic heads CLI."""
import sys

sys.dont_write_bytecode = True
from mymusic_semantic.cli import main

if __name__ == "__main__":
    raise SystemExit(main())
