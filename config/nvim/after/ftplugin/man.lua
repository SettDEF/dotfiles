local bkeymap = require("core.mapping.utils").bufKeymap

vim.opt.statuscolumn = nil
vim.opt.relativenumber = true

-- `gO` opens the heading-selection man pages
bkeymap("n", "gs", "gO", { remap = true })
