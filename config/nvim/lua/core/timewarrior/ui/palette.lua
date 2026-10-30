local Menu = require("nui.menu")
local config = require("core.timewarrior.config")

local M = {}

-- Each entry: { key, label, action }. `action(api)` runs when selected.
function M.entries(api)
    return {
        {
            key = "r",
            label = "start",
            action = function()
                api.start()
            end,
        },
        {
            key = nil,
            label = "start (custom input)",
            action = function()
                api.start_form()
            end,
        },
        {
            key = "s",
            label = "stop",
            action = function()
                api.stop()
            end,
        },
        {
            key = "c",
            label = "cancel",
            action = function()
                api.cancel()
            end,
        },
        {
            key = nil,
            label = "resume last entry",
            action = function()
                api.resume()
            end,
        },
        {
            key = nil,
            label = "add entry",
            action = function()
                api.track_form()
            end,
        },
        {
            key = nil,
            label = "delete entry",
            action = function()
                api.delete_prompt()
            end,
        },
        {
            key = "a",
            label = "add description",
            action = function()
                api.annotate_prompt()
            end,
        },
        {
            key = "t",
            label = "set tag",
            action = function()
                api.tag_prompt()
            end,
        },
        {
            key = "d",
            label = "today report",
            action = function()
                api.report("day")
            end,
        },
        {
            key = nil,
            label = "yesterday report",
            action = function()
                api.report("yesterday")
            end,
        },
        {
            key = "w",
            label = "current week report",
            action = function()
                api.report("week")
            end,
        },
        {
            key = "L",
            label = "log",
            action = function()
                api.show_log()
            end,
        },
    }
end

function M.open(api)
    local entries = M.entries(api)
    local items = {}
    for _, e in ipairs(entries) do
        local prefix = e.key and (e.key .. "  ") or "   "
        table.insert(items, Menu.item(prefix .. e.label, { action = e.action }))
    end

    local cfg = config.get()
    local menu = Menu({
        position = "50%",
        size = { width = 36, height = #items },
        border = {
            style = cfg.popup.border or "rounded",
            text = { top = " TimeTracker ", top_align = "center" },
        },
        -- Normal:NormalFloat keeps the border-row background flush with
        -- the interior; Normal:Normal made it look brighter than the
        -- popup itself in themes where NormalFloat ≠ Normal.
        win_options = { winblend = 0, winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder" },
    }, {
        lines = items,
        max_width = 40,
        keymap = {
            focus_next = { "j", "<Down>", "<Tab>" },
            focus_prev = { "k", "<Up>", "<S-Tab>" },
            close = { "<Esc>", "q" },
            submit = { "<CR>" },
        },
        on_submit = function(item)
            if item.action then
                item.action()
            end
        end,
    })

    menu:mount()

    -- Single-letter accelerators.
    for _, e in ipairs(entries) do
        if e.key then
            vim.keymap.set("n", e.key, function()
                menu:unmount()
                if e.action then
                    e.action()
                end
            end, { buffer = menu.bufnr, nowait = true, silent = true })
        end
    end
end

return M
