#!/usr/bin/env bash
# Exports versioned release builds into build/:
#   build/FrontierStronghold-v<version>-<platform>.<ext>
# The version comes from project.godot (application/config/version).
# Usage: tools/export.sh [macOS|Windows|Linux ...]
# Needs the Godot 4.7.2 export templates (Editor > Manage Export Templates).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
VERSION=$(grep '^config/version=' project.godot | cut -d'"' -f2)
PRESETS=("$@")
[ ${#PRESETS[@]} -eq 0 ] && PRESETS=(macOS Windows Linux)
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
mkdir -p build
for p in "${PRESETS[@]}"; do
	case "$p" in
		macOS) ext="zip" ;;
		Windows) ext="exe" ;;
		Linux) ext="x86_64" ;;
		*) echo "Unknown preset $p" >&2; exit 1 ;;
	esac
	out="build/FrontierStronghold-v${VERSION}-${p}.${ext}"
	echo "Exporting $p -> $out"
	"$GODOT" --headless --path . --export-release "$p" "$out"
done
