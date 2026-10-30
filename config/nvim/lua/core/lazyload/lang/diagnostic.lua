local CC = require("core.lib.colors")

-- Set the highlight groups for diagnostics from the live tinct palette.
-- Registered with core.hls so it re-runs (with fresh colors) on palette reloads.
local function apply_diagnostic_hls()
    local P = require("core.hls.palette")
    for level, fg in pairs({ Error = P.error, Warn = P.warn, Info = P.info, Hint = P.hint }) do
        vim.api.nvim_set_hl(0, "Diagnostic" .. level, {
            fg = fg,
            bg = CC.darken(P.background, 0.95, fg),
            bold = level == "Error",
            blend = level == "Error" and 20 or nil,
        })
        vim.api.nvim_set_hl(0, "DiagnosticUnderline" .. level, {
            undercurl = true,
            sp = fg,
            bg = CC.darken(P.background, 0.8, fg),
        })
    end
end
require("core.hls").register(apply_diagnostic_hls)

vim.diagnostic.config({
    virtual_text = {
        prefix = "▎", -- Could be '●', '▎', 'x', etc.
        spacing = 4,
    },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.INFO] = " ",
            [vim.diagnostic.severity.HINT] = " ",
        },
        linehl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticLineError",
            [vim.diagnostic.severity.WARN] = "DiagnosticLineWarn",
            [vim.diagnostic.severity.INFO] = "DiagnosticLineInfo",
            [vim.diagnostic.severity.HINT] = "DiagnosticLineHint",
        },
        numhl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
            [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
            [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
            [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
        },
    },
    underline = true, -- Enable or disable underlining
    update_in_insert = true, -- Update diagnostics in insert mode
    severity_sort = true, -- Sort diagnostics by severity
    float = {
        --        source = "always", -- Show the source of the diagnostics in the popup window
        --       border = "rounded", -- Use rounded borders for diagnostic float windows
        format = function(diagnostic)
            return string.format("%s [%s]", diagnostic.message, diagnostic.source)
        end,
    },
})
-- vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
-- vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })
