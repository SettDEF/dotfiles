-- Dotos in Neovim: the same tasks as the window, the bar and quick capture,
-- through the same `dotos` CLI — so nothing here can disagree with them.
--
--   <leader>oo  the list (float): x tick · d doing · s timer · e rename
--               p priority · D delete · <CR> details · a add · u undo · q close
--   <leader>oa  add a task (capture syntax: @fri 14:00 !high #tag ~30m +project)
--   <leader>oc  a task from the cursor line / selection, linked to file:line
--   <leader>op  this project's tasks (git top-level name = +project)
--   <leader>oj  today's journal
--   <leader>os  stop the timer
local M = {}

local BIN = vim.fn.expand("~/.local/bin/dotos")
local ns = vim.api.nvim_create_namespace("dotos")
M.snap = nil

-- ── the CLI ──────────────────────────────────────────────────────────────

local function run(args, cb)
    vim.system(vim.list_extend({ BIN }, args), { text = true }, function(res)
        vim.schedule(function()
            if res.code ~= 0 then
                vim.notify("dotos: " .. vim.trim(res.stderr ~= "" and res.stderr or res.stdout), vim.log.levels.WARN)
            end
            if cb then cb(res) end
        end)
    end)
end

local function load(cb)
    run({ "snapshot", "--no-git" }, function(res)
        local ok, data = pcall(vim.json.decode, res.stdout or "", { luanil = { object = true, array = true } })
        if ok and data then
            M.snap = data
            if cb then cb(data) end
        end
    end)
end

local function project_name()
    local top = vim.fs.root(0, ".git")
    return top and vim.fs.basename(top) or nil
end

-- ── ordering and labels ──────────────────────────────────────────────────

local RANK = { doing = 0, overdue = 1, today = 2, tomorrow = 3, week = 4, later = 5, someday = 6, inbox = 7 }
local function rank(t)
    if t.state == "doing" then return 0 end
    if t.overdue then return 1 end
    return RANK[t.bucket] or 6
end
local function prio(t) return t.priority == "high" and 0 or t.priority == "low" and 2 or 1 end

local function open_tasks(snap, filter)
    local out = {}
    for _, t in ipairs(snap.tasks or {}) do
        if t.state ~= "done" and t.state ~= "cancelled" and (t.parent or "") == "" and (not filter or filter(t)) then
            table.insert(out, t)
        end
    end
    table.sort(out, function(a, b)
        if rank(a) ~= rank(b) then return rank(a) < rank(b) end
        if prio(a) ~= prio(b) then return prio(a) < prio(b) end
        return (a.due or "9999") < (b.due or "9999")
    end)
    return out
end

local GROUP = { [0] = "Doing", "Overdue", "Today", "Tomorrow", "This week", "Later", "Someday", "Inbox" }

local function when(t)
    if not t.due then return "" end
    local y, mo, d, h, mi = t.due:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
    if not y then return "" end
    local ts = os.time({ year = y, month = mo, day = d, hour = h, min = mi })
    local time = t.due_time and string.format("%s:%s", h, mi) or ""
    if t.bucket == "today" then return time ~= "" and time or "today" end
    if t.bucket == "tomorrow" then return "tomorrow " .. time end
    local days = math.floor((ts - os.time()) / 86400 + 0.5)
    if days < 0 then return (-days) .. "d late" end
    if days < 7 then return os.date("%a", ts) .. (time ~= "" and " " .. time or "") end
    return os.date("%d %b", ts)
end

local function dur(s)
    s = math.max(0, math.floor(s or 0))
    local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
    return h > 0 and string.format("%d:%02d", h, m) or (m .. "m")
end

-- ── the list float ───────────────────────────────────────────────────────

local view = { popup = nil, rows = {}, filter = nil, title = "Dotos" }

local function render()
    local p = view.popup
    if not p or not M.snap or not vim.api.nvim_buf_is_valid(p.bufnr) then return end
    local buf = p.bufnr
    local tasks = open_tasks(M.snap, view.filter)
    local active = M.snap.time and M.snap.time.active
    local lines, marks, rows = {}, {}, {}
    local width = vim.api.nvim_win_get_width(p.winid)

    local function add(text, hl, task)
        table.insert(lines, text)
        if hl then table.insert(marks, { #lines - 1, hl }) end
        rows[#lines] = task
    end

    if active then
        add(string.format("  ● %s  %s", active.title or "", dur(os.time() - (active.since or os.time()))), "DiagnosticOk")
        add("")
    end
    if #tasks == 0 then
        add("  Nothing open. a to add one.", "Comment")
    end
    local last
    for _, t in ipairs(tasks) do
        local r = rank(t)
        if r ~= last then
            if last ~= nil then add("") end
            add("  " .. GROUP[r], r == 1 and "DiagnosticError" or "Title")
            last = r
        end
        local box = t.state == "doing" and "◐" or "○"
        local meta = {}
        if t.project ~= "" then table.insert(meta, "+" .. t.project) end
        for _, tag in ipairs(t.tags or {}) do table.insert(meta, "#" .. tag) end
        local right = table.concat(meta, " ")
        local w = when(t)
        if w ~= "" then right = right .. (right ~= "" and "  " or "") .. w end
        local left = string.format("  %s %s%s", box, t.priority == "high" and "! " or "", t.title)
        local pad = math.max(1, width - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(right) - 2)
        add(left .. string.rep(" ", pad) .. right, nil, t)
    end
    add("")
    add("  x tick  d doing  s timer  e rename  p prio  D del  <CR> details  a add  u undo  q", "Comment")

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, m in ipairs(marks) do
        vim.api.nvim_buf_set_extmark(buf, ns, m[1], 0, { line_hl_group = m[2] })
    end
    for i, t in pairs(rows) do
        if t.overdue then
            vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { virt_text = { { "", "DiagnosticError" } } })
        end
    end
    view.rows = rows
    p.border:set_text("bottom", string.format(" %d open ", #tasks), "center")
end

local function refresh() load(render) end

local function current()
    if not view.popup then return nil end
    local line = vim.api.nvim_win_get_cursor(view.popup.winid)[1]
    return view.rows[line]
end

local function act(args) run(args, refresh) end

function M.list(opts)
    opts = opts or {}
    if view.popup then view.popup:unmount() end
    local Popup = require("nui.popup")
    view.filter = opts.filter
    view.title = opts.title or "Dotos"
    local p = Popup({
        enter = true,
        focusable = true,
        relative = "editor",
        position = "50%",
        size = { width = math.min(96, math.floor(vim.o.columns * 0.8)), height = math.min(30, math.floor(vim.o.lines * 0.75)) },
        border = { style = "rounded", text = { top = " " .. view.title .. " ", top_align = "center" } },
        buf_options = { modifiable = false, filetype = "dotos" },
        win_options = { cursorline = true, number = false, signcolumn = "no", wrap = false },
    })
    view.popup = p
    p:mount()
    p:on("BufLeave", function() p:unmount(); view.popup = nil end)

    local function map(lhs, fn) p:map("n", lhs, fn, { noremap = true, nowait = true }) end
    map("q", function() p:unmount(); view.popup = nil end)
    map("<Esc>", function() p:unmount(); view.popup = nil end)
    map("r", refresh)
    map("x", function() local t = current(); if t then act({ "done", t.uid }) end end)
    map("d", function() local t = current(); if t then act({ "state", t.uid, t.state == "doing" and "todo" or "doing" }) end end)
    map("s", function()
        local t = current()
        local a = M.snap and M.snap.time and M.snap.time.active
        if a and t and a.uid == t.uid then act({ "stop" }) elseif t then act({ "track", t.uid }) end
    end)
    map("p", function()
        local t = current()
        if not t then return end
        local nxt = ({ high = "low", low = "normal", normal = "high", [""] = "high" })[t.priority or ""]
        act({ "set", t.uid, "priority=" .. nxt })
    end)
    map("e", function()
        local t = current()
        if not t then return end
        vim.ui.input({ prompt = "Rename: ", default = t.title }, function(v)
            if v and v ~= "" and v ~= t.title then act({ "set", t.uid, "title=" .. v }) end
        end)
    end)
    map("D", function()
        local t = current()
        if not t then return end
        vim.ui.select({ "Delete", "Keep" }, { prompt = "Delete “" .. t.title .. "”?" }, function(c)
            if c == "Delete" then act({ "rm", t.uid }) end
        end)
    end)
    map("u", function() act({ "undo" }) end)
    map("a", function() M.add({ project = opts.project, after = refresh }) end)
    map("<CR>", function() local t = current(); if t then M.details(t) end end)

    vim.bo[p.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(p.bufnr, 0, -1, false, { "  loading…" })
    vim.bo[p.bufnr].modifiable = false
    refresh()
end

-- ── details ──────────────────────────────────────────────────────────────

function M.details(t)
    local lines = {
        "# " .. t.title, "",
        "state     " .. t.state .. (t.waiting_on ~= "" and ("  (on " .. t.waiting_on .. ")") or ""),
        "due       " .. (t.due and (t.due:gsub("T00:00:00", ""):gsub("T", " ")) or "—"),
        "priority  " .. (t.priority ~= "" and t.priority or "normal"),
        "project   " .. (t.project ~= "" and t.project or "—"),
        "list      " .. t.list,
        "tags      " .. (#(t.tags or {}) > 0 and table.concat(t.tags, ", ") or "—"),
        "estimate  " .. (t.estimate_min > 0 and (t.estimate_min .. " min") or "—"),
        "tracked   " .. dur(t.tracked_week_s) .. " this week",
    }
    for _, l in ipairs(t.links or {}) do table.insert(lines, "link      " .. l) end
    if t.notes ~= "" then
        table.insert(lines, "")
        vim.list_extend(lines, vim.split(t.notes, "\n"))
    end
    table.insert(lines, "")
    table.insert(lines, "gf on a link opens it · q close")
    local Popup = require("nui.popup")
    local p = Popup({
        enter = true, focusable = true, relative = "editor", position = "50%",
        size = { width = 72, height = math.min(#lines + 1, 30) },
        border = { style = "rounded", text = { top = " Task ", top_align = "center" } },
        buf_options = { filetype = "markdown" },
    })
    p:mount()
    vim.api.nvim_buf_set_lines(p.bufnr, 0, -1, false, lines)
    vim.bo[p.bufnr].modifiable = false
    p:map("n", "q", function() p:unmount() end)
    p:map("n", "<Esc>", function() p:unmount() end)
    p:on("BufLeave", function() p:unmount() end)
end

-- ── capture ──────────────────────────────────────────────────────────────

function M.add(opts)
    opts = opts or {}
    local Input = require("nui.input")
    local input = Input({
        relative = "editor", position = "50%", size = { width = 72 },
        border = { style = "rounded", text = { top = " Add a task — @fri 14:00 !high #tag ~30m +project ", top_align = "center" } },
    }, {
        prompt = "  ",
        default_value = opts.default or "",
        on_submit = function(line)
            if not line or vim.trim(line) == "" then return end
            if opts.project and not line:find("%+%S") then line = line .. " +" .. opts.project end
            local args = { "capture", line }
            if opts.note then vim.list_extend(args, { "--note", opts.note }) end
            run(vim.list_extend(args, { "--json" }), function(res)
                local ok, t = pcall(vim.json.decode, res.stdout or "")
                if ok and t and t.uid and opts.link then
                    run({ "set", t.uid, "link+=" .. opts.link })
                end
                if res.code == 0 then vim.notify("Dotos: added " .. ((ok and t and t.title) or line)) end
                if opts.after then opts.after() end
            end)
        end,
    })
    input:mount()
    input:map("i", "<Esc>", function() input:unmount() end)
    input:on("BufLeave", function() input:unmount() end)
end

--- a task from the cursor line or the selection, linked back to file:line
function M.from_code()
    local mode = vim.fn.mode()
    local s, e
    if mode:match("[vV]") then
        s, e = vim.fn.line("v"), vim.fn.line(".")
        if s > e then s, e = e, s end
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    else
        s, e = vim.fn.line("."), vim.fn.line(".")
    end
    local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(0, s - 1, e, false), " "))
    -- a TODO comment's text is the title; anything else is a note
    local title = text:match("TODO[:%s]+(.*)") or text:match("FIXME[:%s]+(.*)") or ""
    title = title:gsub("%s*%*/%s*$", ""):gsub("%s*%-%->%s*$", "")
    local path = vim.fn.expand("%:p")
    M.add({
        default = title,
        project = project_name(),
        note = title == "" and text or nil,
        link = string.format("file://%s#L%d", path, s),
    })
end

function M.project()
    local name = project_name()
    if not name then
        vim.notify("Dotos: not inside a git project", vim.log.levels.INFO)
        return M.list()
    end
    M.list({ title = "Dotos · " .. name, project = name, filter = function(t) return t.project == name end })
end

function M.journal()
    run({ "journal" }, function(res)
        local path = vim.trim(res.stdout or "")
        if path ~= "" then vim.cmd.edit(vim.fn.fnameescape(path)) end
    end)
end

function M.stop() run({ "stop" }, function() vim.notify("Dotos: timer stopped") end) end

-- ── statusline: the running timer, cheaply (refreshed every 30 s) ────────

local status = ""
function M.statusline() return status end
local function tick()
    load(function(s)
        local a = s.time and s.time.active
        status = a and string.format("● %s %s", a.title or "", dur(os.time() - (a.since or os.time()))) or ""
    end)
end

function M.setup()
    vim.api.nvim_create_user_command("Dotos", function(o)
        local f = ({ add = M.add, code = M.from_code, project = M.project, journal = M.journal, stop = M.stop })[o.fargs[1] or ""]
        if f then f() else M.list() end
    end, { nargs = "?", complete = function() return { "add", "code", "project", "journal", "stop" } end })
    local timer = vim.uv.new_timer()
    timer:start(1000, 30000, vim.schedule_wrap(tick))
end

return M
