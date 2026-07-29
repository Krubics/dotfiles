#!/usr/bin/env lua
-- Persistent listener: reapplies the current wallpaper to any monitor that
-- appears after Hyprland starts (hotplug reconnect, or a monitor coming
-- back on). yin discovers new monitors fine on its own but never
-- automatically re-applies a wallpaper to them -- something has to call
-- yinctl explicitly, every time, for every monitor. This listens on
-- Hyprland's own IPC event socket for "monitoraddedv2" and does that.

local HOME = os.getenv("HOME")
package.path = HOME .. "/.config/hypr/?.lua;" .. package.path
local wallpapers = require("conf.wallpapers")

local XDG_RUNTIME_DIR = os.getenv("XDG_RUNTIME_DIR")
local SIG = os.getenv("HYPRLAND_INSTANCE_SIGNATURE")
local SOCKET = XDG_RUNTIME_DIR .. "/hypr/" .. SIG .. "/.socket2.sock"

local STATE_HOME = os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")
local LOG = STATE_HOME .. "/hypr/wallpaper-hotplug.log"

local function sh(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function basename(path)
    return path:match("([^/]+)$") or path
end

os.execute("mkdir -p " .. sh(LOG:match("(.*)/") or "."))

local function log(msg)
    local f = io.open(LOG, "a")
    if f then
        f:write(string.format("%s [wallpaper-hotplug] %s\n", os.date("%Y-%m-%d %H:%M:%S"), msg))
        f:close()
    end
end

local function mtime(path)
    local p = io.popen("stat -c %Y " .. sh(path) .. " 2>/dev/null")
    local t = p and p:read("*l") or nil
    if p then p:close() end
    return t
end

local function apply_current(monitor)
    local p = io.popen("readlink -f " .. sh(HOME .. "/.cache/current-wallpaper") .. " 2>/dev/null")
    local wallpaper = p and p:read("*l") or nil
    if p then p:close() end

    if not wallpaper or wallpaper == "" then
        log("no current-wallpaper set yet, skipping " .. monitor)
        return
    end

    -- No --output: a bare --img applies to every monitor yin currently
    -- knows about, including one that just appeared moments ago -- at the
    -- cost of replaying the transition on every other monitor too, not
    -- just the new one. Targeting the new monitor by name used to crash
    -- ("Could not find required monitor") if yin's own Wayland connection
    -- hadn't registered it yet; dropping --output avoids that crash, but
    -- doesn't avoid the underlying race -- yin just silently drops any
    -- monitor it doesn't know about yet instead of erroring, so it still
    -- needs confirming via yin's own per-monitor cache file (its mtime
    -- moves only if that specific monitor was actually reached) and
    -- retrying if the new monitor didn't get it.
    local transition = wallpapers.transitions[basename(wallpaper)] or wallpapers.default_transition
    local cmd = ("yinctl --img %s --trans %s >> %s 2>&1"):format(sh(wallpaper), sh(transition), sh(LOG))
    local cache_file = HOME .. "/.cache/yin/" .. monitor

    local RETRIES, POLL_MS = 15, 200
    for attempt = 1, RETRIES do
        local before = mtime(cache_file)
        os.execute(cmd)
        os.execute("sleep 0.1")
        local after = mtime(cache_file)
        if after and after ~= before then
            log(("applied %s (%s), confirmed on %s on attempt %d"):format(wallpaper, transition, monitor, attempt))
            return
        end
        os.execute("sleep 0.1")
    end
    log(("ERROR: %s never showed the wallpaper after %d attempts"):format(monitor, RETRIES))
end

local function main()
    if not SIG then
        log("ERROR: HYPRLAND_INSTANCE_SIGNATURE not set; aborting")
        os.exit(1)
    end

    log("starting; listening on " .. SOCKET)

    local events = io.popen("socat -u UNIX-CONNECT:" .. sh(SOCKET) .. " -")
    if not events then
        log("ERROR: failed to open event socket")
        return
    end

    for line in events:lines() do
        local name = line:match("^monitoraddedv2>>%d+,([^,]+),")
        if name then
            log("monitor added: " .. name)
            apply_current(name)
        end
    end

    log("event stream closed")
end

-- The hyprland.lua dispatch respawns this script on exit, but that only
-- helps if a crash actually gets logged instead of vanishing -- catch
-- anything unexpected here so the next run has a real reason to go on,
-- not just silence.
local ok, err = pcall(main)
if not ok then
    log("CRASHED: " .. tostring(err))
end
