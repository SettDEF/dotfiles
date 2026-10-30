local M = {}

vim.opt.signcolumn = "auto"

-- Signs first, right aligned relative number
function M.signs_right_align()
    vim.opt.number = true
    vim.opt.relativenumber = true
    vim.opt.numberwidth = 3
    vim.opt.statuscolumn = "%s%=%{v:relnum?v:relnum:v:lnum} "
end

function M.terminal()
    vim.opt_local.numberwidth = 1
    vim.opt_local.statuscolumn = " "
end

-- Statuscolumn was added in 0.9.
if vim.fn.has("nvim-0.9") == 0 then
    -- Fallback for when cannot set custom statuscolumn.
    vim.opt.relativenumber = true
    vim.opt.number = true
    vim.opt.signcolumn = "yes"
else
    M.signs_right_align()
end

return M
