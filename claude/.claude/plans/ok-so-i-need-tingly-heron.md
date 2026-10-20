# Per-Monitor Pokeball on Waybar

## Context

The "pokeball" is not a module — it's a CSS background image painted on the
**active** workspace button of the native `hyprland/workspaces` module
(`style.css:30`), using `assets/pokeball.png`.

Today that module has `"all-outputs": true`, so Waybar renders an identical
workspace list on **every** monitor's bar and highlights the single
**globally-focused** workspace on all of them. Result: both monitors' pokeballs
jump together whenever focus moves between monitors.

Goal: each monitor's bar should show the pokeball on **its own** active
workspace, independently. Switching focus/workspaces on one monitor must not
move the other monitor's pokeball.

Chosen approach (confirmed with user): the minimal **native** solution —
`all-outputs: false` so each bar filters to its own monitor's workspaces. Each
bar then shows only that monitor's workspaces, which is accepted.

## Changes

### 1. `/home/krubics/.config/waybar/config.jsonc`

In the `"hyprland/workspaces"` module (lines 27-33), flip:

```jsonc
"all-outputs": false,   // was true
```

This makes each bar instance render only the workspaces on its own monitor
(the bar's `$WAYBAR_OUTPUT_NAME`). The `hyprland/workspaces#taskbar` module
already uses `all-outputs: false`, so this is consistent with existing config.

### 2. `/home/krubics/.config/waybar/style.css`

The pokeball rule (lines 30-44) currently targets only `button.active`. With
`all-outputs: false`:

- The **focused** monitor's bar marks its displayed workspace `.active`.
- A **non-focused** monitor's bar marks its displayed workspace `.visible`
  (Waybar's "visible but not active" class), **not** `.active`.

So targeting only `.active` would leave non-focused monitors with **no**
pokeball. Add `.visible` to the selector so every monitor always shows a
pokeball on its own current workspace:

```css
#workspaces:not(.taskbar) button.active,
#workspaces:not(.taskbar) button.visible {
    /* existing pokeball background rules unchanged */
}
```

No new selectors get contaminated: because `all-outputs: false` filters each
bar to its own monitor's workspaces (and there are no `persistent-workspaces`),
each bar only contains one displayed workspace to mark — so exactly one pokeball
per bar.

## Verification

1. Reload Waybar to pick up config + CSS: `pkill -SIGUSR2 waybar`
   (SIGUSR2 = reload; falls back to `pkill waybar` then relaunch `waybar` if the
   signal reload misbehaves).
2. With workspaces open on both monitors (e.g. ws1 on `eDP-1`, ws3 on
   `HDMI-A-1`), confirm **each** bar shows the pokeball on its own monitor's
   active workspace — cross-check against
   `hyprctl -j monitors | jq '.[] | {name, focused, activeWorkspace: .activeWorkspace.id}'`.
3. Move focus between monitors (mouse or focus bind): the **unfocused** monitor's
   pokeball must stay put; only behavior consistent with each monitor's own
   active workspace should change.
4. Switch the workspace on one monitor (SUPER+N): only **that** monitor's
   pokeball moves; the other monitor's is unaffected.

## Notes / non-goals

- Keeping all 9 workspace numbers on every bar was explicitly declined in favor
  of this minimal approach. If wanted later, it requires replacing the native
  module with per-output custom script modules (hyprctl + `$WAYBAR_OUTPUT_NAME`
  + socket2) — out of scope here.
- No scripts, signals, or intervals are added; the native module + Hyprland's
  socket2 (which Waybar already listens to) drive the updates.
