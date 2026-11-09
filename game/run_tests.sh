#!/usr/bin/env bash
# Ember & Ash — the complete automated test suite (Linux/macOS; CI runs this as its test gate).
#   GODOT=/path/to/godot ./run_tests.sh          full: compile check, regression & progression suite, unit tests
#   GODOT=/path/to/godot ./run_tests.sh smoke    fast subset for routine changes
# Exit code 0 = everything passed. Reports: user://logs/suite_report.txt and test_report.txt.
# Real saves are never touched: each run saves into its own user://test_saves/run_<unix>_<pid>/ folder.
# Each stage runs exactly once; its exit code decides the result, the output is filtered for reading.
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
MODE="${1:-full}"
[ -d .godot/imported ] || "$GODOT" --headless --path . --import >/dev/null 2>&1
fail=0
OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

# run_stage <title> <grep -E filter> <scene> [args...]
run_stage() {
  local title="$1" filter="$2"
  shift 2
  echo "== $title"
  "$GODOT" --headless --path . "$@" >"$OUT" 2>&1
  local code=$?
  grep -E "$filter" "$OUT" || true
  if [ $code -ne 0 ]; then
    echo "!! $title failed (exit code $code)"
    fail=1
  fi
}

run_stage "compile check" "compile_all:|COMPILE FAIL|SCRIPT ERROR|Parse Error" res://tests/compile_all.tscn
run_stage "suite ($MODE)" "^(PASS|FAIL|SKIPPED|Ember|[0-9]+ passed)|^ {2,}|SCRIPT ERROR" res://tests/suite/suite.tscn -- "$MODE"
if [ "$MODE" = "full" ]; then
  run_stage "unit & regression tests" "^(FAIL|[0-9]+ passed)|SCRIPT ERROR" res://tests/test_runner.tscn
fi
[ $fail -eq 0 ] && echo "ALL GREEN" || echo "FAILURES — see the output above"
exit $fail
