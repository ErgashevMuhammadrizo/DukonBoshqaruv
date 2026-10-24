#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
rm -f DokonBoshqaruv.zip
zip -qr DokonBoshqaruv.zip DokonBoshqaruv \
  -x '.env' '.env.*' '*/.env' '*/.env.*' \
  '*/.venv/*' '.venv/*' '.venv' '*/__pycache__/*' '*.pyc' \
  '*.sqlite3' '*/.dart_tool/*' '.dart_tool/*' '*/build/*' \
  '*/node_modules/*' '*.dump' '*.key'
unzip -t DokonBoshqaruv.zip >/dev/null
printf 'Archive verified: %s\n' "$(pwd)/DokonBoshqaruv.zip"
