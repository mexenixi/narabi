#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! xcrun --find swift-format >/dev/null 2>&1; then
  echo "WARNING: Xcode swift-format is unavailable; formatting lint skipped."
  exit 0
fi
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Narabi"
