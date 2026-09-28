#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ -n "${PYTHON_BIN:-}" ]; then
  build_python="$PYTHON_BIN"
else
  for candidate in python3.13 python3.12 python3.11 python3.10; do
    if command -v "$candidate" >/dev/null 2>&1; then
      build_python="$candidate"
      break
    fi
  done
fi

if [ -z "${build_python:-}" ]; then
  echo "Python 3.10〜3.13が必要です（Python 3.14は現在のPydantic固定版に未対応です）。" >&2
  exit 1
fi

build_version="$($build_python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
venv_version=""
if [ -x .venv-desktop/bin/python ]; then
  venv_version="$(.venv-desktop/bin/python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
fi
if [ "$venv_version" != "$build_version" ]; then
  rm -rf .venv-desktop
  "$build_python" -m venv .venv-desktop
fi

. .venv-desktop/bin/activate
python -m pip install -r requirements-build-macos.txt
rm -rf build "dist/MyMusic Analytics.app"
python setup_macos.py py2app

echo "Built: $(pwd)/dist/MyMusic Analytics.app"
