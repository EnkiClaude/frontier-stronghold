#!/usr/bin/env bash
# Exports release builds to build/<platform>/. Usage: tools/export.sh [macOS|Windows|Linux ...]
# Needs the Godot 4.7.2 export templates (Editor > Manage Export Templates).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PRESETS=("$@")
[ ${#PRESETS[@]} -eq 0 ] && PRESETS=(macOS Windows Linux)
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
for p in "${PRESETS[@]}"; do
	out=$(grep -A12 "^name=\"$p\"" export_presets.cfg | grep '^export_path=' | head -1 | cut -d'"' -f2)
	mkdir -p "$(dirname "$out")"
	echo "Exporting $p -> $out"
	"$GODOT" --headless --path . --export-release "$p" "$out"
done
