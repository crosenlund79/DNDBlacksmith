#!/usr/bin/env bash
# Ember & Ash — the complete automated test suite (Linux/macOS; CI runs this as its test gate).
#   GODOT=/path/to/godot ./run_tests.sh          full: compile check, regression & progression suite, unit tests
#   GODOT=/path/to/godot ./run_tests.sh smoke    fast subset for routine changes
#   GODOT=/path/to/godot ./run_tests.sh quick    full minus the long-running tests listed in the cases' `const SLOW`
#                                                (the two 365-day Steward soaks, the year-long identity probe)
#   GODOT=/path/to/godot ./run_tests.sh focus <area>   PARTIAL verification of one area: compile check, the suite
#                                                tests mapped to <area> in tests/suite/focus_areas.cfg, all unit tests
#                                                (areas: workshop, commerce; an unknown area stops with exit code 2)
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
FOCUS_FILE="tests/suite/focus_areas.cfg"
AREA=""
SELECTORS=""
if [ "$MODE" = "focus" ]; then
  AREA="${2:-}"
  areas="$(sed 's/#.*//' "$FOCUS_FILE" | awk -F: 'NF > 1 { k = $1; gsub(/[ \t]/, "", k); if (k != "") print k }' | sort -u | tr '\n' ' ')"
  SELECTORS="$(sed 's/#.*//' "$FOCUS_FILE" | awk -F: -v a="$AREA" '{ k = $1; gsub(/[ \t]/, "", k) } NF > 1 && k == a { print $2 }' | tr -s ' \t\n' '   ' | sed 's/^ *//; s/ *$//')"
  if [ -z "$AREA" ] || [ -z "$SELECTORS" ]; then
    echo "run_tests.sh focus: unknown focus area '${AREA}'. Known areas: ${areas}(mapping: game/$FOCUS_FILE)." >&2
    exit 2
  fi
fi
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

# focus mode: which suite tests ran, per case (whole case or the selected tests), with their results.
focus_summary() {
  awk -v sels="$SELECTORS" -v area="$AREA" '
    BEGIN { n = split(sels, s, " "); for (i = 1; i <= n; i++) if (index(s[i], ".") == 0) whole[s[i]] = 1 }
    $1 ~ /^(PASS|FAIL|SKIPPED)$/ {
      d = index($2, "."); c = substr($2, 1, d - 1); t = substr($2, d + 1)
      if (!(c in seen)) { seen[c] = 1; order[++m] = c }
      cnt[c]++; res[c, $1]++
      if ($1 != "PASS") t = t " [" $1 "]"
      names[c] = (names[c] == "" ? t : names[c] ", " t)
    }
    END {
      print "Tests run (focus " area ", PARTIAL):"
      for (i = 1; i <= m; i++) {
        c = order[i]
        line = sprintf("  %-17s %3d run: %d passed, %d failed, %d skipped", c, cnt[c], res[c, "PASS"], res[c, "FAIL"], res[c, "SKIPPED"])
        print line ((c in whole) ? " — whole case" : " — " names[c])
      }
    }
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
if [ "$MODE" = "focus" ]; then
  echo "== PARTIAL verification — focus '$AREA': $(echo "$SELECTORS" | wc -w) suite selectors from game/$FOCUS_FILE," \
    "plus the compile check and all unit tests. Not a substitute for quick/full."
  # the selectors are single words (case or case.test); word splitting is intended
  # shellcheck disable=SC2086
  run_stage suite "suite (focus $AREA — PARTIAL)" "^(PASS|FAIL|SKIPPED|Ember|Omitted|[0-9]+ passed)|^ {2,}|SCRIPT ERROR" res://tests/suite/suite.tscn -- quick $SELECTORS
  focus_summary <"$OUT"
else
  run_stage suite "suite ($MODE)" "^(PASS|FAIL|SKIPPED|Ember|Omitted|[0-9]+ passed)|^ {2,}|SCRIPT ERROR" res://tests/suite/suite.tscn -- "$MODE"
fi
if [ "$MODE" = "full" ] || [ "$MODE" = "quick" ] || [ "$MODE" = "focus" ]; then
  run_stage unit "unit & regression tests" "^(FAIL|[0-9]+ passed)|SCRIPT ERROR" res://tests/test_runner.tscn
fi
[ "$QUIET" = "1" ] && echo "Complete logs: $LOG_DIR/{compile,suite,unit}.log"
if [ "$MODE" = "focus" ]; then
  [ $fail -eq 0 ] && echo "PARTIAL GREEN — focus '$AREA' only; run ./run_tests.sh quick (or full) before merging" \
    || echo "FAILURES (PARTIAL run, focus '$AREA') — see the output above"
else
  [ $fail -eq 0 ] && echo "ALL GREEN" || echo "FAILURES — see the output above"
fi
exit $fail
