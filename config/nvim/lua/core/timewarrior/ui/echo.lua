local config = require("core.timewarrior.config")

local M = {}

M.log = {}

local function position_for(opts, win, anchor_lines)
    local row = vim.o.lines - anchor_lines - 2
    local col = vim.o.columns - opts.width - 2
    if (config.get().echo.position or "bottomright") == "bottomleft" then
        col = 1
    end
    return row, col
end

local function close_after(winid, ms)
    vim.defer_fn(function()
        if winid and vim.api.nvim_win_is_valid(winid) then
            vim.api.nvim_win_close(winid, true)
        end
    end, ms)
end

function M.show(lines)
    if type(lines) == "string" then
        lines = vim.split(lines, "\n", { plain = true })
    end
    lines = vim.tbl_filter(function(l)
        return l ~= nil and l ~= ""
    end, lines or {})
    if #lines == 0 then
        return
    end
    for _, l in ipairs(lines) do
        table.insert(M.log, { ts = os.time(), msg = l })
    end

    local cfg = config.get().echo
    local width = math.max(20, math.min(60, vim.o.columns - 4))
    local height = math.min(3, #lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].bufhidden = "wipe"
    local row, col = position_for({ width = width }, nil, height)
    local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        focusable = false,
        zindex = 200,
    })
    vim.wo[win].winblend = 10
    close_after(win, cfg.duration or 4000)
end

function M.show_log()
    local lines = {}
    for _, e in ipairs(M.log) do
        table.insert(lines, os.date("%H:%M:%S", e.ts) .. "  " .. e.msg)
    end
    if #lines == 0 then
        lines = { "(no messages)" }
    end
    vim.cmd("botright 10split [TimeTracker Log]")
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

return M
