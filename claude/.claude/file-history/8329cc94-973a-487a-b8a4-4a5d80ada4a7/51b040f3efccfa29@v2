#!/usr/bin/env bash
# Emits a divider glyph only when the given monitor's active workspace has
# open windows, so the divider disappears entirely (no reserved space)
# alongside the native workspace-taskbar icons when the workspace is empty.
set -euo pipefail
MONITOR="${1:-$WAYBAR_OUTPUT_NAME}"

emit() {
  local ws count
  ws=$(hyprctl -j monitors | jq -r --arg m "$MONITOR" '.[] | select(.name == $m) | .activeWorkspace.id')
  count=$(hyprctl -j clients | jq -r --argjson ws "${ws:-0}" '[ .[] | select(.workspace.id == $ws) ] | length')
  if [ "${count:-0}" -gt 0 ]; then
    jq -nc '{text: "│"}'
  else
    jq -nc '{text: ""}'
  fi
}

emit

socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | \
while read -r line; do
  case "$line" in
    openwindow*|closewindow*|movewindow*|workspace*|activewindow*|focusedmon*)
      emit
      ;;
  esac
done
