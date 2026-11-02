#!/usr/bin/env bash
# Runs the headless unit tests. Usage: tools/run_tests.sh [filter]
# Fails if any test fails OR if the engine reports a script/parse error
# (GDScript errors don't throw, so they are detected from the log).
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# (Re)import so new class_name scripts and resources are registered.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
LOG="$(mktemp)"
"$GODOT" --headless --path . -s res://tests/run_tests.gd -- "$@" 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script" "$LOG"; then
	echo "Engine reported script errors (see above)." >&2
	STATUS=1
fi
rm -f "$LOG"
exit $STATUS
