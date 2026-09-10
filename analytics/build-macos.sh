#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -d .venv-desktop ]; then
  python3 -m venv .venv-desktop
fi

. .venv-desktop/bin/activate
python -m pip install -r requirements-build-macos.txt
rm -rf build "dist/MyMusic Analytics.app"
python setup_macos.py py2app

echo "Built: $(pwd)/dist/MyMusic Analytics.app"
