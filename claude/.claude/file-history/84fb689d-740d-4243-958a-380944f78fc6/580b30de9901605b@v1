#!/usr/bin/env bash
# Force running GTK3 apps to re-parse ~/.config/gtk-3.0/gtk.css (which @imports
# the matugen-generated colors.css). GTK3 does NOT watch the file, so we trigger
# a reload by changing Net/ThemeName. We drive BOTH propagation channels:
#   - xsettingsd  -> X11 / XWayland GTK apps
#   - gsettings   -> native Wayland GTK apps
# GTK only reloads on an actual value CHANGE, so we flip to a dummy and back.
set -uo pipefail

MODE="${1:-dark}"                       # matugen passes {{mode}} as $1
THEME="adw-gtk3-${MODE}"
XCONF="${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf"
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/matugen-gtk3-reload.log"
mkdir -p "$(dirname "$LOG")"

log() { printf '%s [gtk3-reload] %s\n' "$(date '+%F %T')" "$*" >>"$LOG"; }

log "start: mode=${MODE} theme=${THEME}"

# --- Channel 1: xsettingsd (X11 / XWayland apps) --------------------------
if command -v xsettingsd >/dev/null 2>&1; then
  if [[ -f "$XCONF" ]]; then
    # Ensure xsettingsd is actually running; without it nothing propagates.
    if ! pgrep -x xsettingsd >/dev/null 2>&1; then
      log "xsettingsd not running -> launching it"
      setsid xsettingsd -c "$XCONF" >/dev/null 2>&1 &
      sleep 0.3
    fi

    set_theme() {
      # Rewrite (or append) the Net/ThemeName line, then SIGHUP to apply.
      if grep -q '^Net/ThemeName' "$XCONF"; then
        sed -i "s|^Net/ThemeName.*|Net/ThemeName \"$1\"|" "$XCONF"
      else
        printf 'Net/ThemeName "%s"\n' "$1" >>"$XCONF"
      fi
      pkill -HUP -x xsettingsd 2>/dev/null
    }

    set_theme "Adwaita"        # dummy value -> forces a delta
    sleep 0.15
    set_theme "$THEME"         # back to the real theme -> second reload
    log "xsettingsd: toggled Net/ThemeName -> $THEME"
  else
    log "WARN: $XCONF missing; skipped xsettingsd channel"
  fi
else
  log "xsettingsd not installed; skipped X11 channel"
fi

# --- Channel 2: gsettings (native Wayland apps) ---------------------------
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme "" 2>/dev/null
  gsettings set org.gnome.desktop.interface gtk-theme "$THEME" 2>/dev/null
  log "gsettings: toggled gtk-theme -> $THEME"
else
  log "gsettings not available; skipped Wayland channel"
fi

log "done"
