# mux

A Claude Code session manager right inside your terminal.

`mux` shows every live Claude Code session running on your current tmux server in a floating
`fzf` overlay - sorted so the sessions **waiting on you** float to the top - with a live preview
of each. Press Enter to jump straight into a session; `ctrl-x` to kill one. The list refreshes
itself like a dashboard.

```
● waiting  ~/dev/api            2899m   │  <live preview of the
● waiting  ~/dev/web             304m   │   highlighted session's
● working  ~/dev/cli               0m   │   terminal screen>
● idle     ~/dev/infra            12m   │
○ ?        ~/dev/scratch          7m   │
Claude sessions - enter: jump - ctrl-x: kill
```

## How it works

Claude Code writes a status file per running process at `~/.claude/sessions/<pid>.json` containing
the session's `cwd`, `kind`, and a live `status` (`waiting` / `busy` / `idle`). `mux` reads those
files, keeps the interactive sessions (not sub-agents) whose process is still alive and whose pane
lives on your current tmux server, and renders them with Claude's own status colors. There is no
terminal scraping - status comes straight from that file.

## Requirements

- `tmux`
- `fzf` **>= 0.38** (needs `become`, `reload`, `--track`)
- `jq`
- `bash`, `ps` (the script runs on macOS's stock bash 3.2)

## Install

### With [TPM](https://github.com/tmux-plugins/tpm) (recommended)

Add this line to your `~/.tmux.conf`:

```tmux
set -g @plugin 'fashton28/mux'
```

Then press `prefix + I` to fetch the plugin. That's it - press **`prefix + u`** to open the overlay.

Want a different key? Set it before the `run '.../tpm'` line:

```tmux
set -g @mux-key 'C'   # default is 'u'
```

### Without TPM

`mux` is a single self-contained script - clone the repo and source the plugin file from your
`~/.tmux.conf`:

```tmux
run-shell '~/path/to/mux/mux.tmux'
```

Or skip tmux integration entirely and call the script directly (put `mux` on your `PATH`).

## Usage

| Key | Action |
|-----|--------|
| j / k | move selection down / up (vim) |
| J / K | scroll the preview pane down / up (shift) |
| ↑ / ↓ | move selection (preview follows) |
| type | fuzzy-filter the list (other letters; j/k/J/K are navigation) |
| Enter | jump to the selected session and close the overlay |
| ctrl-x | SIGTERM the selected session (its pane stays, drops to a shell) |
| Esc | close the overlay |

Sessions are sorted `waiting` → `working` → `idle` → `?`, and within each group the one that has
been in its status longest is shown first. The minutes column is time since the last status change.

You can also run the subcommands directly:

```sh
mux list                          # the formatted session list
mux preview <pane>                # a pane's live screen
mux jump <pane> <window> <session>
mux kill <pid>                    # SIGTERM a Claude session (guarded)
```

## Development

The session-listing logic lives behind one test seam: `mux list` reads its external inputs from
environment variables, so it is a pure, deterministic function for testing:

```sh
MUX_SESSIONS_DIR=tests/fixtures/sessions \
MUX_PANES_FILE=tests/fixtures/panes.txt \
MUX_PPID_FILE=tests/fixtures/ppids.txt \
MUX_NOW=1782657704 \
  mux list
```

Run the suite (requires [`bats`](https://github.com/bats-core/bats-core) and `shellcheck`):

```sh
bats tests/
shellcheck -s bash mux mux.tmux
```
