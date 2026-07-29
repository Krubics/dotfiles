-- ============================================================
--  keybinds.lua  —  Omarchy's keymap, ported to Hyprland 0.55+ Lua
--
--  Grammar (Omarchy's, kept faithfully):
--    SUPER            = window & workspace management
--    SUPER + SHIFT    = launch apps  (and "relocate" on numbers/arrows)
--    SUPER + CTRL     = system / settings
--    SUPER + ALT      = a variant of the base action
--    CTRL + ALT       = session-level
--
--  Pruned to your setup: only terminal / browser / files / Obsidian
--  apps; Omarchy's own menu scripts swapped for standard Linux tools.
--
--  NOTE on hl.dsp.exec_raw("..."): several Omarchy actions use
--  dispatchers the typed Lua API hasn't wrapped yet (swapwindow,
--  movetoworkspacesilent, togglesplit, pin, centerwindow). exec_raw
--  runs the old-style dispatcher string verbatim — it's the bridge
--  for anything not yet in hl.dsp.*. If your build names it
--  differently, the error will point right at these lines.
--
--  Pull in from hyprland.lua with:  require("keybinds")
-- ============================================================

-- ---- Edit these to match your machine -----------------------
local vars = require("conf.vars")
local modKey = "SUPER"

-- ============================================================
--  APPLICATIONS  (SUPER + SHIFT = launch)
-- ============================================================
hl.bind(modKey .. " + RETURN",         hl.dsp.exec_cmd(vars.terminal))
hl.bind(modKey .. " + SPACE",          hl.dsp.exec_cmd(vars.launcher))
-- hl.bind(modKey .. " + B",      hl.dsp.exec_cmd(vars.browser))
hl.bind(modKey .. " + F",          hl.dsp.exec_cmd(vars.yazi))   -- yazi (terminal FM)
hl.bind(modKey .. " + CTRL + SHIFT + F",  hl.dsp.exec_cmd(vars.files))  -- nautilus (moved off SUPER+SHIFT+F for herdr search)
hl.bind(modKey .. " + O",      hl.dsp.exec_cmd(vars.obsidian))
hl.bind(modKey .. " + A",      function()
  hl.exec_cmd(vars.browser)
  hl.exec_cmd(vars.terminal)
end)

---- Scroll -------------------------------------------------------
-- hl.bind("ALT + semicolon", hl.dsp.scroll({ direction = "down" }))
hl.bind("ALT + P", function() 
  hl.exec_cmd("move +col")
end)

-- ============================================================
--  WINDOW MANAGEMENT  (SUPER)
-- ============================================================
hl.bind(modKey .. " + Q", hl.dsp.window.close())                     -- close window
hl.bind(modKey .. " + D", hl.dsp.window.float({ action = "toggle" })) -- toggle float
hl.bind(modKey .. " + J", hl.dsp.exec_raw("togglesplit"))            -- flip split axis
hl.bind(modKey .. " + bracketright", hl.dsp.window.fullscreen({ mode = 0 }))    -- fullscreen
hl.bind(modKey .. " + GRAVE", hl.dsp.layout("rotatesplit 90"))
-- (0.55 quirk: fullscreen toggle-off can misfire from a bind; works via hyprctl)

-- Pop out: float + size + center + pin  (Omarchy's SUPER+O)
hl.bind(modKey .. " + O", function()
  hl.dispatch(hl.dsp.window.float({ action = "set" }))
  hl.dispatch(hl.dsp.exec_raw("resizeactive exact 50% 50%"))
  hl.dispatch(hl.dsp.exec_raw("centerwindow"))
  hl.dispatch(hl.dsp.exec_raw("pin"))
end)

-- Toggle whole-workspace layout dwindle <-> master  (Omarchy's SUPER+L)
hl.bind(modKey .. " + N", function()
  if hl.get_config("general.layout") == "dwindle" then
    hl.config({ general = { layout = "master" } })
    hl.exec_cmd("notify-send Layout Master -t 3000")
  else
    hl.config({ general = { layout = "dwindle" } })
    hl.exec_cmd("notify-send Layout Dwindle -t 3000")
  end
end)

-- ---- Focus / swap / cycle ----------------------------------
hl.bind(modKey  .. " + L",  hl.dsp.focus({ direction = "l" }))
hl.bind(modKey .. " + apostrophe", hl.dsp.focus({ direction = "r" }))
hl.bind(modKey .. " + P",    hl.dsp.focus({ direction = "u" }))
hl.bind(modKey .. " + semicolon",  hl.dsp.focus({ direction = "d" }))


-- ---- Resize (horizontal, Omarchy default) ------------------
hl.bind(modKey .. " + minus", hl.dsp.window.resize({ x = 100*(16/9), y = 100, relative = true }))
hl.bind(modKey .. " + equal", hl.dsp.window.resize({ x = -100*(16/9), y = -100, relative = true }))

-- ---- Mouse move / resize -----------------------------------
hl.bind(modKey .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(modKey .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ============================================================
--  WORKSPACES  (SUPER = go, +SHIFT = move, +SHIFT+ALT = silent)
-- ============================================================
for i = 1, 9 do
    hl.bind(modKey .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(modKey .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
    hl.bind(modKey .. " + SHIFT + ALT + " .. i, hl.dsp.window.move({ workspace = i, silent = true }))
end

hl.bind(modKey .. " + ALT + 0", hl.dsp.window.move({ workspace = 10 }))
hl.bind(modKey .. " + SHIFT + ALT + 0", hl.dsp.window.move({ workspace = 10, silent = true }))
-- ---- Scratchpads (pyprland) -----------------------------------
-- `pypr toggle <name>` launches the app on first use (lazy) and shows/hides
-- it on every call after — one bind per scratchpad, no separate spawn key.
-- Config: ~/.config/pypr/config.toml. Daemon autostarted in hyprland.lua.
hl.bind(modKey .. " + V", hl.dsp.exec_cmd("pypr toggle code"))
hl.bind(modKey .. " + T", hl.dsp.exec_cmd("pypr toggle term"))
hl.bind(modKey .. " + W", hl.dsp.exec_cmd("pypr toggle browser"))

-- ============================================================
--  SYSTEM / SETTINGS  (SUPER + CTRL)  — mapped to standard tools
-- ============================================================
-- hl.bind(modKey .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"))                     -- lock
hl.bind(modKey .. " + CTRL + A", hl.dsp.exec_cmd("pavucontrol"))                  -- audio
hl.bind(modKey .. " + CTRL + B", hl.dsp.exec_cmd("blueman-manager"))              -- bluetooth
hl.bind(modKey .. " + CTRL + SHIFT + W", hl.dsp.exec_cmd("nm-connection-editor"))         -- wifi (moved off SUPER+CTRL+W for herdr search)
hl.bind(modKey .. " + CTRL + SHIFT + N", hl.dsp.exec_cmd("hyprsunset -t 4000"))           -- nightlight (moved off SUPER+CTRL+N for herdr new_workspace)
hl.bind(modKey .. " + CTRL + I", hl.dsp.exec_cmd("pkill hypridle || hypridle"))   -- toggle idle
hl.bind(modKey .. " + CTRL + E", hl.dsp.exec_cmd("rofi -modi emoji -show emoji")) -- emoji (needs rofi-emoji)
-- Wallpaper transitions are configured in conf/wallpapers.lua, not here.
hl.bind(modKey .. " + SHIFT + Space", hl.dsp.exec_cmd("/home/krubics/.config/hypr/scripts/wallpaper-picker.lua"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("wlogout"))
 
-- ============================================================
--  SPEECH TO TEXT
-- ============================================================
hl.bind(modKey .. " + ALT + D", hl.dsp.exec_cmd("/home/krubics/.local/share/hyprwhspr/src/config/hyprland/hyprwhspr-tray.sh record"))

-- ============================================================
--  CAPTURE
-- ============================================================
hl.bind(modKey .. " + CTRL + S",   hl.dsp.exec_cmd("hyprshot -m region"))

-- ============================================================
--  MEDIA KEYS  (standard: wpctl / brightnessctl / playerctl)
-- ============================================================
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

-- SCRATCHPADS
-- Terminal
local size = {
  l = 0.90,
  w = 0.90,
}

hl.workspace_rule({ workspace = "special:term", on_created_empty = "ghostty --class=com.krubics.ghostty-scratch --gtk-single-instance=false" })
hl.window_rule({
  match = { class = "ghostty-scratch", workspace = "special:term" },
  float = true,
  center = true,
  size = "(monitor_w*" .. size.l .. ") (monitor_h*" .. size.w .. ")",
  persistent_size = true,
})
hl.bind("SUPER+T", hl.dsp.workspace.toggle_special("term"))

-- VSCode
hl.workspace_rule({ workspace = "special:code", on_created_empty = "code --ozone-platform=wayland" })
hl.window_rule({
  match = { class = "^[Cc]ode$", workspace = "special:code" },
  float = true,
  center = true,
  size = "(monitor_w*" .. size.l .. ") (monitor_h*" .. size.w .. ")",
  persistent_size = true,
})
hl.bind("SUPER+C", hl.dsp.workspace.toggle_special("code"))

-- Zen
hl.workspace_rule({ workspace = "special:zen", on_created_empty = "zen --new-window about:blank" })
hl.window_rule({
  match = { class = "^zen$", workspace = "special:zen" },
  float = true,
  center = true,
  size = "(monitor_w*" .. size.l .. ") (monitor_h*" .. size.w .. ")",
  persistent_size = true,
})
hl.bind("SUPER+B", hl.dsp.workspace.toggle_special("zen"))

