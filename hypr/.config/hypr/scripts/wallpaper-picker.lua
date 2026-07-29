#!/usr/bin/env lua
-- Wallpaper picker: lists files under ~/.config/hypr/wallpapers via rofi,
-- then applies the pick through set-wallpaper.lua. Per-wallpaper transitions
-- are configured in conf/wallpapers.lua, not here.

local HOME = os.getenv("HOME")
local WALLPAPER_DIR = HOME .. "/.config/hypr/wallpapers"
local ROFI_THEME = HOME .. "/.config/rofi/launchers/type-1/style-6.rasi"
local SET_WALLPAPER = HOME .. "/.config/hypr/scripts/set-wallpaper.lua"

local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local pick_cmd = string.format(
    "find %s -type f | rofi -dmenu -i -p 'Wallpaper' -theme %s",
    shell_quote(WALLPAPER_DIR), shell_quote(ROFI_THEME)
)

local p = io.popen(pick_cmd)
local pick = p and p:read("*l") or nil
if p then
    p:close()
end

if not pick or pick == "" then
    os.exit(0)
end

os.execute(SET_WALLPAPER .. " " .. shell_quote(pick))
