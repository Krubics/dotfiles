# Wallpaper on newly-added monitors

## Context

A monitor appearing (hotplug, or a disabled output re-enabled) must end up
showing the current wallpaper. The `yin` daemon binds new `wl_output`s on its
own but never puts a wallpaper on them, so something outside must call
`yinctl --img`. The existing listener,
`~/.config/hypr/scripts/wallpaper-hotplug.lua`, does this in 118 lines with a
`while true` respawn wrapper, a `stat`-based mtime comparison, and commentary
that contradicts itself; it is being replaced with a short one that does the
same job legibly.

Separately, `yin` never destroys a `Monitor` when an output goes away. That is
fixed in the `~/yin` repo source.

## Verified facts (read this session)

- **A bare `yinctl --img` with no `--output` applies to every monitor** on the
  installed `/usr/bin/yin`. Disassembly of `IPC::serverAccept` shows the
  disengaged-optional branch iterating `Daemon::m_monitors` (init at `13150`,
  `call Monitor::setWallpaper` at `131da`, `add $0x8,%r13` at `13214`,
  back-edge at `13218`/`1321d`). The plan depends on this.
- **`/usr/bin/yin` was NOT built from the `~/yin` working tree.** Build IDs
  differ from `~/yin/release/yin`, and no branch in the repo
  (`main`, `origin/main`, `gl-trans`, `cuda`, `play-with-cuda`, `rewrite`,
  `asyncIpc`, `fix/static-image-transition-recursion`, `list`) has that loop —
  every one of them routes `SetWallpaper` through a single
  `daemonFindMonitor()` call, which returns `m_monitors.front()` when no output
  is named. That source is not on disk (`grep -rln "for (auto &monitor :
  daemon.m_monitors)" ~/ --include=IPC_Server.cpp` finds nothing).
  **Therefore: never `sudo install` a build of this repo over `/usr/bin/yin`.**
  Doing so silently downgrades a bare `--img` to one monitor and breaks both
  the new script and `set-wallpaper.lua`.
- **The old script is not broken, it is overbuilt.**
  `~/.local/state/hypr/wallpaper-hotplug.log` ends with
  `applied ... confirmed on eDP-1 on attempt 1`. The `Could not connect to Ipc
  socket, is Yin daemon running?` / `Aborted (core dumped)` spam earlier in the
  log is from a window when `yin` was not running, not a defect in the listener.
- `lua`, `socat`, `jq` are all present at `/usr/bin`.
- `yin` writes `~/.cache/yin/<monitor-name>` containing the wallpaper path
  every time it puts a wallpaper on that monitor, synchronously inside
  `Monitor::setWallpaper` before the IPC reply is sent — so once `yinctl`
  returns, the file is on disk. This is the readiness signal the script uses.

## Step 0 — Discard the uncommitted daemon edits

`~/yin` currently has uncommitted changes to `daemon/Monitor.cpp` and
`daemon/Monitor.hpp` (an in-daemon auto-apply experiment). They are not part of
this plan. Discard them before starting:

```
cd ~/yin && git checkout -- daemon/Monitor.cpp daemon/Monitor.hpp
```

`git status --short` must then be clean.

## Step 1 — Replace the hotplug listener

Independent of Steps 3–4.

Overwrite `~/.config/hypr/scripts/wallpaper-hotplug.lua` with exactly this, and
keep it executable (`chmod +x`):

```lua
#!/usr/bin/env lua
-- Re-applies the current wallpaper whenever a monitor appears.
--
-- yin binds new wl_outputs on its own but never puts a wallpaper on them, so
-- something has to call yinctl. Hyprland announces new outputs on its event
-- socket. A bare `yinctl --img` (no --output) applies to every monitor the
-- daemon currently knows about, so a single call covers the new one -- but
-- only once yin has actually bound it, which happens a moment after Hyprland
-- announces it. yin writes ~/.cache/yin/<monitor> when it puts a wallpaper on
-- that monitor, so removing that file first and retrying until it reappears
-- is a direct signal that the new monitor was really reached.

local HOME = os.getenv("HOME")
package.path = HOME .. "/.config/hypr/?.lua;" .. package.path
local wallpapers = require("conf.wallpapers")

local SIG = os.getenv("HYPRLAND_INSTANCE_SIGNATURE")
local SOCKET = os.getenv("XDG_RUNTIME_DIR") .. "/hypr/" .. (SIG or "") .. "/.socket2.sock"
local STATE_HOME = os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")
local LOG = STATE_HOME .. "/hypr/wallpaper-hotplug.log"
local CURRENT = HOME .. "/.cache/current-wallpaper"

local ATTEMPTS = 12 -- ~3s; yin normally binds the output within one attempt

local function sh(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

os.execute("mkdir -p " .. sh(LOG:match("(.*)/")))

local function log(msg)
    local f = io.open(LOG, "a")
    if f then
        f:write(string.format("%s [wallpaper-hotplug] %s\n", os.date("%Y-%m-%d %H:%M:%S"), msg))
        f:close()
    end
end

-- The wallpaper currently in force, as recorded by scripts/set-wallpaper.lua.
local function current_wallpaper()
    local p = io.popen("readlink -f " .. sh(CURRENT) .. " 2>/dev/null")
    if not p then return nil end
    local path = p:read("*l")
    p:close()
    if path == nil or path == "" then return nil end
    return path
end

local function apply(monitor)
    local wallpaper = current_wallpaper()
    if not wallpaper then
        log("no current wallpaper recorded; skipping " .. monitor)
        return
    end

    local name = wallpaper:match("([^/]+)$") or wallpaper
    local transition = wallpapers.transitions[name] or wallpapers.default_transition
    local cmd = ("yinctl --img %s --trans %s >> %s 2>&1"):format(sh(wallpaper), sh(transition), sh(LOG))
    local receipt = HOME .. "/.cache/yin/" .. monitor

    os.remove(receipt)
    for attempt = 1, ATTEMPTS do
        os.execute(cmd)
        local f = io.open(receipt, "r")
        if f then
            f:close()
            log(("%s: applied %s (%s) on attempt %d"):format(monitor, wallpaper, transition, attempt))
            return
        end
        os.execute("sleep 0.25")
    end
    log(("ERROR: %s did not pick up the wallpaper after %d attempts"):format(monitor, ATTEMPTS))
end

if not SIG then
    log("ERROR: HYPRLAND_INSTANCE_SIGNATURE not set; not inside a Hyprland session")
    os.exit(1)
end

log("listening on " .. SOCKET)
local events = io.popen("socat -u UNIX-CONNECT:" .. sh(SOCKET) .. " -")
if not events then
    log("ERROR: could not open the Hyprland event socket")
    os.exit(1)
end

for line in events:lines() do
    local monitor = line:match("^monitoraddedv2>>%d+,([^,]+)")
    if monitor then
        log("monitor added: " .. monitor)
        apply(monitor)
    end
end

log("event stream closed")
```

Decisions already made here, do not revisit:
- Bare `--img`, not `--output <name>`. On a re-plug, `yin` still holds a stale
  `Monitor` under the same name (Step 3's bug, which is not being installed),
  so `--output HDMI-A-1` would resolve to the dead one and silently do nothing.
  The bare form iterates every `Monitor` and so reaches the live one too.
- Transition comes from `conf/wallpapers.lua` (`transitions[basename]`, else
  `default_transition`, currently `"static"`), same lookup `set-wallpaper.lua`
  uses. Do not hardcode one.
- Deleting the receipt file and polling for its return replaces the old
  `stat -c %Y` mtime comparison. Removing it is harmless — it is a cache yin
  rewrites on every apply.
- The script does not touch matugen or `~/.cache/current-wallpaper`; that is
  `set-wallpaper.lua`'s job and the wallpaper is not changing here.
- Log strings above are the observable contract used by Verification.

## Step 2 — Drop the respawn wrapper (`~/.config/hypr/hyprland.lua`)

Inside `hl.on("hyprland.start", function() ... end)`, the last entry is a
six-line comment ("Then keep listening for newly-appeared monitors ... bring it
back.") followed by `hl.dispatch(hl.dsp.exec_cmd("sh -c 'while true; do
/home/krubics/.config/hypr/scripts/wallpaper-hotplug.lua; sleep 1; done'"))`
— around lines 73-81. Replace that whole comment-plus-dispatch block with:

```lua
    -- Then keep listening for newly-appeared monitors for the rest of the
    -- session -- yin binds new outputs on its own but never puts a wallpaper
    -- on them. The listener lives exactly as long as Hyprland's event socket,
    -- so it needs no respawn wrapper.
    hl.dispatch(hl.dsp.exec_cmd("/home/krubics/.config/hypr/scripts/wallpaper-hotplug.lua"))
```

Leave the `yin`, `hyprsession`, polkit, `waybar`, and `wallpaper-autostart.lua`
dispatches above it untouched.

Two stale `socat` listeners from earlier manual testing are running right now
(`pgrep -af socat` shows two `UNIX-CONNECT:.../.socket2.sock`). Kill them so the
verification below observes one listener:
`pkill -f 'socat -U - UNIX-CONNECT:.*\.socket2\.sock'`.

Also delete the debris the old testing left in `~/.cache/yin/`: `finalcheck`,
`finaltest`, `hotplugtest`, `hotplugtest2`, `hotplugtest3`, `racetest`,
`simpletest`, `testmon`. Keep `HDMI-A-1`, `eDP-1`, `HEADLESS-2` and the
`*.mp4` / `*.png` transcode caches.

## Step 3 — Repo fix: destroy the Monitor when its output goes away

Repo-only. Independent of Steps 1–2; **the result is not installed** (see
Verified facts). All paths under `~/yin`.

`handle_global_remove` in `daemon/Daemon.cpp` is an empty stub and
`Monitor::m_waylandName` (`daemon/Monitor.hpp`, private section) is declared but
never assigned or read, so an unplugged output leaves a dead `Monitor` in
`Daemon::m_monitors` forever. `IPC::daemonFindMonitor` matches by
`m_name` and returns the first hit — the dead one — so after a
disable/re-enable cycle `yinctl --output <name>` targets nothing.

**3a. Record the registry name.**
- `daemon/Monitor.hpp`: change the constructor to
  `Monitor(wl_output *output, Daemon &daemon, u32 waylandName);` and add a
  public accessor `u32 waylandName() const { return m_waylandName; }`.
- `daemon/Monitor.cpp`: constructor becomes
  `Monitor::Monitor(wl_output *output, Daemon &daemon, u32 waylandName)
   : m_daemon(daemon), m_waylandOutput(output), m_waylandName(waylandName) {
   setListener(); }`.
  That initialiser order matches the declaration order in the header
  (`m_daemon`, then `m_waylandOutput`, then `m_waylandName`) — keep it, or GCC
  warns `-Wreorder`.
- `daemon/Daemon.cpp`, in `bindGlobal`'s `wl_output_interface` branch:
  `auto monitor = std::make_unique<Monitor>(wl_output, *this, name);`
  (`name` is already the function's registry-id parameter.)
  This is the only construction site — confirm with
  `grep -rn "make_unique<Monitor>" ~/yin`.

**3b. Erase on removal.**
- `daemon/Daemon.hpp`: declare `void removeGlobal(u32 name);` next to
  `bindGlobal`.
- `daemon/Daemon.cpp`: replace the empty `handle_global_remove` body with
  `static_cast<Daemon *>(data)->removeGlobal(name);` and add:

```cpp
void Daemon::removeGlobal(u32 name) {
  auto it = std::find_if(m_monitors.begin(), m_monitors.end(),
                         [name](const std::unique_ptr<Monitor> &monitor) {
                           return monitor->waylandName() == name;
                         });
  if (it == m_monitors.end())
    return;
  std::cout << "[yin] " << (*it)->m_name << ": disconnected" << std::endl;
  m_monitors.erase(it);
}
```

  `daemon/Daemon.cpp` currently includes neither `<algorithm>` nor
  `<iostream>`; add both.

**3c. Make in-flight frame callbacks survive the destruction.**
Several `wl_callback`s can be outstanding at once (`setWallpaper` calls
`nextFrame` while an earlier callback is still pending; the stale ones are
filtered by `scheduledID != m_wallpaperID` inside `onFrame`). Each holds a raw
`Monitor *` in its `FrameCallbackData`, so erasing the `Monitor` makes the next
`frame_done` a use-after-free. Add a liveness token:

- `daemon/Monitor.hpp`: private member
  `std::shared_ptr<int> m_alive = std::make_shared<int>(0);`
  and extend the struct below the class to
  `struct FrameCallbackData { Monitor *monitor; uint64_t scheduledID;
   std::weak_ptr<int> alive; };`
  (`<memory>` is already included there.)
- `daemon/Monitor.cpp`, in `Monitor::nextFrame`:
  `auto cbData = new FrameCallbackData{this, m_wallpaperID, m_alive};`
- `daemon/Monitor.cpp`, `frame_done`:

```cpp
static void frame_done(void *data, wl_callback *callback, uint32_t) {
  auto cbData = static_cast<FrameCallbackData *>(data);
  wl_callback_destroy(callback);
  if (!cbData->alive.expired())
    cbData->monitor->onFrame(cbData->scheduledID);
  delete cbData;
}
```

**3d. Release the monitor's resources.**
Declare `~Monitor();` in the public section of `daemon/Monitor.hpp` (there is
no destructor today) and define it in `daemon/Monitor.cpp` next to the
constructor:

```cpp
Monitor::~Monitor() {
  // Decoder and VA surfaces first -- they were bound against the EGL surface
  // torn down below.
  m_wallpaper = nullptr;

  for (auto &image : m_eglImages) {
    if (image != EGL_NO_IMAGE) {
      m_daemon.eglDestroyImageKHR(m_daemon.m_eglDisplay, image);
      image = EGL_NO_IMAGE;
    }
  }

  if (m_glSetup &&
      eglMakeCurrent(m_daemon.m_eglDisplay, m_eglSurface, m_eglSurface,
                     m_daemon.m_eglContext) == EGL_TRUE) {
    glDeleteTextures(2, m_textures);
    glDeleteTextures(2, m_toTextures);
    glDeleteProgram(m_glShaderProgram);
    for (auto &[transition, program] : m_transitionShaderPrograms) {
      glDeleteProgram(program);
    }
    eglMakeCurrent(m_daemon.m_eglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE,
                   EGL_NO_CONTEXT);
  }

  if (m_eglSurface != EGL_NO_SURFACE)
    eglDestroySurface(m_daemon.m_eglDisplay, m_eglSurface);
  if (m_eglWindow != nullptr)
    wl_egl_window_destroy(m_eglWindow);
  if (m_viewport != nullptr)
    wp_viewport_destroy(m_viewport);
  if (m_fractionalScale != nullptr)
    wp_fractional_scale_v1_destroy(m_fractionalScale);
  if (m_layerSurface != nullptr)
    zwlr_layer_surface_v1_destroy(m_layerSurface);
  if (m_waylandSurface != nullptr)
    wl_surface_destroy(m_waylandSurface);
  if (m_waylandOutput != nullptr)
    wl_output_release(m_waylandOutput);
}
```

`wl_output_release` needs `wl_output` >= 3; `bindGlobal` binds version 4.
The VAO/VBO/EBO from `setupGl` stay leaked — the VBO/EBO handles are function
locals that are never stored and `glDeleteVertexArrays` is not among the procs
`Daemon::createEGL` loads. Pre-existing and deliberately left alone; do not
widen this step to chase it.

## Step 4 — Unblock the repo build (`~/yin/meson.build`)

Needed only to compile and test Step 3. `ninja` in `~/yin/release` currently
dies before compiling anything with
`ERROR: Include dir /opt/cuda/include does not exist` — the build dir is
configured `enable_cuda=true` and the path is hardcoded Arch layout, while this
machine has the Ubuntu toolkit (`/usr/include/cuda.h`,
`/usr/lib/x86_64-linux-gnu/libcuda.so`).

Replace the `if cuda_enabled` block (tab-indented; match it):

```meson
if cuda_enabled
  yin_args += ['-DENABLE_CUDA']
	# /opt/cuda is the Arch layout. On Debian/Ubuntu the toolkit installs into
	# the default system prefix, where cuda.h needs no explicit include dir --
	# so only add the path when it is actually there.
	fs = import('fs')
	if fs.is_dir('/opt/cuda/include')
		yin_includes += [include_directories('/opt/cuda/include')]
	endif
	cuda = cpp.find_library(
	  'cuda',
	  dirs: ['/opt/cuda/lib64', '/usr/lib', '/usr/lib/x86_64-linux-gnu'],
	  required: true
	)
	yin_deps += [cuda]
endif
```

The `cuda_inc` local disappears; `grep -n cuda_inc ~/yin/meson.build` must
return nothing afterwards.

If the CUDA sources still will not compile against the Ubuntu headers, run
`meson configure ~/yin/release -Denable_cuda=false` and move on — nothing in
this plan exercises `CudaCopy`, which is only reachable via `--use-cuda-copy`
(`~/yin/daemon/main.cpp`).

## Critical files & anchors

- `~/yin/daemon/Daemon.cpp` — `handle_global_remove` (empty stub, ~line 31) and
  the `wl_output_interface` branch of `bindGlobal` (~line 77). Both edits in 3a/3b.
- `~/yin/daemon/Monitor.cpp` — `frame_done` (~line 76), `Monitor::Monitor`
  (~line 114), `Monitor::nextFrame` (~line 646). Steps 3a/3c/3d.
- `~/yin/daemon/IPC_Server.cpp` — `IPC::daemonFindMonitor`; explains why a
  stale same-named `Monitor` shadows the live one.
- `~/.config/hypr/conf/wallpapers.lua` — `transitions` table and
  `default_transition = "static"`; the lookup the new script reuses.

## Verification

All checks run from a normal desktop terminal inside the Hyprland session
(needs `WAYLAND_DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE`).

**Script (Steps 1–2).** Do not log out; start the new listener by hand.

1. `pkill -f 'socat -U - UNIX-CONNECT:.*\.socket2\.sock'`, then
   `pgrep -af socat` returns nothing.
2. `~/.config/hypr/scripts/wallpaper-hotplug.lua &` — then
   `tail -f ~/.local/state/hypr/wallpaper-hotplug.log` shows a
   `listening on /run/user/1000/hypr/<sig>/.socket2.sock` line.
3. **New behaviour:** `hyprctl output create headless`. Within ~3s the log must
   gain `monitor added: HEADLESS-<n>` followed by
   `HEADLESS-<n>: applied /home/krubics/.config/hypr/wallpapers/latios-latias.png (static) on attempt <k>`,
   `~/.cache/yin/HEADLESS-<n>` must exist and contain that path, and the
   wallpaper must be visible on the new output.
   Tear down with `hyprctl output remove HEADLESS-<n>`.
4. **Real output:**
   `hyprctl keyword monitor "HDMI-A-1,disable"; sleep 2; hyprctl keyword monitor "HDMI-A-1,preferred,auto,1"`.
   HDMI-A-1 must come back with the wallpaper on it and a matching
   `HDMI-A-1: applied ...` line. No `ERROR:` lines, no `Aborted (core dumped)`.
5. **No regression:**
   `~/.config/hypr/scripts/set-wallpaper.lua ~/.config/hypr/wallpapers/gojo.mp4`
   still switches every monitor; switch back to `latios-latias.png` afterwards.
6. Kill the hand-started listener (`kill %1`) — the next login starts it from
   `hyprland.lua`.

**Repo fix (Steps 3–4).** Tested against a locally-run binary; nothing is
installed.

7. `cd ~/yin/release && ninja` exits 0.
8. `pkill -x yin; sleep 1; ~/yin/release/yin` in a spare terminal. Set a
   wallpaper so there is something to see:
   `yinctl --img ~/.config/hypr/wallpapers/latios-latias.png --output eDP-1`
   (this build resolves a bare `--img` to one monitor only, so name the output).
9. `hyprctl output create headless` then `hyprctl output remove HEADLESS-<n>`,
   five times in a row. Each removal must print exactly one
   `[yin] HEADLESS-<n>: disconnected` on the daemon's stdout, the daemon must
   not crash, and after the cycles `yinctl --img <path> --output eDP-1` must
   still succeed — proving no stale `Monitor` is shadowing a live one and that
   no in-flight frame callback faulted (3c).
10. Ctrl-C that daemon and restore the installed one:
    `hyprctl dispatch exec yin`, then confirm
    `md5sum /usr/bin/yin` is unchanged from `3f22095459613d2c1c7194059b26a1b6`.

## Assumptions & contingencies

- **`/usr/bin/yin` is left exactly as-is.** The repo cannot reproduce it and a
  rebuild from this tree regresses bare-`--img`-hits-all-monitors, which Step 1
  relies on. If you want the Step 3 fix live, the prerequisite is finding or
  reconstructing the source `/usr/bin/yin` was built from — a separate job.
- **`~/.cache/current-wallpaper` is the source of truth for "current
  wallpaper".** It is a symlink `set-wallpaper.lua` maintains and currently
  points at `~/.config/hypr/wallpapers/latios-latias.png`. If it is missing the
  script logs `no current wallpaper recorded` and does nothing, rather than
  guessing. `wallpaper-autostart.lua` hardcodes its own boot image and is not
  changed here.
- **`ATTEMPTS = 12` at 0.25s ≈ 3s.** The existing log shows attempt 1 or 2
  succeeding. If verification step 3 or 4 ever logs the `did not pick up the
  wallpaper` error, raise `ATTEMPTS`, do not add a fixed pre-delay.
- **`monitoraddedv2>>ID,NAME,DESC` is the event format**, matched with
  `^monitoraddedv2>>%d+,([^,]+)`. Confirmed by the existing log extracting
  `eDP-1` and `finalcheck` correctly with the same prefix.
</content>
<parameter name="i">Rewriting plan with corrected facts