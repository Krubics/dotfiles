#!/usr/bin/env bash
# Launch yazi in a fresh ghostty window.
#
# ~/.config/ghostty/config sets gtk-single-instance=true (left untouched —
# the user relies on it for normal desktop usage). A plain
# `ghostty --gtk-single-instance=false -e yazi` is NOT enough to force a
# fresh instance: GTK's GApplication still races to register on the D-Bus
# session bus, and it frequently loses to the already-running primary
# ghostty, which then hands the launch off to that instance and silently
# drops `-e yazi` (no yazi, no new window).
#
# Fix: run the child with DBUS_SESSION_BUS_ADDRESS unset. GApplication can't
# reach the session bus, so it can't perform single-instance activation at
# all and just runs as a normal standalone process. Verified reliable across
# 10/10 test launches (each producing a real window + yazi process), vs. the
# flag-only approach which failed intermittently.
#
# Usage: yazi.sh [path ...]   (paths forwarded to yazi; defaults to cwd)
set -euo pipefail

if command -v ghostty >/dev/null 2>&1; then
  exec env -u DBUS_SESSION_BUS_ADDRESS ghostty --gtk-single-instance=false -e yazi "$@"
elif command -v kitty >/dev/null 2>&1; then
  exec kitty yazi "$@"
else
  echo "yazi.sh: no supported terminal found (need ghostty or kitty)" >&2
  exit 1
fi
