#!/usr/bin/env bash
# Run every gdUnit4 test suite **in its own Godot process** so cross-suite
# state contamination (autoload / gdUnit4 monitor_signals) cannot SIGSEGV
# the run.
#
# 背景：gdUnit4 `runtest.sh -a tests/` 把所有 suite 跑在同一个 Godot 进程
# 里。EventBus / EngineAPI / SaveSystem 等 autoload 在 suite 之间共享，
# `monitor_signals(EventBus)` 留下的 dangling Callable 会让下一 suite 进
# `_ready` 时段错。每个 suite 独立进程 = 每个进程都从干净 autoload 起步，
# 跨 suite 污染不再可达。
#
# 用法：
#   GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
#     bash tools/test/run_all_tests.sh
#
# 退出码：所有 suite 都 PASS 时 0；任意一个非 0 即 1。
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

if [ -z "${GODOT_BIN:-}" ]; then
  if [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
  else
    echo "ERROR: GODOT_BIN unset and /Applications/Godot.app not found" >&2
    exit 2
  fi
  export GODOT_BIN
fi

# Portable: macOS ships bash 3.2 (no mapfile). Use a NUL-delimited read loop.
SUITES=()
while IFS= read -r -d '' s; do
  SUITES+=("$s")
done < <(find tests -name "test_*.gd" -not -name "*.uid" -print0 | sort -z)

if [ ${#SUITES[@]} -eq 0 ]; then
  echo "ERROR: no test suites found under tests/" >&2
  exit 2
fi

PASS=0
FAIL=0
FAIL_LIST=()

for suite in "${SUITES[@]}"; do
  echo "──────────────────────────────────────────────"
  echo "▶ $suite"
  echo "──────────────────────────────────────────────"
  if bash addons/gdUnit4/runtest.sh -a "$suite" 2>&1 | tail -8; then
    rc=${PIPESTATUS[0]}
  else
    rc=${PIPESTATUS[0]}
  fi
  if [[ $rc -eq 0 ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAIL_LIST+=("$suite (rc=$rc)")
  fi
done

echo "══════════════════════════════════════════════"
echo "  Summary: ${PASS} passed, ${FAIL} failed (out of ${#SUITES[@]})"
if [[ ${FAIL} -gt 0 ]]; then
  printf '    ✗ %s\n' "${FAIL_LIST[@]}"
fi
echo "══════════════════════════════════════════════"

[[ ${FAIL} -eq 0 ]]
