# Convert waybar `image` modules to CSS `background-image`

## Context

The waybar config uses four native `image` modules (`image#clock`, `image#network`,
`image#bluetooth`, `image#battery`) to render pokemon sprites. Waybar's `image` module
sizes via a single `size:` value that acts as a **bounding box**, not a height. Because
the sprites have different aspect ratios, the rendered heights don't match:

| Module | Sprite | Intrinsic size | Aspect | `size:` | Rendered |
|---|---|---|---|---|---|
| `image#clock` | `dialga.png` | 800×800 | 1:1 | 32 | 32×32 |
| `image#network` | `pixelated-wooper.png` | 256×256 | 1:1 | 32 | 32×32 |
| `image#bluetooth` | `pixelated-magneton.png` | 364×364 | 1:1 | 32 | 32×32 |
| `image#battery` | `*-percent-pikachu.png` | 677×200 | 3.385:1 | 115 | 115×**34** |

The pokeball (`style.css:22-35`) already demonstrates the fix: a CSS `background-image`
on a normal label/button, with the box sized explicitly. That decouples height from
aspect ratio, so every sprite can share one height.

**Outcome:** all five images (four pokemon + pokeball) render at a uniform **26px** tall,
driven entirely from `style.css`. Sprite selection for battery moves from "script echoes
a file path" to "script echoes a CSS class".

Three incidental problems get fixed along the way:

1. **`pickachu-battery.sh` is half-broken today.** It echoes `80-percent-pikachu.png`,
   `60-percent-pikachu.png`, and `10-percent-pikachu.png`, but the files on disk are
   `80-percent-pickachu.png`, `60-percent-pikachi.png`, and `10-percent-pickachu.png`.
   Three of six battery states silently render nothing.
2. **Orphaned icons.** `network` hides itself when disconnected and `bluetooth` hides
   when disabled, but `image#network` / `image#bluetooth` stay onscreen regardless.
3. **Duplicate JSON key.** `config.jsonc:79-80` defines `"format-disconnected"` twice.

---

## Decisions (confirmed with user)

- Battery keeps its script, rewritten to emit JSON (`{"text":" ","class":"p80"}`) instead of a file path.
- Uniform icon height: **26px**. Bar `height` goes 34 → 38.
- Icons hide whenever their sibling module hides.
- Tooltips disabled on every module.
- All images consolidated into `assets/` and renamed consistently.

---

## Step 1 — Consolidate and rename image assets

Everything is CSS-referenced after this change, so the `images/` vs `assets/` split
stops meaning anything. Move all sprites into `assets/` and delete `images/`.

```
images/dialga.png                → assets/dialga.png
images/pixelated-wooper.png      → assets/wooper.png
images/pixelated-magneton.png    → assets/magneton.png
images/100-percent-pikachu.png   → assets/pikachu-100.png
images/80-percent-pickachu.png   → assets/pikachu-80.png
images/60-percent-pikachi.png    → assets/pikachu-60.png
images/40-percent-pikachu.png    → assets/pikachu-40.png
images/20-percent-pikachu.png    → assets/pikachu-20.png
images/10-percent-pickachu.png   → assets/pikachu-10.png
assets/pixelated-pokeball.png    → assets/pokeball.png
```

This directory is not a git repo, so plain `mv`, then `rmdir images/`.

---

## Step 2 — Rewrite `scripts/pickachu-battery.sh`

**File:** `/home/krubics/.config/waybar/scripts/pickachu-battery.sh`

Emit waybar JSON instead of a path. `text` must be a single space — waybar's custom
module hides the widget when `text` is empty, and the space is what the background
image paints behind.

Requirements:

- `#!/usr/bin/env bash`, `set -euo pipefail`.
- Read `/sys/class/power_supply/BAT0/capacity`. If the file is missing or unreadable,
  log to stderr and emit an empty `text` so the module hides rather than showing a
  stale sprite. Exit 0 regardless — a non-zero exit makes waybar respawn the module.
- Allow `WAYBAR_BATTERY_CAPACITY` to override the sysfs read, and `BATTERY_SYSFS` to
  override the path. These are what make all six branches testable without draining a
  battery (see Verification).
- Log the resolved capacity and chosen class to stderr with an ISO-8601 timestamp;
  waybar surfaces stderr in its own log, and stdout stays clean JSON.
- Same thresholds as today, so behavior is unchanged:

  | Capacity | Class |
  |---|---|
  | `> 80` | `p100` |
  | `> 60` | `p80` |
  | `> 40` | `p60` |
  | `> 20` | `p40` |
  | `> 10` | `p20` |
  | else | `p10` |

- Output exactly: `{"text":" ","class":"<class>"}`

The `text` value carries no capacity number — the existing `battery` text module still
renders `{capacity}%` next to it.

---

## Step 3 — Rework `config.jsonc`

**File:** `/home/krubics/.config/waybar/config.jsonc`

### 3a. Bar height

`"height": 34` → `"height": 38`.

Box math per icon: 26px content + 2px padding × 2 + 4px margin × 2 = 38px.

### 3b. Replace the four `image#*` modules

Delete `image#clock`, `image#network`, `image#bluetooth`, `image#battery` entirely.
Replace them in `modules-left` / `modules-right` at the **same positions** (note
`image#battery` currently sits *after* the `battery` text module — preserve that):

| Old | New | Widget selector | Hides when |
|---|---|---|---|
| `image#clock` | `custom/clock-icon` | `#custom-clock-icon` | never |
| `image#network` | `network#icon` | `#network.icon` | disconnected |
| `image#bluetooth` | `bluetooth#icon` | `#bluetooth.icon` | disabled |
| `image#battery` | `custom/battery-icon` | `#custom-battery-icon` | sysfs read fails |

**`custom/clock-icon`** — a static label, no `exec`. This mirrors the existing
`custom/divider` (`config.jsonc:41-43`), which already proves a `custom/` module with
only a `format` works:

```jsonc
"custom/clock-icon": {
  "format": " ",
  "tooltip": false,
},
```

**`network#icon`** — reusing the built-in `network` module (rather than a static
`custom/` one) is what makes the wooper disappear alongside the network text. An empty
`format-disconnected` is the same mechanism the existing `network` module already uses
to hide itself.

```jsonc
"network#icon": {
  "interface": "wlo1",
  "format": " ",
  "format-wifi": " ",
  "format-ethernet": " ",
  "format-disconnected": "",
  "tooltip": false,
},
```

**`bluetooth#icon`** — same idea, keyed on `format-disabled`:

```jsonc
"bluetooth#icon": {
  "format": " ",
  "format-connected": " ",
  "format-disabled": "",
  "tooltip": false,
},
```

The `#icon` suffix becomes a CSS class on the widget. This is the same mechanism
`hyprland/workspaces#taskbar` already relies on for its `#workspaces.taskbar` selector
(`style.css:43`), so the pattern is already proven in this config.

**`custom/battery-icon`**:

```jsonc
"custom/battery-icon": {
  "exec": "/home/krubics/.config/waybar/scripts/pickachu-battery.sh",
  "return-type": "json",
  "interval": 30,
  "tooltip": false,
},
```

### 3c. Disable tooltips everywhere

Waybar has no global tooltip switch — it's per-module. Add `"tooltip": false` to
`clock`, `network`, `bluetooth`, `battery`, `hyprland/workspaces`,
`hyprland/workspaces#taskbar`, `custom/divider`, `custom/taskbar-divider`, and the four
new icon modules.

Leave the existing `tooltip-format*` keys in place. They become inert, but keeping them
means flipping `"tooltip": true` later restores the old text with no rework.

### 3d. Fix the duplicate key

`config.jsonc:79-80` declares `"format-disconnected"` twice inside `network`. Keep one
declaration, preserving the `//An empty format will hide the module.` comment.

---

## Step 4 — Add the CSS

**File:** `/home/krubics/.config/waybar/style.css`

Reuse the exact pattern from the existing pokeball rule (`style.css:22-35`):
`background-image` + `no-repeat` + `center` + `contain` + `background-origin: content-box`,
with the box sized by `min-width` / `min-height`.

`background-size: contain` fits the sprite *inside* the content box, so rendered height is
`min(box_height, box_width / aspect)`. For height to actually land on 26px, each box must
be at least `26 × aspect` wide:

| Selector | Sprite | Aspect | `min-width` | `min-height` |
|---|---|---|---|---|
| `#custom-clock-icon` | `dialga.png` | 1:1 | 26px | 26px |
| `#network.icon` | `wooper.png` | 1:1 | 26px | 26px |
| `#bluetooth.icon` | `magneton.png` | 1:1 | 26px | 26px |
| `#custom-battery-icon` | `pikachu-*.png` | 3.385:1 | **88px** | 26px |
| `#workspaces:not(.taskbar) button.active` | `pokeball.png` | 1:1 | 26px | 26px |

Structure it as one shared rule plus per-module `background-image` overrides, so the box
geometry lives in exactly one place:

```css
/* Shared geometry for every CSS-backed sprite. 26px content + 2px padding
   + 4px margin = 38px, matching the bar height. */
#custom-clock-icon,
#network.icon,
#bluetooth.icon,
#custom-battery-icon {
    background-position: center;
    background-repeat: no-repeat;
    background-size: contain;
    background-origin: content-box;
    color: transparent; /* hides the placeholder space glyph */
    min-width: 26px;
    min-height: 26px;
    padding: 2px;
    margin: 4px 0;
}

#custom-clock-icon { background-image: url('/home/krubics/.config/waybar/assets/dialga.png'); }
#network.icon      { background-image: url('/home/krubics/.config/waybar/assets/wooper.png'); }
#bluetooth.icon    { background-image: url('/home/krubics/.config/waybar/assets/magneton.png'); }

/* 26px x 3.385 aspect ratio; contain letterboxes short without the full width */
#custom-battery-icon { min-width: 88px; }

#custom-battery-icon.p100 { background-image: url('/home/krubics/.config/waybar/assets/pikachu-100.png'); }
#custom-battery-icon.p80  { background-image: url('/home/krubics/.config/waybar/assets/pikachu-80.png'); }
#custom-battery-icon.p60  { background-image: url('/home/krubics/.config/waybar/assets/pikachu-60.png'); }
#custom-battery-icon.p40  { background-image: url('/home/krubics/.config/waybar/assets/pikachu-40.png'); }
#custom-battery-icon.p20  { background-image: url('/home/krubics/.config/waybar/assets/pikachu-20.png'); }
#custom-battery-icon.p10  { background-image: url('/home/krubics/.config/waybar/assets/pikachu-10.png'); }
```

Also update the existing pokeball rule: point `background-image` at the renamed
`assets/pokeball.png`, and raise `min-width` / `min-height` from `22px` to `26px` so the
center pill's content height matches the left and right pills.

**Fallback if `contain` misbehaves:** GTK3 also accepts `background-size: auto 26px`,
which pins the height and derives width from the intrinsic aspect ratio, removing the
dependence on `min-width` being wide enough. Prefer `contain` since it's the pattern
already working in this file; switch only if the pikachu renders letterboxed.

---

## Step 5 — Tune the bar

`height` in waybar is a *request*, not a cap: GTK grows the window when content needs more
room. The `.modules-*` pills add `6px` margin + `4px` padding vertically (20px), so with a
38px icon box the pills want 58px. The bar is already in this state today (the pokeball's
34px box inside those same pills), so this is not a regression — but with icons 4px taller
than before, the bar will grow ~4px.

If the result is too tall, reduce `.modules-left/.modules-center/.modules-right`
`margin: 6px 4px` and `padding: 4px 8px` (`style.css:12-19`) rather than shrinking the
icons. Confirm visually in Verification step 5 before touching anything.

---

## Verification

1. **Script emits valid JSON for every state.** The capacity override makes all six
   branches reachable:
   ```bash
   for c in 95 75 55 35 15 5; do
     WAYBAR_BATTERY_CAPACITY=$c /home/krubics/.config/waybar/scripts/pickachu-battery.sh | jq -c .
   done
   ```
   Expect `p100, p80, p60, p40, p20, p10` in order, each with `"text": " "`.

2. **Missing-battery path degrades safely.**
   ```bash
   BATTERY_SYSFS=/nonexistent /home/krubics/.config/waybar/scripts/pickachu-battery.sh | jq -c .
   echo "exit=$?"
   ```
   Expect empty `text` (module hides), a stderr log line, and `exit=0`.

3. **Every CSS url resolves.** Guards against typo'd filenames recurring:
   ```bash
   grep -o "url('[^']*')" /home/krubics/.config/waybar/style.css \
     | sed "s/url('//;s/')//" | while read -r f; do
         [ -f "$f" ] || echo "MISSING: $f"
       done
   ```
   Expect no output.

4. **Config parses and CSS has no errors.** Run a throwaway instance and read the log:
   ```bash
   waybar -l debug 2>&1 | grep -iE 'error|warning|css'
   ```
   GTK reports unparsed CSS properties here. `background-size: contain` and
   `background-origin` should be silent; anything flagged means falling back to Step 4's
   `auto 26px` form.

5. **Visual check.** Reload the running bar with `killall -SIGUSR2 waybar`, then confirm by
   eye: dialga, wooper, magneton and pikachu all share one height; the pokeball sits at the
   same height; the bar isn't clipped.

6. **Hiding behavior.** `nmcli radio wifi off` — wooper and the network text should both
   disappear, then both return on `nmcli radio wifi on`. Same for `bluetoothctl power off`
   / `on` and the magneton.

7. **Live battery class.** Inspect the running widget's CSS classes with
   `GTK_DEBUG=interactive waybar`, or unplug AC and watch the sprite change bucket at the
   80/60/40/20/10 boundaries.

---

## Files touched

- `/home/krubics/.config/waybar/config.jsonc` — remove 4 `image#*` modules, add 4 icon modules, `height` 34→38, `tooltip: false` everywhere, fix duplicate key
- `/home/krubics/.config/waybar/style.css` — add shared icon geometry + 9 `background-image` rules, repoint & resize the pokeball rule
- `/home/krubics/.config/waybar/scripts/pickachu-battery.sh` — rewrite to emit JSON class, add stderr logging, capacity override, safe fallback
- `/home/krubics/.config/waybar/assets/` — receives 9 renamed sprites; `pixelated-pokeball.png` → `pokeball.png`
- `/home/krubics/.config/waybar/images/` — deleted
