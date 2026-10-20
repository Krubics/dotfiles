# Fix Waybar height jump on workspace switch

## Context
The Waybar bar changes height when switching Hyprland workspaces. Root cause is an
asymmetry in `~/.config/waybar/style.css`:

- The **active** workspace button (`#workspaces:not(.taskbar) button.active`, lines 30–44)
  defines a tall box: `min-height: 20px`, `padding: 4px 4px`, `margin: 4px 0px`, and a
  visible `border: 1px solid @outline` (the pokeball accent pill).
- The **inactive** workspace buttons have **no CSS rule**, so they render at GTK default
  size (shorter, no border, less padding).

Because a workspace lives on only one monitor in Hyprland and the module uses
`all-outputs: true`, a bar on a non-focused monitor has *no* `.active` button — so its
workspaces module collapses to the short inactive height. When focus moves to that
monitor, the tall active pill is inserted and the module (and the whole bar pill) grows.
That is the shrink/grow the user is seeing.

**Intended outcome:** the workspaces module keeps a constant height whether or not an
active button is present, so the bar never resizes on workspace switch. Activation should
only change the *appearance* (background color, border color, pokeball image), not the box
geometry.

## Change
Single file: `/home/krubics/.config/waybar/style.css`.

Add a base rule for **all** main workspace buttons that reserves the same vertical box the
active button uses, with a **transparent** border (same 1px width, so no layout shift), then
let `.active` override only the visual properties.

Insert before the existing `.active` rule (line 30):

```css
/* Reserve identical geometry on every workspace button so toggling .active only
   swaps colors + the pokeball image, never the box size. Without this, inactive
   buttons fall back to smaller GTK defaults and the bar changes height whenever an
   active button appears/disappears (e.g. focusing a workspace on another monitor). */
#workspaces:not(.taskbar) button {
    padding: 4px 4px;
    margin: 4px 0px;
    min-width: 20px;
    min-height: 20px;
    border: 1px solid transparent; /* same 1px as .active, but invisible */
    border-radius: 10px;
}
```

Then trim the existing `#workspaces:not(.taskbar) button.active` rule (lines 30–44) so it
only carries the properties that actually differ when active — the box metrics now come
from the base rule and can be removed from it:

- Keep: `background-image`, `background-position`, `background-repeat`, `background-size`,
  `background-origin`, `background-color: @primary`, `color: transparent`,
  `border: 1px solid @outline` (this overrides the transparent border with the visible one).
- Remove from `.active` (now redundant / inherited from base): `padding`, `margin`,
  `min-width`, `min-height`, `border-radius`.

Net effect: active and inactive buttons occupy the exact same 1px-bordered, padded,
margined box; only the fill/border color and pokeball differ. Module height is constant.

## Verification
1. Reload Waybar so the CSS takes effect: `killall -SIGUSR2 waybar` (or restart it the way
   the user's Hyprland config launches it).
2. Switch between workspaces on the **same** monitor and confirm the bar no longer changes
   height as the pokeball moves.
3. If multi-monitor: move focus between monitors and confirm the bar on the
   newly-focused/unfocused monitor stays the same height (the original trigger).
4. Confirm the active workspace still shows the pokeball accent pill and inactive
   workspaces still show their number, unchanged visually apart from the constant height.
