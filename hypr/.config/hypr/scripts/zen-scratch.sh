#!/bin/sh
# Scratchpad Zen browser — isolated profile, forced new instance, so it's a
# genuinely separate process pyprland can track by PID (safe: no shared
# class="zen" ambiguity with your regular Zen windows). First-ever launch
# creates the profile (~1-13s depending on system load); every launch after
# is fast (~1s) since the profile already exists.
#
# The local HTML file below sets the *page* title to "zen-scratch-marker",
# which Zen folds into the OS window title. pyprland's [scratchpads.browser]
# in ~/.config/pypr/config.toml matches on that title regex — without this,
# there is nothing distinguishing this window from a normal Zen window and
# toggling would never find/hide it.
#
# A data: URL was tried and REJECTED: verified live that Firefox-based
# browsers (Zen included) silently refuse to navigate to a data: URL passed
# as a command-line argument (security restriction), so the window title
# stayed the generic "Zen Browser" and title-matching never fired. A real
# file:// URL has no such restriction.
MARKER_PAGE="$HOME/.config/hypr/scripts/zen-scratch-marker.html"
mkdir -p "$HOME/.zen-scratch"
exec zen --new-instance --profile "$HOME/.zen-scratch" "file://$MARKER_PAGE"
