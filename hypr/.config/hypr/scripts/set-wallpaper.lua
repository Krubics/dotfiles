#!/usr/bin/env lua
-- Usage: set-wallpaper.lua <path> [transition]
-- Applies the wallpaper via yin/yinctl, which handles both images and
-- videos natively -- no separate video player, no per-type branching.
-- Transition is looked up in conf/wallpapers.lua when not passed explicitly.

local HOME = os.getenv("HOME")
package.path = HOME .. "/.config/hypr/?.lua;" .. package.path
local wallpapers = require("conf.wallpapers")

local wallpaper = arg[1]
local transition = arg[2]
if not wallpaper or wallpaper == "" then
    io.stderr:write("Usage: set-wallpaper.lua <path> [transition]\n")
    os.exit(1)
end

local function sh(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function basename(path)
    return path:match("([^/]+)$") or path
end

if not transition or transition == "" then
    transition = wallpapers.transitions[basename(wallpaper)] or wallpapers.default_transition
end

local monitors = {}
local p = io.popen("hyprctl monitors -j | jq -r '.[].name' 2>/dev/null")
if p then
    for line in p:lines() do
        if line ~= "" then table.insert(monitors, line) end
    end
    p:close()
end

if #monitors == 0 then
    os.execute(("yinctl --img %s --trans %s"):format(sh(wallpaper), sh(transition)))
else
    local parts = {}
    for _, m in ipairs(monitors) do
        table.insert(parts, ("yinctl --img %s --trans %s --output %s &"):format(sh(wallpaper), sh(transition), sh(m)))
    end
    table.insert(parts, "wait")
    os.execute(table.concat(parts, " "))
end

-- Regenerate matugen colours: prefer a pre-baked JSON (videos ship one,
-- since matugen can't sample a video frame), else derive live from images.
local video_exts = { mp4 = true, mkv = true, mov = true, webm = true }
local ext = wallpaper:match("%.(%w+)$")
local is_video = ext and video_exts[ext:lower()]

local stem = basename(wallpaper):match("^([^.]+)") or wallpaper
local colors_json = HOME .. "/.config/hypr/matugen-colors/" .. stem .. ".json"
local f = io.open(colors_json, "r")
if f then
    f:close()
    os.execute("matugen json " .. sh(colors_json))
elseif not is_video then
    os.execute("matugen image " .. sh(wallpaper))
end

os.execute("ln -sf " .. sh(wallpaper) .. " " .. sh(HOME .. "/.cache/current-wallpaper"))
