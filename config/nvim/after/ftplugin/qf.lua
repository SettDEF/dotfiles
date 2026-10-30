local bkeymap = require("core.mapping.utils").bufKeymap
--------------------------------------------------------------------------------
vim.opt_local.cursorlineopt = "line"

bkeymap("n", "q", vim.cmd.close, { desc = " Close" })

-- keep <CR> behavior of going to entry, even if <CR> is mapped to something else otherwise
bkeymap("n", "<CR>", "<CR>")
