local config = require("core.timewarrior.config")
local cli = require("core.timewarrior.cli")
local echo = require("core.timewarrior.ui.echo")
local form = require("core.timewarrior.ui.form")
local report = require("core.timewarrior.ui.report")
local palette = require("core.timewarrior.ui.palette")
local statusline = require("core.timewarrior.statusline")

local M = {}

local function notify_result(res)
    if not res then
        return
    end
    local lines = {}
    for _, l in ipairs(res.stdout or {}) do
        table.insert(lines, l)
    end
    for _, l in ipairs(res.stderr or {}) do
        table.insert(lines, l)
    end
    echo.show(lines)
end

local function require_timew()
    if not cli.available() then
        echo.show("`timew` not found on $PATH")
        return false
    end
    return true
end

function M.start(opts)
    if not require_timew() then
        return
    end
    cli.start(opts or {}, notify_result)
end

function M.stop()
    if not require_timew() then
        return
    end
    cli.stop(notify_result)
end

function M.cancel()
    if not require_timew() then
        return
    end
    cli.cancel(notify_result)
end

function M.resume()
    if not require_timew() then
        return
    end
    cli.continue(notify_result)
end

function M.report(range)
    if not require_timew() then
        return
    end
    report.open(range or "day")
end

function M.statusline()
    return statusline.get()
end

local api = {}
api.start = M.start
api.stop = M.stop
api.cancel = M.cancel
api.resume = M.resume
api.report = M.report
api.show_log = echo.show_log

api.start_form = function()
    if not require_timew() then
        return
    end
    form.open("start", function(payload)
        cli.start(payload, notify_result)
    end)
end

api.track_form = function()
    if not require_timew() then
        return
    end
    form.open("track", function(payload)
        cli.track(payload, notify_result)
    end)
end

api.annotate_prompt = function()
    if not require_timew() then
        return
    end
    vim.ui.input({ prompt = "Annotate @id (default @1): " }, function(id)
        id = (id == nil or id == "") and "@1" or id
        vim.ui.input({ prompt = "Description: " }, function(text)
            if text and text ~= "" then
                cli.annotate(id, text, notify_result)
            end
        end)
    end)
end

api.tag_prompt = function()
    if not require_timew() then
        return
    end
    vim.ui.input({ prompt = "Tag @id (default @1): " }, function(id)
        id = (id == nil or id == "") and "@1" or id
        vim.ui.input({ prompt = "Tags (space-sep): " }, function(text)
            if text and text ~= "" then
                cli.tag(id, vim.split(text, "%s+"), notify_result)
            end
        end)
    end)
end

api.delete_prompt = function()
    if not require_timew() then
        return
    end
    vim.ui.input({ prompt = "Delete @id: " }, function(id)
        if id and id ~= "" then
            cli.delete(id, notify_result)
        end
    end)
end

function M.open()
    palette.open(api)
end

function M.setup(user)
    config.apply(user)

    vim.api.nvim_create_user_command("TimeTracker", function(opts)
        local arg = opts.fargs[1]
        if not arg then
            M.open()
        elseif api[arg] then
            api[arg]()
        elseif M[arg] then
            M[arg]()
        else
            vim.notify("Unknown TimeTracker action: " .. arg, vim.log.levels.WARN)
        end
    end, {
        nargs = "?",
        complete = function()
            return {
                "open",
                "start",
                "stop",
                "cancel",
                "resume",
                "start_form",
                "track_form",
                "annotate_prompt",
                "tag_prompt",
                "delete_prompt",
                "report",
                "show_log",
            }
        end,
    })

    local km = config.get().keymap
    if km and km ~= "" then
        vim.keymap.set("n", km, M.open, { silent = true, desc = "TimeTracker" })
    end

    statusline.start_timer()
end

return M
