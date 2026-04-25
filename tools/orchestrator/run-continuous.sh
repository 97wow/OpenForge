#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# OpenForge continuous orchestrator (bash 3.2+ compatible — macOS default ok)
#
# Runs a queue of tasks sequentially by invoking `claude-next auto` for each.
# Waits for a pre-existing auto loop (via WAIT_FOR_PID env) before starting.
#
# Typical invocation:
#   WAIT_FOR_PID=$(cat /tmp/claude-next-auto.pid) \
#     nohup tools/orchestrator/run-continuous.sh > \
#     /tmp/openforge-orchestrator.log 2>&1 &
#
# Kill switches (either halts at next tick):
#   touch ~/.claude/next/orchestrator.stop
#   touch ~/.claude/next/auto.stop         (also halts current auto loop)
# -----------------------------------------------------------------------------
set -uo pipefail

ORCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$ORCH_DIR/../.." && pwd)"
STATE_DIR="$ORCH_DIR/state"
PROMPTS_DIR="$ORCH_DIR/prompts"
mkdir -p "$STATE_DIR"

LOG="$STATE_DIR/orchestrator.log"
COMPLETED="$STATE_DIR/completed.log"
CURRENT_FILE="$STATE_DIR/current.json"
PID_FILE="$STATE_DIR/current.pid"

ORCH_STOP="$HOME/.claude/next/orchestrator.stop"
AUTO_STOP="$HOME/.claude/next/auto.stop"

log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG"; }

check_stop() {
  if [ -f "$ORCH_STOP" ]; then log "orchestrator.stop found — halting"; return 0; fi
  if [ -f "$AUTO_STOP" ]; then log "auto.stop found — halting"; return 0; fi
  return 1
}

wait_for_pid() {
  local pid="$1"
  log "waiting for PID $pid..."
  while kill -0 "$pid" 2>/dev/null; do
    if check_stop; then return 0; fi
    sleep 30
  done
  log "PID $pid exited"
}

# ----- Task queue (bash 3.2 compatible: case statements instead of assoc arrays)
TASK_IDS="31"

task_budget() {
  case "$1" in
    31) echo 2 ;;
  esac
}

task_windows() {
  case "$1" in
    31) echo 1 ;;
  esac
}

task_deliverable() {
  case "$1" in
    31) echo "docs/THEME_BONDS_WAVE_A_INTEGRATION.md" ;;
  esac
}

task_prompt_file() {
  echo "$PROMPTS_DIR/task-$1.md"
}

# ----- Wait for optional existing PID ---------------------------------------
if [ -n "${WAIT_FOR_PID:-}" ]; then
  wait_for_pid "$WAIT_FOR_PID"
fi
if check_stop; then exit 0; fi

log "======== orchestrator started · queue: $TASK_IDS ========"

for tid in $TASK_IDS; do
  if check_stop; then break; fi

  budget="$(task_budget "$tid")"
  wins="$(task_windows "$tid")"
  deliverable="$(task_deliverable "$tid")"
  prompt_file="$(task_prompt_file "$tid")"

  if [ ! -f "$prompt_file" ]; then
    log "✗ Task #$tid prompt file missing: $prompt_file — skipping"
    continue
  fi

  prompt="$(cat "$prompt_file")"

  log "--- Task #$tid start · \$${budget} / ${wins} windows · deliverable=$deliverable ---"
  printf '{"task_id":"%s","started":"%s","budget":%s,"max_windows":%s}\n' \
    "$tid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$budget" "$wins" > "$CURRENT_FILE"

  claude-next auto \
    --cwd "$ROOT" \
    --max-turns-per-window 20 \
    --max-windows "$wins" \
    --window-budget-usd 2 \
    --total-budget-usd "$budget" \
    "$prompt" \
    > "$STATE_DIR/task-${tid}.log" 2>&1 &
  child_pid=$!
  echo "$child_pid" > "$PID_FILE"
  log "Task #$tid child PID: $child_pid"

  wait "$child_pid" || true
  rc=$?
  log "Task #$tid exit=$rc"

  if [ -f "$ROOT/$deliverable" ]; then
    log "✅ Task #$tid deliverable present: $deliverable"
    printf '[%s] task %s OK · deliverable=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tid" "$deliverable" >> "$COMPLETED"
  else
    log "⚠️  Task #$tid deliverable MISSING: $deliverable — continuing anyway"
    printf '[%s] task %s MISSING · expected=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tid" "$deliverable" >> "$COMPLETED"
  fi

  rm -f "$CURRENT_FILE" "$PID_FILE"
  sleep 5
done

log "======== orchestrator finished ========"
