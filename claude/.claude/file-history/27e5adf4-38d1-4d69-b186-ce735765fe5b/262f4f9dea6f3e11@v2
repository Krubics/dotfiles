# Waybar: pin workspaces 1–9, and fix the missing ghostty icon

## Context

Two unrelated symptoms on the same bar, both now diagnosed.

**1. "An extra workspace with nothing inside."** `hyprctl workspaces` reports workspaces
1/2/3 on `HDMI-A-1` and workspace **4 on `eDP-1` with zero windows**. Hyprland always keeps
exactly one active workspace alive per connected monitor and never destroys it, even when
empty — so while the laptop panel is on, workspace 4 exists. `config.jsonc:29` sets
`"all-outputs": true`, so the external monitor's bar renders it. Nothing is broken.

The real want, per the user: **a stable row of workspaces 1–9**, always present, rather than
buttons that appear and vanish as workspaces get created and destroyed. That is
`persistent-workspaces`.

**2. Ghostty has no taskbar icon.** A tempting false lead: Papirus *does* ship
`com.mitchellh.ghostty.svg` (six sizes under `/usr/share/icons/Papirus/*/apps/`), so the icon
theme is *not* the problem and swapping themes would not help. The failure is one step
earlier, in the window-class → app lookup. The only file declaring
`StartupWMClass=com.mitchellh.ghostty` is the snap's exported entry at
`/var/lib/snapd/desktop/applications/ghostty_ghostty.desktop`. Reading waybar's live
environment (`/proc/<waybar-pid>/environ`) shows **`XDG_DATA_DIRS` is not set at all**, and
`/etc/profile.d/snapd.sh` — the script that normally appends snapd's directory — does not
exist on this machine. With the variable unset, GLib falls back to the spec default
`/usr/local/share:/usr/share`, which is exactly why `code` and `google-chrome` resolve (their
desktop files live in `/usr/share/applications`) while **every snap silently fails**.

Intended outcome: a fixed 1–9 workspace row, and ghostty (plus any future snap) showing its
icon.

## Decisions taken

- Pin **1–9**. Accepted caveat: `SUPER+0` → workspace 10 (`conf/keybinds.lua:105`) remains
  bound, so a transient 10th button will still appear when workspace 10 holds a window. The
  `SUPER+0` binds are left alone.
- Fix ghostty **both** ways: the durable env var, plus a local desktop-file copy that takes
  effect without a full session restart.

## Verified facts this plan relies on

- Waybar **v0.14.0**.
- `createWorkspace()` in `src/modules/hyprland/workspaces.cpp` dedups by workspace id
  (`w->id() == workspaceId`). The `"*"` key applies per-monitor, but the second monitor's pass
  finds the existing id and only updates persistence flags. So `"*": [1..9]` with
  `all-outputs: true` yields **9 buttons, not 18**. `all-outputs` can stay `true`.
- `style.css` has no base `#workspaces button` rule — only
  `#workspaces:not(.taskbar) button.active` (`style.css:30`) and `#workspaces.taskbar button`.
  Inactive workspaces already render as plain numbers, so six more need **no new assets and no
  CSS change**.
- `ghostty_ghostty.desktop` already contains a correct absolute
  `Icon=/snap/ghostty/current/share/icons/hicolor/512x512/apps/com.mitchellh.ghostty.png`
  (file exists) and `StartupWMClass=com.mitchellh.ghostty`. Nothing in it needs editing.

## Changes

### 1. `~/.config/waybar/config.jsonc` — pin workspaces 1–9

In the **`"hyprland/workspaces"`** block (lines 27–33) add one key. Leave `all-outputs: true`.

```jsonc
"hyprland/workspaces": {
  "format": "{name}",
  "all-outputs": true,
  "ignore-hidden": false,
  "on-click": "activate",
  "tooltip": false,
  "persistent-workspaces": { "*": [1, 2, 3, 4, 5, 6, 7, 8, 9] },
},
```

**Do not** add this to `"hyprland/workspaces#taskbar"` (lines 47–60). That module is a
different thing — `active-only: true` + `format: "{windows}"` renders the *window list* of the
current workspace. Pinning workspaces there would produce nine window-lists.

### 2. `~/.config/hypr/hyprland.lua` — export `XDG_DATA_DIRS`

In the `ENVIRONMENT VARIABLES` section, beside the existing `hl.env("XCURSOR_THEME", ...)`
calls (~line 67):

```lua
-- snapd exports .desktop files here; without this, waybar cannot map a snap's
-- window class to its app entry and renders no icon. The two defaults must be
-- listed explicitly: XDG_DATA_DIRS is otherwise unset, and GLib's implicit
-- fallback to /usr/local/share:/usr/share is lost the moment we set the var.
hl.env("XDG_DATA_DIRS", "/var/lib/snapd/desktop:/usr/local/share:/usr/share")
```

The trap is in that comment and it is the one thing to get right: because the variable is
currently **unset**, setting it without re-listing `/usr/local/share:/usr/share` would break
the Chrome and VS Code icons that work today.

Hyprland's `env` only applies to processes it spawns afterward; `hyprctl reload` will **not**
re-export it into the already-running waybar. This takes effect on the next session start.

### 3. Copy the snap desktop entry (immediate effect)

`XDG_DATA_HOME=/home/krubics/.local/share` is already set, so `~/.local/share/applications`
is searched today.

```sh
cp /var/lib/snapd/desktop/applications/ghostty_ghostty.desktop \
   ~/.local/share/applications/
update-desktop-database ~/.local/share/applications 2>/dev/null || true
```

This is what makes the icon appear before a reboot. It is redundant once change #2 is live;
harmless to keep.

## Verification

1. **Workspaces, no restart needed:**
   `killall -SIGUSR2 waybar` (reload) — or restart waybar. The bar should show exactly
   `1 2 3 4 5 6 7 8 9`, with the pokeball sprite on the active one. Confirm **nine** buttons,
   not eighteen — that is the `all-outputs` dedup claim being tested for real.
2. Press `SUPER+5` (an empty pinned workspace). The button should already have existed and
   simply become active, rather than popping into being.
3. **Ghostty icon:** after step 3 above, restart waybar and confirm the ghostty window in the
   taskbar module now renders its icon alongside `code` and `google-chrome`.
4. **No regression:** confirm the `code` and `google-chrome` icons still render — this is the
   check that catches a botched `XDG_DATA_DIRS` value.
5. **Durable path:** log out and back into Hyprland, then
   `tr '\0' '\n' < /proc/$(pgrep -x waybar)/environ | grep XDG_DATA_DIRS`
   should print the three-entry list. Temporarily move the copied desktop file aside and
   confirm the icon *still* renders — proving change #2 works on its own.

## Notes / loose ends

- The absent `/etc/profile.d/snapd.sh` is itself unusual for a snapd install and suggests the
  session (`start-hyprland`) never sources login-shell profile scripts. Out of scope here, but
  it is the underlying reason and may bite other snap integrations.
- I did not read waybar's icon-resolution source to prove it *only* uses the desktop-entry
  path and never falls back to the raw class as an icon name. The evidence (Papirus has the
  icon; it still does not render) says the desktop-entry path is where it breaks either way,
  so the fix holds regardless. Step 5 is what actually confirms it.
