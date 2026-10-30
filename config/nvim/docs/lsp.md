# LSP

## Files

| Path | Role |
|------|------|
| `lua/core/lazyload/plugins/lsp.lua` | Lazy spec for `nvim-lspconfig` + deps. The `config` function loads the config below. |
| `lua/core/lazyload/lang/lsp/init.lua` | Per-server `vim.lsp.config(name, opts)` calls + `vim.lsp.enable({...})` at the bottom. |
| `lua/core/lazyload/lang/lsp/config.lua` | Shared `M.default`, `M.capabilities` (cmp_nvim_lsp), `M.on_attach` (document_highlight). |
| `lua/core/lazyload/lang/lsp/helper.lua` | Misc helpers used by server configs. |
| `lua/core/lazyload/lang/lsp/tsn.lua` | TypeScript-specific extras. |
| `lua/core/lazyload/lang/diagnostic.lua` | Diagnostic display config. |

## Lifecycle

1. `nvim-lspconfig` is registered to load on `BufReadPre / BufReadPost / BufNewFile`.
2. When a buffer triggers it, `config()` runs:
   - sets `vim.lsp.config.capabilities.offsetEncoding = { "utf-16" }`
   - loads diagnostic and color-preview hooks
   - `require("neoconf").setup(...)`
   - `require("core.lazyload.lang.lsp")` — registers all servers.
   - `require("mason").setup(...)`
3. Each `vim.lsp.config("<name>", opts)` merges over upstream configs that ship in `lsp/<name>.lua` from nvim-lspconfig (auto-loaded by Neovim 0.11+).
4. The trailing `vim.lsp.enable({...})` activates the listed servers; they attach when filetype matches.

## Servers configured

`html`, `cssls`, `ts_ls`, `eslint`, `jsonls`, `pyright`, `dockerls`, `docker_compose_language_service`, `yamlls`, `terraformls`, `clangd`, `bashls`, `qmlls`, `lua_ls`, `elixirls`, `intelephense`, `slint_lsp`.

## Adding a server

1. Install via Mason (`:Mason`) or system package manager.
2. Append a `vim.lsp.config("<name>", { … })` block in `lang/lsp/init.lua`.
3. Add the name to the `vim.lsp.enable({ … })` list at the bottom.
4. Re-open a matching filetype; verify with `:LspInfo`.

If the server already has a default in nvim-lspconfig's bundled `lsp/<name>.lua`, you only need overrides (extra `settings`, custom `on_attach`, etc.).

## `on_attach` defaults

`config.lua` `M.on_attach` enables `documentHighlightProvider` autocmds (CursorHold/CursorHoldI → `vim.lsp.buf.document_highlight`, CursorMoved → `clear_references`).

`M.default` bundles `lsp_flags`, `capabilities`, and `on_attach` — used via `vim.tbl_extend("force", C.default, { ... })` for servers that don't need a custom attach.

## Per-server quirks

- **eslint** — `on_attach` adds a `BufWritePre` autocmd that runs `vim.lsp.buf.format({ async = false })`.
- **clangd** — overrides `capabilities.offsetEncoding = { "utf-16" }`, enables inlay hints, and binds `<leader>sh` to `:ClangdSwitchSourceHeader`.
- **intelephense** — pulls licence from `$INTELEPHENSE_LICENCE`; sets `phpVersion = "8.2"`; large stub list; binds `gd/gr/gi/<leader>rn/<leader>ca/<leader>f/K/<C-h>/[d/]d/<leader>ih`.
- **slint_lsp** — buffer-local wrap settings; declared with explicit `cmd` and enabled separately right after.
- **lua_ls** — workspace library includes `stdpath("config")` and the runtime files; `vim` declared as a global to silence diagnostics.
