-- Plugins from GitHub or a local folder (:PlugList, :PlugUpdate), as nvim's lazyload/plugins.

-- the theme: tinct.nvim, the same one nvim uses. It follows the desktop's colours live
-- (the palette tinct writes for the wallpaper; a change shows without a restart)
zett.plug("tinct.nvim", {
  dir = (os.getenv("PROJECTS_DIR") or (os.getenv("HOME") .. "/dev/projects")) .. "/tinct/tinct.nvim",
  -- as nvim's (lazyload/plugins/theme.lua): the terminal's own background shows through
  opts = {
    transparent = { bg = true, statusline = true },
    watch = true,
    palette_override = { error = "#f38ba8", warn = "#fabd2f", info = "#89b4fa", hint = "#94e2d5", success = "#a6e3a1" },
  },
})
vim.cmd.colorscheme("tinct")

-- LSP progress in the corner
zett.plug("j-hui/fidget.nvim", { opts = {} })

-- the file tree (neo-tree's settings in nvim)
require("core.plugins.browsing")

-- git signs and hunk keys
require("core.plugins.git")
