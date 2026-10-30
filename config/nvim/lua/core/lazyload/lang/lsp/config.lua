local DC = require("cmp_nvim_lsp").default_capabilities()

local M = {}

M.lsp_flags = {
    debounce_text_changes = 100, -- ms
}

M.on_attach = function(client, bufnr)
    if client.server_capabilities.documentHighlightProvider then
        local group =
            vim.api.nvim_create_augroup("lsp_document_highlight_" .. bufnr, { clear = true })
        vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
            buffer = bufnr,
            group = group,
            callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd("CursorMoved", {
            buffer = bufnr,
            group = group,
            callback = vim.lsp.buf.clear_references,
        })
    end
end

M.default = {
    lsp_flags = M.lsp_flags,
    capabilities = DC,
    on_attach = M.on_attach,
}

M.capabilities = DC

return M
