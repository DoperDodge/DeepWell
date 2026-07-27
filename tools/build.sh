#!/usr/bin/env bash
# tools/build.sh — headless export (Linux host). Mirrors tools/build.ps1.
# Usage: GODOT=/path/to/godot ./tools/build.sh [windows|linux]
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
TARGET="${1:-windows}"

case "$TARGET" in
  windows) PRESET="Windows Desktop"; OUT="build/windows/DEEPWELL.exe" ;;
  linux)   PRESET="Linux";           OUT="build/linux/deepwell.x86_64" ;;
  *) echo "unknown target: $TARGET" >&2; exit 1 ;;
esac

mkdir -p "$(dirname "$OUT")"

echo "Importing assets..."
"$GODOT" --headless --path . --import

echo "Exporting release build ($PRESET)..."
"$GODOT" --headless --path . --export-release "$PRESET" "$OUT"

[ -f "$OUT" ] || { echo "EXPORT FAILED - no output produced (are export templates installed?)" >&2; exit 1; }

# Ship the license alongside — legally required (see PLAN.md §2)
cp LICENSE.md docs/ATTRIBUTION.md docs/ASSET_LICENSES.md "$(dirname "$OUT")/"

echo "OK: $OUT ($(du -m "$OUT" | cut -f1) MB)"
