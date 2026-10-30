-- Options (as nvim's lua/core/config/options.lua).

-- Vim's modes and Doom's SPC tree (zett's default is Emacs')
zett.opt.keys = "vim"

-- no row under the status line: the : line and messages take the status line's place
vim.o.cmdheight = 0

-- the tab line of buffers (shown once two or more are open)
zett.opt.tabs = true

-- signs (git, diagnostics) in their own column when there are any, as nvim's default
vim.o.signcolumn = "auto"
