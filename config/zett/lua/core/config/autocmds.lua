-- Autocommands (as nvim's lua/core/config/autocmds.lua).

-- format on save: the file's language server formats it before it is written
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function() vim.lsp.buf.format({ timeout_ms = 1000 }) end,
})

-- started without a file: open the last file used in this folder (v:oldfiles)
vim.api.nvim_create_autocmd("VimEnter", {
  nested = true,
  callback = function()
    if vim.fn.argc() > 0 then return end
    local cwd = vim.fn.getcwd() .. "/"
    for _, f in ipairs(vim.v.oldfiles) do
      if f:sub(1, #cwd) == cwd and vim.fn.filereadable(f) == 1 then
        vim.cmd.edit(vim.fn.fnameescape(f))
        return
      end
    end
  end,
})
