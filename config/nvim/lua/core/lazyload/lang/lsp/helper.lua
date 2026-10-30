vim.api.nvim_create_user_command("ClangdSwitchSourceHeader", function()
    vim.lsp.buf.execute_command({
        command = "clangd.switchsourcesourceheader",
        arguments = { vim.uri_from_bufnr(0) },
    })
end, {})
