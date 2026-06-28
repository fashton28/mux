#!/usr/bin/env bash
#
# TPM entrypoint for mux. When installed via the Tmux Plugin Manager, TPM
# sources every *.tmux file in the plugin root; this one binds the overlay key.
#
#   set -g @plugin 'fashton28/mux'      # in ~/.tmux.conf, then press prefix + I
#
# The overlay opens on  prefix + u  by default. Override it with:
#
#   set -g @mux-key 'C'                 # any single key after the prefix
#
# The bundled `mux` script is run by absolute path, so nothing needs to be on
# PATH for the keybinding to work.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mux_option() {
  local value
  value="$(tmux show-option -gqv "$1")"
  if [ -n "$value" ]; then echo "$value"; else echo "$2"; fi
}

key="$(mux_option "@mux-key" "u")"

tmux bind-key "$key" display-popup -E -w 90% -h 90% "$CURRENT_DIR/mux"
