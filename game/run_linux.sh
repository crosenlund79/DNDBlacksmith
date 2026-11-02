#!/usr/bin/env bash
# Ember & Ash — Linux/macOS launcher. GODOT=/path/to/godot ./run_linux.sh [--tests]
set -e
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
[ -d .godot/imported ] || "$GODOT" --headless --path . --import
if [ "$1" = "--tests" ]; then exec "$GODOT" --headless --path . res://tests/test_runner.tscn; fi
exec "$GODOT" --path . "$@"
