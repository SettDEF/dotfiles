-- Bootstrap lazy.nvim (clone on first launch) then load plugin specs
-- from core.lazyload.plugins.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

local chars = require("core.lib.utils.chars")

require("lazy").setup("core.lazyload.plugins", {
    ui = { border = chars.border_chars_outer_thin },
    checker = { notify = false, enabled = true },
    dev = { fallback = true, path = "~/workspace/nvim_projekts" },
})
