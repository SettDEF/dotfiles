local M = {}

M.defaults = {
    keymap = "<leader>tt",
    cmd = "timew",
    tags = { "Research", "Personal", "Reading", "Learning", "Other", "Break" },
    colors = {
        Personal = "DiagnosticError",
        Other = "DiagnosticError",
    },
    popup = {
        width = 0.55,
        height = 0.50,
        border = "rounded",
    },
    echo = {
        duration = 4000,
        position = "bottomright",
    },
    statusline = {
        interval_ms = 60000,
        format = "%s · %s",
    },
}

M.values = vim.deepcopy(M.defaults)

function M.apply(user)
    M.values = vim.tbl_deep_extend("force", M.defaults, user or {})
    return M.values
end

function M.get()
    return M.values
end

return M
