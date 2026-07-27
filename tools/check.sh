#!/usr/bin/env bash
# tools/check.sh — headless project validation. Run this before every commit.
# Imports the project, then runs tools/validate_project.gd (data schemas,
# script loads, seeded generation soak, save round-trip).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"

echo "== import =="
"$GODOT" --headless --path . --import 2>&1 | grep -Ei "error|script" || true

echo "== validate =="
"$GODOT" --headless --path . -- --validate

echo "== ui probe =="
"$GODOT" --headless --path . -- --uiprobe
