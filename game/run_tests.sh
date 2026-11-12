#!/usr/bin/env bash
# Ember & Ash — the complete automated test suite (Linux/macOS; CI runs this as its test gate).
#   GODOT=/path/to/godot ./run_tests.sh          full: compile check, regression & progression suite, unit tests
#   GODOT=/path/to/godot ./run_tests.sh smoke    fast subset for routine changes
#   GODOT=/path/to/godot ./run_tests.sh quick    full minus the long-running tests listed in the cases' `const SLOW`
#                                                (the two 365-day Steward soaks, the year-long identity probe)
#   QUIET=1 ./run_tests.sh [mode]                 print only failures (with their diagnostics) and the totals; the
#                                                complete output of each stage is kept in $TEST_LOG_DIR
#                                                (default .godot/test_logs/: compile.log, suite.log, unit.log)
# Exit code 0 = everything passed. Reports: user://logs/suite_report.txt and test_report.txt.
# Real saves are never touched: each run saves into its own user://test_saves/run_<unix>_<pid>/ folder.
# Each stage runs exactly once; its exit code decides the result, the output is filtered for reading.
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
MODE="${1:-full}"
QUIET="${QUIET:-0}"
LOG_DIR=""
if [ "$QUIET" = "1" ]; then
  LOG_DIR="${TEST_LOG_DIR:-$(pwd)/.godot/test_logs}"
  mkdir -p "$LOG_DIR"
fi
[ -d .godot/imported ] || "$GODOT" --headless --path . --import >/dev/null 2>&1
fail=0
OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

# QUIET=1: failures with the diagnostic lines that follow them (indented), script errors, and the totals lines.
quiet_filter() {
  awk '
    /^FAIL|COMPILE FAIL|SCRIPT ERROR|Parse Error/ { ctx = 1; print; next }
    /^  / { if (ctx) print; next }
    { ctx = 0 }
    /^compile_all:|^Ember & Ash test suite|^Omitted in quick mode|^[0-9]+ passed/ { print }
  '
}

# run_stage <log name> <title> <grep -E filter> <scene> [args...]
run_stage() {
  local name="$1" title="$2" filter="$3"
  shift 3
  echo "== $title"
  "$GODOT" --headless --path . "$@" >"$OUT" 2>&1
  local code=$?
  if [ "$QUIET" = "1" ]; then
    cp "$OUT" "$LOG_DIR/$name.log"
    quiet_filter <"$OUT"
  else
    grep -E "$filter" "$OUT" || true
  fi
  if [ $code -ne 0 ]; then
    echo "!! $title failed (exit code $code)"
    fail=1
  fi
}

run_stage compile "compile check" "compile_all:|COMPILE FAIL|SCRIPT ERROR|Parse Error" res://tests/compile_all.tscn
run_stage suite "suite ($MODE)" "^(PASS|FAIL|SKIPPED|Ember|Omitted|[0-9]+ passed)|^ {2,}|SCRIPT ERROR" res://tests/suite/suite.tscn -- "$MODE"
if [ "$MODE" = "full" ] || [ "$MODE" = "quick" ]; then
  run_stage unit "unit & regression tests" "^(FAIL|[0-9]+ passed)|SCRIPT ERROR" res://tests/test_runner.tscn
fi
[ "$QUIET" = "1" ] && echo "Complete logs: $LOG_DIR/{compile,suite,unit}.log"
[ $fail -eq 0 ] && echo "ALL GREEN" || echo "FAILURES — see the output above"
exit $fail
