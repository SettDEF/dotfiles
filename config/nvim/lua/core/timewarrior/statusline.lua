local cli = require("core.timewarrior.cli")
local parse = require("core.timewarrior.parse")
local config = require("core.timewarrior.config")

local M = {}

local state = { tag = nil, start = nil, last_check = 0 }
local timer = nil

local function refresh()
    if not cli.available() then
        return
    end
    cli.active(function(active)
        if active then
            state.tag = active.tag or active["tag.1"] or ""
            state.start = active.start
        else
            state.tag, state.start = nil, nil
        end
        state.last_check = os.time()
    end)
end

function M.start_timer()
    if timer then
        return
    end
    timer = vim.uv.new_timer()
    local interval = config.get().statusline.interval_ms or 60000
    timer:start(0, interval, vim.schedule_wrap(refresh))
    vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("TimewarriorStatusline", { clear = true }),
        callback = refresh,
    })
end

function M.get()
    if not state.start then
        return ""
    end
    local fmt = config.get().statusline.format or "%s · %s"
    local elapsed = parse.fmt_elapsed(parse.elapsed_seconds(state.start))
    return " " .. string.format(fmt, state.tag or "", elapsed)
end

return M
