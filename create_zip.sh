#!/usr/bin/env bash
set -euo pipefail
python3 "$(dirname "$0")/tools/package_release.py" "$@"
