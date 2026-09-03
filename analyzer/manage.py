#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from mymusic_analyzer.catalog import export_master, inventory, load_roots


ROOT = Path(__file__).resolve().parent


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyzer cacheを非破壊で棚卸し・統合します。")
    parser.add_argument("command", choices=("audit", "export-master"))
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--cache", type=Path, default=ROOT / "cache" / "analysis.sqlite3")
    parser.add_argument("--output", type=Path, default=ROOT / "output" / "music_features_master.json")
    parser.add_argument("--report", type=Path, default=ROOT / "output" / "music_features_master.sources.json")
    args = parser.parse_args()
    roots = load_roots(args.manifest)
    if args.command == "audit":
        report, _ = inventory(args.cache, roots)
    else:
        report = export_master(args.cache, roots, args.output, args.report)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
