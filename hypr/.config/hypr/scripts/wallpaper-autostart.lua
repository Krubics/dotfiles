#!/usr/bin/env lua
-- Applies the boot wallpaper once yin's IPC socket is ready.
--
-- yin is started by Hyprland's autostart (see hyprland.lua) immediately
-- before this script. It binds a Unix socket at /tmp/yin once it comes up,
-- so instead of guessing with a fixed delay, this waits for that socket to
-- exist before calling yinctl, so yinctl never races the daemon.

local HOME = os.getenv("HOME")
local IMG = HOME .. "/.config/hypr/wallpapers/latios-latias.png"
local STATE_HOME = os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")
local LOG = STATE_HOME .. "/hypr/wallpaper-autostart.log"
local SOCKET = "/tmp/yin"

local SOCKET_TIMEOUT_MS = 5000 -- give up waiting for the socket after ~5s
local RETRIES = 20             -- then retry the apply loop this many times (0.1s apart)
local POLL_MS = 100

local function sh(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function exec_ok(cmd)
    local ok = os.execute(cmd)
    if type(ok) == "number" then
        return ok == 0
    end
    return ok == true
end

os.execute("mkdir -p " .. sh(LOG:match("(.*)/") or "."))

local function log(msg)
    local f = io.open(LOG, "a")
    if f then
        f:write(string.format("%s [wallpaper-autostart] %s\n", os.date("%Y-%m-%d %H:%M:%S"), msg))
        f:close()
    end
end

log(string.format("starting; waiting for yin socket at %s (timeout %dms)", SOCKET, SOCKET_TIMEOUT_MS))

-- 1. Wait for yin to create its IPC socket.
local waited = 0
while not exec_ok("[ -S " .. sh(SOCKET) .. " ]") do
    if waited >= SOCKET_TIMEOUT_MS then
        log(string.format("ERROR: yin socket did not appear within %dms; aborting", SOCKET_TIMEOUT_MS))
        os.exit(1)
    end
    os.execute("sleep 0.1")
    waited = waited + POLL_MS
end
log(string.format("yin socket ready after %dms", waited))

-- 2. Discover the monitors this Hyprland instance actually has.
local monitors = {}
local p = io.popen("hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null")
if p then
    for line in p:lines() do
        if line ~= "" then table.insert(monitors, line) end
    end
    p:close()
end
if #monitors == 0 then
    log("WARN: hyprctl reported no monitors; falling back to yin's default output")
end

-- 3. Apply the wallpaper to each monitor, retrying until every one succeeds.
local attempt = 1
while true do
    local all_ok = true
    if #monitors == 0 then
        if not exec_ok("yinctl --img " .. sh(IMG) .. " >> " .. sh(LOG) .. " 2>&1") then
            all_ok = false
        end
    else
        for _, m in ipairs(monitors) do
            if not exec_ok("yinctl --img " .. sh(IMG) .. " --output " .. sh(m) .. " >> " .. sh(LOG) .. " 2>&1") then
                all_ok = false
                log(string.format("yinctl for '%s' failed on attempt %d", m, attempt))
            end
        end
    end

    if all_ok then
        log(string.format("wallpaper applied on attempt %d (img=%s)", attempt, IMG))
        os.exit(0)
    end
    if attempt >= RETRIES then
        log(string.format("ERROR: wallpaper apply failed after %d attempts", attempt))
        os.exit(1)
    end
    attempt = attempt + 1
    os.execute("sleep 0.1")
end
