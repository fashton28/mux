#!/usr/bin/env bash
#
# no-mistakes-gate - PreToolUse hook (issue #8).
#
# Fires when an agent runs a command that *completes an issue* (`gh pr create`
# or `gh issue close`). At that moment it enforces the project's testing layer:
# the bats suite must pass, otherwise the command is blocked and the agent is
# told to run /no-mistakes and fix the failures.
#
# It deliberately does nothing on any other command, so normal/read-only turns
# are never gated. Wired up in .claude/settings.json.
#
# Hook protocol: receives the tool call as JSON on stdin; exit 2 blocks the call
# and feeds stderr back to the agent; exit 0 allows it.

set -u

input=$(cat)

tool=$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null)
[ "$tool" = "Bash" ] || exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)
case "$cmd" in
  *"gh pr create"*|*"gh issue close"*) ;;
  *) exit 0 ;;
esac

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] && cd "$root" 2>/dev/null || exit 0

# Nothing to enforce if there is no suite or no runner available.
[ -d tests ] || exit 0
command -v bats >/dev/null 2>&1 || exit 0

log="$(mktemp -t mux-gate.XXXXXX)"
if ! bats tests >"$log" 2>&1; then
  {
    echo "BLOCKED: the test suite must pass before completing an issue."
    echo "Run /no-mistakes and fix the failures, then retry. Test output:"
    echo "---"
    tail -n 40 "$log"
  } >&2
  exit 2
fi

echo "no-mistakes-gate: tests pass. Confirm /no-mistakes was run for this issue (Definition of Done)." >&2
exit 0
