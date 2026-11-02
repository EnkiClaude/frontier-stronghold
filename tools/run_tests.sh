#!/usr/bin/env bash
# Runs the headless unit tests. Usage: tools/run_tests.sh [filter]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Import once so class_name scripts and resources are registered.
if [ ! -d .godot ]; then "$GODOT" --headless --path . --import >/dev/null 2>&1 || true; fi
"$GODOT" --headless --path . -s res://tests/run_tests.gd -- "$@"
