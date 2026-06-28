#!/usr/bin/env bats
#
# Tests for `mux list` (and the `mux kill` safety guard) via the injectable seam.
# These run with no live tmux server and no real Claude processes - everything
# is driven from committed fixtures + a frozen clock.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  MUX="$REPO/mux"
  FIX="$BATS_TEST_DIRNAME/fixtures"

  # HOME is pinned so ~-abbreviation of fixture paths is machine-independent.
  export HOME=/home/tester
  export MUX_SESSIONS_DIR="$FIX/sessions"
  export MUX_PANES_FILE="$FIX/panes.txt"
  export MUX_PPID_FILE="$FIX/ppids.txt"
  export MUX_NOW=1782657704
}

# Strip ANSI color escapes for content/ordering assertions.
strip_ansi() { sed $'s/\x1b\\[[0-9;]*m//g'; }

# The pid is the last tab-separated field of every row.
pids() { awk -F'\t' '{print $NF}'; }

@test "lists exactly the live, interactive, this-server sessions" {
  run "$MUX" list
  [ "$status" -eq 0 ]
  # 5 included (100,101,102,103,106); 104 off-server and 105 sub-agent excluded.
  count=$(printf '%s\n' "$output" | grep -c .)
  [ "$count" -eq 5 ]
}

@test "off-server session (unresolvable pane) is excluded" {
  run "$MUX" list
  ! printf '%s\n' "$output" | pids | grep -qx 104
}

@test "non-interactive (sub-agent) session is excluded" {
  run "$MUX" list
  ! printf '%s\n' "$output" | pids | grep -qx 105
}

@test "sorts waiting first, then working, then idle, then unknown" {
  run "$MUX" list
  order=$(printf '%s\n' "$output" | pids | tr '\n' ' ')
  [ "$order" = "100 101 102 103 106 " ]
}

@test "within waiting, the longest-waiting session is on top" {
  run "$MUX" list
  first=$(printf '%s\n' "$output" | head -1 | pids)
  second=$(printf '%s\n' "$output" | sed -n 2p | pids)
  [ "$first" = "100" ]   # 2899m
  [ "$second" = "101" ]  # 304m
}

@test "minutes column is computed from statusUpdatedAt and the frozen clock" {
  run "$MUX" list
  line=$(printf '%s\n' "$output" | strip_ansi | grep alpha)
  [[ "$line" == *2899m* ]]
}

@test "unknown status renders as ? and falls back to updatedAt for minutes" {
  run "$MUX" list
  line=$(printf '%s\n' "$output" | strip_ansi | grep foxtrot)
  [[ "$line" == *"?"* ]]
  [[ "$line" == *7m* ]]   # updatedAt fallback
}

@test "status labels map to working/idle/waiting" {
  run "$MUX" list
  out=$(printf '%s\n' "$output" | strip_ansi)
  [[ "$out" == *waiting* ]]
  [[ "$out" == *working* ]]
  [[ "$out" == *idle* ]]
}

@test "rows carry the canonical Claude status colors" {
  run "$MUX" list
  [[ "$output" == *$'\033[38;2;95;135;255m'* ]]   # waiting = blue
  [[ "$output" == *$'\033[38;2;255;149;0m'* ]]    # working = orange
  [[ "$output" == *$'\033[38;2;0;215;95m'* ]]     # idle = green
  [[ "$output" == *$'\033[38;2;136;136;136m'* ]]  # unknown = grey
}

@test "paths are abbreviated with ~" {
  run "$MUX" list
  printf '%s\n' "$output" | strip_ansi | grep -q '~/dev/alpha'
}

@test "shows the tmux session name column" {
  run "$MUX" list
  out=$(printf '%s\n' "$output" | strip_ansi)
  # pid 100 (alpha) lives in tmux session 'main'; pid 103 (delta) in 'work'
  printf '%s\n' "$out" | grep alpha | grep -q 'main'
  printf '%s\n' "$out" | grep delta | grep -q 'work'
}

@test "empty sessions dir yields the placeholder, no session rows" {
  empty="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$empty"
  MUX_SESSIONS_DIR="$empty" run "$MUX" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"no live Claude sessions"* ]]
  ! printf '%s\n' "$output" | grep -q '~/dev'
}

@test "kill refuses a pid that is not a known session" {
  run "$MUX" kill 999999
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a known Claude session"* ]]
}

@test "kill refuses a non-interactive session" {
  run "$MUX" kill 105
  [ "$status" -ne 0 ]
  [[ "$output" == *"not an interactive"* ]]
}

@test "kill refuses a non-numeric pid" {
  run "$MUX" kill nonsense
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid pid"* ]]
}

@test "kill proceeds for a valid interactive session (dry run)" {
  MUX_KILL_DRY_RUN=1 run "$MUX" kill 100
  [ "$status" -eq 0 ]
  [[ "$output" == *"would SIGTERM 100"* ]]
}
