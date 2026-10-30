#!/usr/bin/env lua
-- Watches Hyprland for monitor layout changes and fires a desktop
-- notification when two monitors' logical bounds claim the same
-- pixel cell.
--
-- Why: Hyprland tolerates overlapping monitor positions silently,
-- but the resulting cursor behaviour (follow_mouse:1 yanks focus
-- back, workspace dispatchers misroute) is hard to diagnose.
-- The compute uses ceil(width/scale) for logical width, matching
-- Hyprland's own internal layout check — so this detects the exact
-- 1px overlap a fractional scale (e.g. 2560 @ 1.67 → 1532.93)
-- introduces when the neighbouring monitor's x lands on the ceil'd
-- column.
--
-- Spawned by exec-once in custom/execs.conf. Idempotent — exits
-- silently if Hyprland isn't running yet.

local LOG_PATH = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state"))
    .. "/monitor-overlap-watch.log"
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

local function iceil(n)
    local i = math.floor(n)
    return (n > i) and (i + 1) or i
end

local function get_monitors()
    local raw = popen_read("hyprctl monitors -j 2>/dev/null")
    if not raw or raw == "" then return {} end
    local mons = {}
    for blob in raw:gmatch("%b{}") do
        local name = blob:match('"name"%s*:%s*"([^"]+)"')
        local x = tonumber(blob:match('"x"%s*:%s*(%-?%d+)'))
        local y = tonumber(blob:match('"y"%s*:%s*(%-?%d+)'))
        local w = tonumber(blob:match('"width"%s*:%s*(%d+)'))
        local h = tonumber(blob:match('"height"%s*:%s*(%d+)'))
        local s = tonumber(blob:match('"scale"%s*:%s*([%d%.]+)'))
        local disabled = blob:match('"disabled"%s*:%s*true')
        if name and x and y and w and h and s and s > 0 and not disabled then
            mons[#mons + 1] = {
                name = name, x = x, y = y,
                lw = iceil(w / s), lh = iceil(h / s)
            }
        end
    end
    return mons
end

local function shellquote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function notify(title, body)
    os.execute(string.format(
        "notify-send -a 'monitor-watch' -u critical -i display %s %s",
        shellquote(title), shellquote(body)))
end

local last_overlap_key = ""

local function check()
    local mons = get_monitors()
    local overlaps = {}
    for i = 1, #mons do
        for j = i + 1, #mons do
            local a, b = mons[i], mons[j]
            local x_overlap = (a.x < b.x + b.lw) and (b.x < a.x + a.lw)
            local y_overlap = (a.y < b.y + b.lh) and (b.y < a.y + a.lh)
            if x_overlap and y_overlap then
                overlaps[#overlaps + 1] = string.format(
                    "%s [%d..%d × %d..%d] ⇄ %s [%d..%d × %d..%d]",
                    a.name, a.x, a.x + a.lw - 1, a.y, a.y + a.lh - 1,
                    b.name, b.x, b.x + b.lw - 1, b.y, b.y + b.lh - 1)
            end
        end
    end

    local key = table.concat(overlaps, "|")
    local changed = key ~= last_overlap_key
    last_overlap_key = key

    if #overlaps > 0 then
        log_write("OVERLAP: " .. key .. "\n")
        if changed then
            local body = table.concat(overlaps, "\n") ..
                "\n\nEdit ~/.config/hypr/monitors.conf to nudge x/y or pick a scale " ..
                "whose logical width is integer (e.g. 1.6 → 1600)."
            notify("Monitor layout overlap", body)
        end
    else
        log_write("layout clean\n")
    end
end

log_write("startup\n")
-- Launched from exec-once ~30ms after the compositor starts, i.e. before the
-- IPC socket exists. Giving up on the first miss leaves this dead for the whole
-- session, so wait for Hyprland instead. See cursor-follow-workspace.lua.
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

check()

local evt_sock = sock_dir .. "/.socket2.sock"
local pipe = io.popen("socat -u UNIX-CONNECT:" .. shellquote(evt_sock) .. " STDOUT 2>/dev/null")
if not pipe then os.exit(0) end

for line in pipe:lines() do
    local evt = line:match("^([^>]+)>>")
    if evt == "monitoradded" or evt == "monitoraddedv2"
        or evt == "monitorremoved" or evt == "monitorremovedv2"
        or evt == "configreloaded" then
        check()
    end
end
