#!/usr/bin/env bash
# Ember & Ash — the complete automated test suite (Linux/macOS).
#   GODOT=/path/to/godot ./run_tests.sh          full: compile check, regression & progression suite, unit tests
#   GODOT=/path/to/godot ./run_tests.sh smoke    fast subset for routine changes
# Exit code 0 = everything passed. Reports: user://logs/suite_report.txt and test_report.txt.
# Real saves are never touched (tests use user://test_saves/).
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
MODE="${1:-full}"
[ -d .godot/imported ] || "$GODOT" --headless --path . --import >/dev/null 2>&1
fail=0
echo "== compile check"
"$GODOT" --headless --path . res://tests/compile_all.tscn 2>&1 | grep -E "compile_all:|COMPILE FAIL|SCRIPT ERROR" || true
"$GODOT" --headless --path . res://tests/compile_all.tscn >/dev/null 2>&1 || fail=1
echo "== suite ($MODE)"
"$GODOT" --headless --path . res://tests/suite/suite.tscn -- "$MODE" 2>&1 | grep -vE "ObjectDB|leaked|resources still in use|at: (cleanup|clear)|ALSA|audio_driver" || true
"$GODOT" --headless --path . res://tests/suite/suite.tscn -- "$MODE" >/dev/null 2>&1 || fail=1
if [ "$MODE" = "full" ]; then
  echo "== unit & regression tests"
  "$GODOT" --headless --path . res://tests/test_runner.tscn 2>&1 | grep -E "^(FAIL|[0-9]+ passed)" || true
  "$GODOT" --headless --path . res://tests/test_runner.tscn >/dev/null 2>&1 || fail=1
fi
[ $fail -eq 0 ] && echo "ALL GREEN" || echo "FAILURES — see the output above"
exit $fail
