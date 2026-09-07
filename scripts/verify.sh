#!/usr/bin/env bash
set -euo pipefail

fast=false
if [[ "${1:-}" == "--fast" ]]; then
  fast=true
elif [[ $# -ne 0 ]]; then
  echo "使い方: $0 [--fast]" >&2
  exit 2
fi

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "必要なコマンドが見つかりません: $1" >&2
    exit 1
  }
}

run_step() {
  echo "==> $1"
  shift
  "$@"
}

require_command python3
require_command node

run_step "Analyzer unit test" env PYTHONPATH=analyzer python3 -m unittest discover -s analyzer/tests -v
run_step "Analytics unit test" bash -c 'cd analytics && python3 -m unittest discover -s tests -v'
run_step "Analytics control test" bash -c 'cd analytics && node --test tests/controls.test.cjs'

if ! "$fast"; then
  run_step "Analytics browser regression test" bash -c 'cd analytics && node tests/browser_ux.cjs'
  require_command xcodebuild
  run_step "iOS / Watch Simulator XCTest" xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO test
fi

echo "検証に成功しました。"
