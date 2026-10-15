#!/usr/bin/env bash
# Run Godot and fail if it prints errors, even when its exit code is 0.
# Usage: GODOT=/path/to/godot tools/ci/godot_checked.sh <godot args...>
set -uo pipefail

: "${GODOT:?GODOT must point to the Godot binary}"
log="$(mktemp)"

"$GODOT" "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

# Godot prefixes engine and script errors with "ERROR:" / "SCRIPT ERROR:".
# Warnings about typed GDScript are promoted to errors by project settings.
if grep -E "^(SCRIPT )?ERROR:|Parse Error|Failed to load script" "$log" >/dev/null; then
	echo "::error::Godot reported errors (see log above)"
	grep -nE "^(SCRIPT )?ERROR:|Parse Error|Failed to load script" "$log"
	status=1
fi

rm -f "$log"
exit "$status"
