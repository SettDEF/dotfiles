-- Language servers (as nvim's lazyload/lang/lsp). zett knows ~80 languages and uses whichever
-- server is installed; Mason's folder (from nvim) is searched too. Another server for a file
-- type, or one zett does not know, goes in servers:
--   servers = { ext = { cmd = { "program", "--stdio" }, lang = "language-id" } }
zett.opt.lsp = {
  path = { "~/.local/share/nvim/mason/bin" },
  servers = {},
}

-- completion while typing (Neovim's vim.lsp.completion; Tab walks a snippet's stops)
vim.lsp.completion.enable(true)
