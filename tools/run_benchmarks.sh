#!/usr/bin/env bash
# Runs the headless benchmarks.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
if [ ! -d .godot ]; then "$GODOT" --headless --path . --import >/dev/null 2>&1 || true; fi
"$GODOT" --headless --path . -s res://tests/benchmarks/run_benchmarks.gd
