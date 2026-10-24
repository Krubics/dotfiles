#!/usr/bin/env bash
# Emits waybar JSON selecting a pikachu sprite via CSS class. The sprite itself
# lives in style.css as a background-image on #custom-battery-icon.<class>.
set -euo pipefail

BATTERY_SYSFS="${BATTERY_SYSFS:-/sys/class/power_supply/BAT0/capacity}"

log() {
  printf '[%s] pickachu-battery: %s\n' "$(date -Iseconds)" "$*" >&2
}

# A single space, not an empty string: waybar hides a custom module whose text
# is empty, and the space is what the background image paints behind.
emit() {
  printf '{"text":"%s","class":"%s"}\n' "$1" "$2"
}

capacity="${WAYBAR_BATTERY_CAPACITY:-}"

if [ -z "$capacity" ]; then
  if [ ! -r "$BATTERY_SYSFS" ]; then
    log "cannot read $BATTERY_SYSFS; hiding module"
    emit "" ""
    exit 0
  fi
  capacity=$(<"$BATTERY_SYSFS")
fi

if ! [[ "$capacity" =~ ^[0-9]+$ ]]; then
  log "non-numeric capacity '$capacity'; hiding module"
  emit "" ""
  exit 0
fi

if [ "$capacity" -gt 80 ]; then
  class=p100
elif [ "$capacity" -gt 60 ]; then
  class=p80
elif [ "$capacity" -gt 40 ]; then
  class=p60
elif [ "$capacity" -gt 20 ]; then
  class=p40
elif [ "$capacity" -gt 10 ]; then
  class=p20
else
  class=p10
fi

log "capacity=$capacity class=$class"
emit " " "$class"
