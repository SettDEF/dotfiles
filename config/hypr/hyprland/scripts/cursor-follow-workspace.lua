#!/usr/bin/env lua
-- Cursor follower — warps the cursor to the centre of the focused
-- monitor whenever the active workspace changes onto a different
-- monitor.
--
-- Why this exists when cursor:warp_on_change_workspace=2 is set:
--   That option mostly works, but in 0.55.2 it intermittently misses
--   the cross-monitor case (Super+N where N lives on the other
--   output). When it misses, follow_mouse=1 yanks focus back to
--   wherever the cursor still is and the workspace switch silently
--   reverts. This daemon listens to socket2's focusedmon> event and
--   reissues a movecursor as a safety net.
--
-- Spawned by exec-once in custom/execs.conf. Idempotent — exits
-- silently if Hyprland isn't running yet.

local LOG_PATH = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state"))
    .. "/cursor-follow-workspace.log"
local log_fh = io.open(LOG_PATH, "a")
local function log_write(msg)
    if not log_fh then return end
    log_fh:write(os.date("%Y-%m-%d %H:%M:%S ") .. msg)
    log_fh:flush()
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function popen_read(cmd)
    local p = io.popen(cmd)
    if not p then return nil end
    local out = p:read("*a")
    p:close()
    return out
end

local function shellquote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function find_socket_dir()
    local rt = os.getenv("XDG_RUNTIME_DIR")
    if not rt or rt == "" then
        rt = "/run/user/" .. trim(popen_read("id -u") or "1000")
    end
    local sig = os.getenv("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig or sig == "" then
        local ls = popen_read("ls -t '" .. rt .. "/hypr' 2>/dev/null") or ""
        for line in ls:gmatch("[^\n]+") do
            if line:match("^[a-f0-9]+_%d+_%d+$") then
                local sock = rt .. "/hypr/" .. line .. "/.socket.sock"
                local f = io.open(sock, "r")
                if f then f:close(); sig = line; break end
            end
        end
    end
    if not sig or sig == "" then return nil end
    return rt .. "/hypr/" .. sig
end

-- Returns {name, x, y, w_logical, h_logical} for the monitor with the
-- given name, or nil. Logical w/h = round(pixel/scale), matching
-- Hyprland's own layout coords (Monitor.cpp line 1081).
local function get_monitor(name)
    local raw = popen_read("hyprctl monitors -j 2>/dev/null")
    if not raw or raw == "" then return nil end
    for blob in raw:gmatch("%b{}") do
        local n = blob:match('"name"%s*:%s*"([^"]+)"')
        if n == name then
            local x = tonumber(blob:match('"x"%s*:%s*(%-?%d+)'))
            local y = tonumber(blob:match('"y"%s*:%s*(%-?%d+)'))
            local w = tonumber(blob:match('"width"%s*:%s*(%d+)'))
            local h = tonumber(blob:match('"height"%s*:%s*(%d+)'))
            local s = tonumber(blob:match('"scale"%s*:%s*([%d%.]+)'))
            if x and y and w and h and s and s > 0 then
                local function iround(v)
                    local i = math.floor(v)
                    return (v - i >= 0.5) and (i + 1) or i
                end
                return {
                    name = n, x = x, y = y,
                    w = iround(w / s), h = iround(h / s),
                }
            end
        end
    end
    return nil
end

-- Returns the monitor Hyprland considers focused RIGHT NOW, in the same
-- {name,x,y,w,h} shape as get_monitor. Deliberately not taken from the
-- focusedmon event: hyprctl calls in this handler cost ~50ms each, so a
-- burst of events queues up in the socat pipe and the name carried by an
-- event is routinely stale by the time it is read. Warping to a stale
-- monitor moves the cursor off the focused output, follow_mouse=1 then
-- drags focus after it, and that emits another focusedmon — the ping-pong
-- that made cross-monitor workspace switches impossible to land.
local function get_focused_monitor()
    local raw = popen_read("hyprctl monitors -j 2>/dev/null")
    if not raw or raw == "" then return nil end
    for blob in raw:gmatch("%b{}") do
        if blob:match('"focused"%s*:%s*true') then
            local n = blob:match('"name"%s*:%s*"([^"]+)"')
            if n then return get_monitor(n) end
        end
    end
    return nil
end

-- Returns cursor's current logical (cx, cy), or nil if hyprctl fails.
local function get_cursor_pos()
    local raw = popen_read("hyprctl cursorpos -j 2>/dev/null")
    if not raw or raw == "" then return nil end
    local x = tonumber(raw:match('"x"%s*:%s*(%-?%d+)'))
    local y = tonumber(raw:match('"y"%s*:%s*(%-?%d+)'))
    return x, y
end

-- Dispatch movecursor to the centre of the monitor.
local function warp_to_monitor(mon)
    local cx = mon.x + math.floor(mon.w / 2)
    local cy = mon.y + math.floor(mon.h / 2)
    os.execute(string.format(
        "hyprctl dispatch \"hl.dsp.cursor.move({ x = %d, y = %d })\" >/dev/null 2>&1", cx, cy))
    log_write(string.format("warped to %s centre (%d, %d)\n", mon.name, cx, cy))
end

local function point_in_monitor(x, y, mon)
    return x >= mon.x and x < mon.x + mon.w
       and y >= mon.y and y < mon.y + mon.h
end

-- Cooldown that prevents self-feedback. The core problem: our warp
-- under follow_mouse=1 causes Hyprland to re-fire focusedmon on the
-- arrival monitor; if Super+N landed us on HDMI we'd warp to HDMI's
-- centre, the cursor arrives, Hyprland fires focusedmon=HDMI again,
-- we re-check, cursor SOMETIMES hasn't actually arrived at the new
-- position yet because hyprctl cursorpos is racy with the dispatch,
-- so the "already on it" check misses and we warp again — to
-- whatever monitor follow_mouse currently thinks we're on, which
-- may already be flickering between the two. Result: ping-pong
-- alternating eDP↔HDMI at ~kHz until something breaks. A
-- per-monitor debounce was useless because successive warps target
-- DIFFERENT monitors.
--
-- Fix: a single global cooldown. After every self-warp we drop
-- focusedmon events for SELF_WARP_GRACE_MS regardless of which
-- monitor they name. The cursor settles, the cascade dies, and the
-- next legitimate user-driven monitor focus resumes warping.
local SELF_WARP_GRACE_MS = 400
local ignore_events_until_ms = 0

-- Guards the slow bounce the 400ms cooldown misses: after a warp, something
-- re-focuses the other monitor ~1s later and we warp back, ping-ponging at 1Hz.
-- Rate limit rather than a direction guard — a direction guard also swallowed
-- the user deliberately clicking the other monitor again. Intent vs oscillation
-- is a question of volume, not direction.
local WARP_BURST_WINDOW_MS = 3000
local WARP_BURST_MAX = 3
local warp_times = {}

-- Drop timestamps outside the window; returns how many warps remain inside it.
local function recent_warp_count(now)
    local kept = {}
    for i = 1, #warp_times do
        if (now - warp_times[i]) < WARP_BURST_WINDOW_MS then
            kept[#kept + 1] = warp_times[i]
        end
    end
    warp_times = kept
    return #kept
end

local function now_ms()
    -- Lua 5.5 has no Date.now(); read uptime in ms from /proc/uptime
    -- (sufficient resolution and monotonic).
    local f = io.open("/proc/uptime", "r")
    if not f then return 0 end
    local s = f:read("*l"); f:close()
    local sec = tonumber(s:match("^([%d%.]+)"))
    return sec and math.floor(sec * 1000) or 0
end

local function handle_focused_monitor(name)
    local t = now_ms()
    if t < ignore_events_until_ms then
        -- post-warp cascade; ignore entirely
        return
    end

    -- Sustained oscillation: too many warps in the last few seconds means we are
    -- feeding a loop rather than following the user. Back off until it settles.
    if recent_warp_count(t) >= WARP_BURST_MAX then
        log_write("focusedmon " .. name .. " — " .. WARP_BURST_MAX .. " warps in " .. WARP_BURST_WINDOW_MS .. "ms, backing off\n")
        return
    end

    -- Trust the event's monitor, not whoever is focused now: under follow_mouse
    -- the revert already landed by the time our first hyprctl call returns, so
    -- asking "who is focused" makes us skip the warp and the revert sticks.
    local mon = get_monitor(name)
    if not mon then
        log_write("could not resolve focused monitor (event said " .. name .. ")\n")
        return
    end
    local cx, cy = get_cursor_pos()
    if cx and point_in_monitor(cx, cy, mon) then
        log_write("focusedmon " .. name .. " — cursor already on it, skip\n")
        return
    end

    warp_to_monitor(mon)
    local warped_at = now_ms()
    warp_times[#warp_times + 1] = warped_at
    ignore_events_until_ms = warped_at + SELF_WARP_GRACE_MS
end

log_write("startup\n")
-- Hyprland runs exec-once entries while it is still coming up: this script is
-- launched ~30ms after the compositor starts, before the IPC socket exists.
-- Exiting on the first miss is what left this daemon dead for an entire
-- session — and with it, every cross-monitor focus silently reverting. Wait
-- for the compositor rather than giving up on it.
local sock_dir = find_socket_dir()
local waited_ms = 0
while not sock_dir and waited_ms < 30000 do
    os.execute("sleep 0.25")
    waited_ms = waited_ms + 250
    sock_dir = find_socket_dir()
end
if not sock_dir then
    log_write("Hyprland IPC never appeared after 30s, exiting\n")
    os.exit(0)
end
if waited_ms > 0 then
    log_write("waited " .. waited_ms .. "ms for Hyprland IPC\n")
end
log_write("socket dir: " .. sock_dir .. "\n")

local evt_sock = sock_dir .. "/.socket2.sock"
local pipe = io.popen("socat -u UNIX-CONNECT:" .. shellquote(evt_sock) .. " STDOUT 2>/dev/null")
if not pipe then
    log_write("could not open socket2, exiting\n")
    os.exit(0)
end

for line in pipe:lines() do
    -- socket2 event format: NAME>>ARGS
    local evt, args = line:match("^([^>]+)>>(.*)$")
    if evt == "focusedmon" then
        -- args = "MONITORNAME,WORKSPACEID"
        local mon_name = args:match("^([^,]+)")
        if mon_name and mon_name ~= "" then
            handle_focused_monitor(mon_name)
        end
    end
end
