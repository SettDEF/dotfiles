local cli = require("core.timewarrior.cli")

local M = {}

local function open_scratch(title)
    vim.cmd("vsplit")
    vim.cmd("enew")
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "timew_report"
    pcall(vim.api.nvim_buf_set_name, buf, title)
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true })
    return buf
end

function M.open(range)
    range = range or "day"
    local buf = open_scratch("[TimeTracker " .. range .. "]")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Loading " .. range .. " report..." })
    cli.summary(range, function(res)
        if not vim.api.nvim_buf_is_valid(buf) then
            return
        end
        local lines = {}
        vim.list_extend(lines, res.stdout or {})
        if res.stderr and #res.stderr > 0 then
            table.insert(lines, "")
            table.insert(lines, "-- stderr --")
            vim.list_extend(lines, res.stderr)
        end
        if #lines == 0 then
            lines = { "(no output)" }
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    end)
end

return M
