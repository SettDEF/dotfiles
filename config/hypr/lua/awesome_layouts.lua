-- AwesomeWM-style layouts (awful.layout.suit) as a Hyprland Lua layout.
--
-- One layout, "lua:awesomewm", with a per-workspace state like an Awesome tag:
--   suit     tile | tileleft | tilebottom | tiletop | fair | fairh |
--            spiral | dwindle | max | cornernw | cornerne | cornersw | cornerse
--   mwfact   master width factor (0.05 .. 0.95)
--   nmaster  number of master windows
--   ncol     number of columns in the stack area
--
-- Driven by layout messages (hl.dsp.layout("<msg>")):
--   suit <name> | next | prev | mwfact <+-x|x> | nmaster <+-n> | ncol <+-n>
--   swapmaster | reset | state (rewrite the state file)
-- The shell's LayoutService sends these and reads ~/.cache/hypr-awesome.json.

local M = {}

M.suits = { "tile", "tileleft", "tilebottom", "tiletop", "fair", "fairh",
            "spiral", "dwindle", "max", "cornernw", "cornerne", "cornersw", "cornerse" }
local valid = {}
for _, s in ipairs(M.suits) do valid[s] = true end

local DEFAULT = { suit = "tile", mwfact = 0.5, nmaster = 1, ncol = 1 }

-- workspace name -> state (0.56: named workspaces have no id); window address -> order key (masters first).
M.state = {}
M.order = {}
local seq = 0

local STATE_FILE = os.getenv("HOME") .. "/.cache/hypr-awesome.json"

local function json_state()
    local parts = {}
    for ws, s in pairs(M.state) do
        parts[#parts + 1] = string.format(
            '"%s":{"suit":"%s","mwfact":%.2f,"nmaster":%d,"ncol":%d}',
            tostring(ws), s.suit, s.mwfact, s.nmaster, s.ncol)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function save()
    local f = io.open(STATE_FILE, "w")
    if f then f:write(json_state()); f:close() end
end

local function load()
    local f = io.open(STATE_FILE, "r")
    if not f then return end
    local text = f:read("a"); f:close()
    for ws, suit, mw, nm, nc in text:gmatch(
        '"([^"]+)":{"suit":"(%w+)","mwfact":([%d%.]+),"nmaster":(%d+),"ncol":(%d+)}') do
        if valid[suit] then
            M.state[ws] = { suit = suit, mwfact = tonumber(mw), nmaster = tonumber(nm), ncol = tonumber(nc) }
        end
    end
end

local function ws_key(ctx)
    for _, t in ipairs(ctx.targets) do
        local w = t.window
        if w and w.workspace then return w.workspace.name end
    end
    local aw = hl.get_active_workspace()
    return aw and aw.name or "?"
end

local function state_for(key)
    local s = M.state[key]
    if not s then
        s = { suit = DEFAULT.suit, mwfact = DEFAULT.mwfact, nmaster = DEFAULT.nmaster, ncol = DEFAULT.ncol }
        M.state[key] = s
    end
    return s
end

-- Targets in our order: new windows go to the end (Awesome's default is to
-- the master slot; "swapmaster" promotes), the order survives recalcs.
local function ordered(ctx)
    local list = {}
    for _, t in ipairs(ctx.targets) do
        local a = t.window and t.window.address or ("idx" .. t.index)
        if not M.order[a] then seq = seq + 1; M.order[a] = seq end
        list[#list + 1] = { t = t, key = M.order[a], addr = a }
    end
    table.sort(list, function(x, y) return x.key < y.key end)
    return list
end

local function box(x, y, w, h) return { x = x, y = y, w = w, h = h } end

-- Split `area` into `n` equal slices along one axis.
local function slices(area, n, vertical)
    local out = {}
    for i = 0, n - 1 do
        if vertical then
            local y0 = math.floor(area.y + area.h * i / n)
            local y1 = math.floor(area.y + area.h * (i + 1) / n)
            out[#out + 1] = box(area.x, y0, area.w, y1 - y0)
        else
            local x0 = math.floor(area.x + area.w * i / n)
            local x1 = math.floor(area.x + area.w * (i + 1) / n)
            out[#out + 1] = box(x0, area.y, x1 - x0, area.h)
        end
    end
    return out
end

-- awful.layout.suit.tile and its orientations. "orient" is where the master
-- area sits: left (tile), right (tileleft), top (tilebottom), bottom (tiletop).
local function tile(list, area, s, orient)
    local n = #list
    local horizontal = orient == "left" or orient == "right"
    local nmaster = math.min(s.nmaster, n)
    local nother = n - nmaster
    local boxes = {}

    local master, other = area, nil
    if nmaster > 0 and nother > 0 then
        local size = math.floor((horizontal and area.w or area.h) * s.mwfact)
        if orient == "left" then
            master = box(area.x, area.y, size, area.h)
            other = box(area.x + size, area.y, area.w - size, area.h)
        elseif orient == "right" then
            master = box(area.x + area.w - size, area.y, size, area.h)
            other = box(area.x, area.y, area.w - size, area.h)
        elseif orient == "top" then
            master = box(area.x, area.y, area.w, size)
            other = box(area.x, area.y + size, area.w, area.h - size)
        else
            master = box(area.x, area.y + area.h - size, area.w, size)
            other = box(area.x, area.y, area.w, area.h - size)
        end
    elseif nmaster == 0 then
        master, other = nil, area
    end

    if master and nmaster > 0 then
        for _, b in ipairs(slices(master, nmaster, horizontal)) do boxes[#boxes + 1] = b end
    end
    if other and nother > 0 then
        -- ncol columns (rows for top/bottom); like Awesome, the later columns
        -- take the remainder so the one next to the master stays tidy.
        local ncol = math.max(1, math.min(s.ncol, nother))
        local cols = slices(other, ncol, not horizontal)
        if orient == "right" or orient == "bottom" then
            -- Columns fill from the master side outwards.
            local rev = {}
            for i = #cols, 1, -1 do rev[#rev + 1] = cols[i] end
            cols = rev
        end
        local base, extra = nother // ncol, nother % ncol
        for c = 1, ncol do
            local count = base + ((c > ncol - extra) and 1 or 0)
            for _, b in ipairs(slices(cols[c], count, horizontal)) do boxes[#boxes + 1] = b end
        end
    end
    return boxes
end

-- awful.layout.suit.fair: a grid, last row/column stretched.
local function fair(list, area, horizontal)
    local n = #list
    if n == 2 then
        return slices(area, 2, horizontal)
    end
    local rows = math.ceil(math.sqrt(n))
    local cols = math.ceil(n / rows)
    local boxes = {}
    -- "lines" are columns for fair, rows for fair.horizontal.
    local lines = slices(area, cols, horizontal)
    local placed = 0
    for l = 1, cols do
        local remaining_lines = cols - l + 1
        local count = math.ceil((n - placed) / remaining_lines)
        for _, b in ipairs(slices(lines[l], count, not horizontal)) do boxes[#boxes + 1] = b end
        placed = placed + count
    end
    return boxes
end

-- awful.layout.suit.spiral / spiral.dwindle.
local function spiral(list, area, s, is_spiral)
    local n = #list
    local boxes = {}
    local rest = box(area.x, area.y, area.w, area.h)
    for i = 1, n do
        if i == n then
            boxes[#boxes + 1] = rest
            break
        end
        local k = (i - 1) % 4
        local vertical_split = (k % 2 == 0)   -- side by side first
        local ratio = (i == 1) and s.mwfact or 0.5
        local cur, nxt
        if vertical_split then
            local w = math.floor(rest.w * ratio)
            if is_spiral and k == 2 then
                cur = box(rest.x + rest.w - w, rest.y, w, rest.h)
                nxt = box(rest.x, rest.y, rest.w - w, rest.h)
            else
                cur = box(rest.x, rest.y, w, rest.h)
                nxt = box(rest.x + w, rest.y, rest.w - w, rest.h)
            end
        else
            local h = math.floor(rest.h * ratio)
            if is_spiral and k == 3 then
                cur = box(rest.x, rest.y + rest.h - h, rest.w, h)
                nxt = box(rest.x, rest.y, rest.w, rest.h - h)
            else
                cur = box(rest.x, rest.y, rest.w, h)
                nxt = box(rest.x, rest.y + h, rest.w, rest.h - h)
            end
        end
        boxes[#boxes + 1] = cur
        rest = nxt
    end
    return boxes
end

-- awful.layout.suit.corner.*: master in a corner, the others split between
-- the column beside it and the row below/above it.
local function corner(list, area, s, which)
    local n = #list
    if n == 1 then return { area } end
    local mw = math.floor(area.w * s.mwfact)
    local mh = math.floor(area.h * s.mwfact)
    local left = which == "cornernw" or which == "cornersw"
    local top = which == "cornernw" or which == "cornerne"
    local mx = left and area.x or area.x + area.w - mw
    local my = top and area.y or area.y + area.h - mh
    local boxes = { box(mx, my, mw, mh) }
    local others = n - 1
    if others == 1 then
        -- One more window: a plain side-by-side split, master keeps full height.
        boxes[1] = box(mx, area.y, mw, area.h)
        boxes[2] = box(left and area.x + mw or area.x, area.y, area.w - mw, area.h)
        return boxes
    end
    local ncolside = math.ceil(others / 2)
    local nrow = others - ncolside
    local side = box(left and area.x + mw or area.x, area.y, area.w - mw, area.h)
    local row = box(mx, top and area.y + mh or area.y, mw, area.h - mh)
    for _, b in ipairs(slices(side, ncolside, true)) do boxes[#boxes + 1] = b end
    for _, b in ipairs(slices(row, nrow, false)) do boxes[#boxes + 1] = b end
    return boxes
end

local function recalculate(ctx)
    local list = ordered(ctx)
    local n = #list
    if n == 0 then return end
    local s = state_for(ws_key(ctx))
    local a = ctx.area
    local area = box(a.x, a.y, a.w, a.h)
    local boxes
    if n == 1 or s.suit == "max" then
        boxes = {}
        for i = 1, n do boxes[i] = area end
    elseif s.suit == "tile" then boxes = tile(list, area, s, "left")
    elseif s.suit == "tileleft" then boxes = tile(list, area, s, "right")
    elseif s.suit == "tilebottom" then boxes = tile(list, area, s, "top")
    elseif s.suit == "tiletop" then boxes = tile(list, area, s, "bottom")
    elseif s.suit == "fair" then boxes = fair(list, area, false)
    elseif s.suit == "fairh" then boxes = fair(list, area, true)
    elseif s.suit == "spiral" then boxes = spiral(list, area, s, true)
    elseif s.suit == "dwindle" then boxes = spiral(list, area, s, false)
    else boxes = corner(list, area, s, s.suit) end
    for i, e in ipairs(list) do
        e.t:place(boxes[i] or area)
    end
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function adjust(cur, arg, lo, hi)
    local sign, num = arg:match("^([%+%-]?)([%d%.]+)$")
    if not num then return cur end
    num = tonumber(num)
    if sign == "+" then return clamp(cur + num, lo, hi)
    elseif sign == "-" then return clamp(cur - num, lo, hi) end
    return clamp(num, lo, hi)
end

local function layout_msg(ctx, msg)
    local cmd, arg = msg:match("^%s*(%S+)%s*(.-)%s*$")
    local key = ws_key(ctx)
    local s = state_for(key)
    if cmd == "suit" and valid[arg] then
        s.suit = arg
    elseif cmd == "next" or cmd == "prev" then
        local i = 1
        for j, name in ipairs(M.suits) do if name == s.suit then i = j end end
        i = ((i - 1 + (cmd == "next" and 1 or -1)) % #M.suits) + 1
        s.suit = M.suits[i]
    elseif cmd == "mwfact" or cmd == "splitratio" then
        -- splitratio: the master layout's name for it, so existing binds keep working.
        s.mwfact = adjust(s.mwfact, arg, 0.05, 0.95)
    elseif cmd == "nmaster" then
        s.nmaster = math.floor(adjust(s.nmaster, arg, 0, 10))
    elseif cmd == "ncol" then
        s.ncol = math.floor(adjust(s.ncol, arg, 1, 10))
    elseif cmd == "swapmaster" then
        -- Awesome's Mod+Ctrl+Return: the focused window becomes the master.
        local list = ordered(ctx)
        local active = hl.get_active_window()
        if active and #list > 1 then
            for _, e in ipairs(list) do
                if e.addr == active.address and e ~= list[1] then
                    local first = list[1]
                    M.order[e.addr], M.order[first.addr] = M.order[first.addr], M.order[e.addr]
                    break
                end
            end
        end
    elseif cmd == "reset" then
        M.state[key] = nil
        s = state_for(key)
    elseif cmd == "state" then
        -- Just (re)writes the state file; a string return would be shown as an error.
    else
        return "unknown layout message: " .. msg
    end
    save()
    recalculate(ctx)
    return true
end

load()
-- Registered once per Hyprland session (a second register is an error); the
-- wrappers call whatever this file defined last, so re-running it hot-swaps
-- the code while windows keep their state.
local prev = package.loaded["lua.awesome_layouts"]
if type(prev) == "table" and prev.state then
    M.state, M.order = prev.state, prev.order
end
M.recalculate, M.layout_msg = recalculate, layout_msg
local NAME = _G.__awesome_layout_name or "awesomewm"
_G.__awesome_registered = _G.__awesome_registered or {}
if not _G.__awesome_registered[NAME] then
    _G.__awesome_registered[NAME] = true
    pcall(hl.layout.register, NAME, {
        recalculate = function(ctx) return package.loaded["lua.awesome_layouts"].recalculate(ctx) end,
        layout_msg = function(ctx, msg) return package.loaded["lua.awesome_layouts"].layout_msg(ctx, msg) end,
    })
end

-- Forget closed windows so the order table doesn't grow forever.
if not _G.__awesome_close_hook then
    _G.__awesome_close_hook = true
    pcall(hl.on, "window.close", function(w)
    local m = package.loaded["lua.awesome_layouts"]
    if m and w and w.address then m.order[w.address] = nil end
end)
end

-- ── Hybrid: native layouts where Hyprland has one ────────────────────────
-- A Lua layout has no resize hook: Hyprland calls recalculate() with the old
-- boxes after a mouse resize, so the drag is undone. The suits that ARE native
-- layouts (tile = master, dwindle, max = monocle) therefore run natively, per
-- workspace through a workspace rule, and keep mouse resizing. spiral runs on dwindle too (the
-- same alternating splits; 2026-10-20, so it resizes with the mouse); fair and corner stay on
-- "lua:awesomewm", resized with the keys or Super+right-drag (the shell turns the drag into mwfact).
M.native = {
    spiral     = { layout = "dwindle" },
    tile       = { layout = "master", layout_opts = { orientation = "left" } },
    tileleft   = { layout = "master", layout_opts = { orientation = "right" } },
    tilebottom = { layout = "master", layout_opts = { orientation = "top" } },
    tiletop    = { layout = "master", layout_opts = { orientation = "bottom" } },
    dwindle    = { layout = "dwindle" },
    max        = { layout = "monocle" },
}

local function ws_selector(name)
    return tostring(name):match("^%-?%d+$") and tostring(name) or ("name:" .. name)
end

--- Give workspace `name` the suit: a native layout or the Lua one.
function M.apply(name, suit)
    local s = state_for(name)
    s.suit = suit
    save()
    local n = M.native[suit]
    if n then
        hl.workspace_rule({ workspace = ws_selector(name), layout = n.layout, layout_opts = n.layout_opts })
        -- master re-reads orientation only when the layout itself changes; on
        -- the focused workspace tell it directly (tileleft -> tile).
        local act = hl.get_active_workspace()
        if n.layout == "master" and act and act.name == name and act.tiled_layout == "master" then
            hl.dispatch(hl.dsp.layout("orientation" .. n.layout_opts.orientation))
        end
    else
        hl.workspace_rule({ workspace = ws_selector(name), layout = "lua:awesomewm" })
    end
end

--- Re-apply every saved workspace (config load / reload).
M.save = save

function M.restore()
    for name, s in pairs(M.state) do
        if valid[s.suit] then M.apply(name, s.suit) end
    end
end

local function step(arg)
    return tonumber(arg) or 0
end

--- One entry point for keys and the shell: "next", "prev", "suit <name>",
--- "mwfact <+-x>", "nmaster <+-n>", "ncol <+-n>", "swapmaster", "reset".
--- Translated to whatever the focused workspace's layout understands.
function M.cmd(msg)
    local ws = hl.get_active_workspace()
    if not ws then return end
    local name = ws.name
    local layout = ws.tiled_layout or ""
    local cmd, arg = tostring(msg):match("^%s*(%S+)%s*(.-)%s*$")
    local s = state_for(name)
    local function lmsg(m) hl.dispatch(hl.dsp.layout(m)) end

    if cmd == "next" or cmd == "prev" then
        local i = 1
        for j, n in ipairs(M.suits) do if n == s.suit then i = j end end
        i = ((i - 1 + (cmd == "next" and 1 or -1)) % #M.suits) + 1
        M.apply(name, M.suits[i])
    elseif cmd == "suit" and valid[arg] then
        M.apply(name, arg)
    elseif cmd == "reset" then
        M.state[name] = nil
        M.apply(name, DEFAULT.suit)
    elseif layout == "master" then
        if cmd == "mwfact" then lmsg("mfact " .. arg)
        elseif cmd == "nmaster" then lmsg(step(arg) >= 0 and "addmaster" or "removemaster")
        elseif cmd == "swapmaster" then lmsg("swapwithmaster")
        end
    elseif layout == "dwindle" then
        if cmd == "mwfact" then lmsg("splitratio " .. arg) end
    elseif layout == "lua:awesomewm" then
        lmsg(msg)
    end
end

--- Awesome's keys (its Mod+h/l etc. are taken here, so on Super+Alt).
function M.bind_keys()
    local binds = {
        { "SUPER + Y", "next" }, { "SUPER + SHIFT + Y", "prev" },
        { "SUPER + ALT + L", "mwfact +0.05", true }, { "SUPER + ALT + H", "mwfact -0.05", true },
        { "SUPER + ALT + SHIFT + H", "nmaster +1" }, { "SUPER + ALT + SHIFT + L", "nmaster -1" },
        { "SUPER + ALT + CTRL + H", "ncol +1" }, { "SUPER + ALT + CTRL + L", "ncol -1" },
        { "SUPER + CTRL + Return", "swapmaster" },
    }
    for _, b in ipairs(binds) do
        pcall(hl.unbind, b[1])
        hl.bind(b[1], function() M.cmd(b[2]) end, b[3] and { repeating = true } or nil)
    end
end

package.loaded["lua.awesome_layouts"] = M
return M
