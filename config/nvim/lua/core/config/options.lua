local C = require("core.lib.utils.chars")

-- Important to place this before loading plugins.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.opt.winborder = "rounded"

vim.opt.showmode = false
vim.opt.swapfile = false
vim.opt.mouse = ""
vim.opt.hlsearch = true
vim.opt.undofile = true
vim.opt.autoread = true
-- Lower the idle timer so CursorHold fires fast — Claude's edits show up in
-- gitsigns within ~250ms instead of 4s.
vim.opt.updatetime = 250

-- Disable unused providers
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- Detect external file changes (e.g. Claude editing a file) so gitsigns and
-- LSP see the new content. Runs on common focus / idle events.
local checktime_group = vim.api.nvim_create_augroup("CoreAutoChecktime", { clear = true })
vim.api.nvim_create_autocmd(
    { "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermClose", "TermLeave" },
    {
        group = checktime_group,
        callback = function()
            if vim.fn.mode() ~= "c" and vim.bo.buftype == "" then
                pcall(vim.cmd.checktime)
            end
        end,
    }
)

-- CursorHold only fires when the cursor is idle, which is unreliable on
-- network / external mounts (/mnt/*, NFS, SSHFS, etc.) where you may be
-- actively typing while Claude writes elsewhere — *and* on those mounts the
-- mtime/inotify signal is often coarse or missing. A 1s libuv timer that
-- just calls :checktime catches every reload regardless of cursor state.
do
    local poll = vim.uv.new_timer()
    poll:start(
        1500,
        1500,
        vim.schedule_wrap(function()
            if vim.fn.mode() == "c" then
                return
            end
            pcall(vim.cmd.checktime)
        end)
    )
end

vim.opt.clipboard:append("unnamedplus")
vim.g.clipboard = nil

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.textwidth = 0

vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.showtabline = 0

vim.opt.inccommand = "nosplit"

vim.opt.cmdheight = 0
vim.g.VM_set_statusline = 0
vim.g.VM_silent_exit = 1

vim.opt.fillchars = {
    eob = " ",
    diff = "╱",
    vert = C.right_thick,
    vertleft = C.right_thick,
    vertright = C.right_thick,
    verthoriz = C.right_thick,
    horiz = C.bottom_thin,
    horizup = C.bottom_right_thin,
}

-- Cursor
vim.opt.cursorline = true
vim.opt.cursorlineopt = "number"

-- Windows
vim.opt.winblend = 0
vim.opt.pumblend = 0
vim.opt.pumheight = 10

vim.cmd("filetype plugin indent on")
