# Structure

## Entry points

```
init.lua                  -- bootstraps the core namespace
lua/core/init.lua         -- ordered loader (see below)
```

`lua/core/init.lua` runs four steps in order:

1. `core.config.options` — vim options before plugins.
2. `core.lazyload` — bootstraps lazy.nvim and registers plugin specs.
3. `core.config` — native (non-plugin) features: terminal, statuscolumn, winbar.
4. `core.mapping.global` — global keymaps.

## Top-level directories

| Path | Role |
|------|------|
| `lua/core/config/` | Features built on stock Neovim (no plugin dep). Options, statuscolumn, terminal, winbar. |
| `lua/core/lazyload/` | Everything plugin-related. See `plugins/`, `lang/`, `managers/`, `themes/`. |
| `lua/core/lazyload/plugins/` | Lazy specs grouped by purpose: `completion`, `edit`, `git`, `lsp`, `syntax`, `theme`, `ui/`, `browsing`, `formatting`, `utils`. |
| `lua/core/lazyload/lang/` | Language tooling: `lsp/`, `completion`, `diagnostic`, `lint`, `dap`. |
| `lua/core/lib/` | Project utilities: `git`, `diagnostics`, `events`, `layouts`, `symbols`, `colors/`, `utils/`. |
| `lua/core/hls/` | Highlight-group setup: `cocoa` (palette), `custom`, `diagnostics`, `nui`, `events`. |
| `lua/core/keymaps/` | Buffer-local and feature-specific keymap helpers. |
| `lua/core/mapping/` | Global mapping wiring (`global.lua`) and helpers (`utils.lua`, `functions.lua`). |
| `lua/core/environments/` | Per-host overrides: `neovide`, `vscode`, `wezterm`. |
| `lua/core/utils/` | Shared utility modules (chars, git, lua, neovim). |
| `after/ftplugin/` | Per-filetype overrides, loaded automatically by Neovim. |
| `after/syntax/` | Custom syntax for `abp`, `applescript`, `brewfile`, `log`. |
| `queries/` | Tree-sitter query overrides. |
| `snippets/` | LuaSnip JSON snippets (`general/`, `project-specific/`). |
| `dap/` | Debug adapter configs (`debugpy`, `js-debug`). |
| `debug/` | `repro.lua` for minimal-config bug repros. |
| `docs/` | This directory. |

## Notable files

- `lua/core/lazyload/managers/lazy/bootstrap.lua` — clones lazy.nvim if missing.
- `lua/core/lazyload/managers/lazy/init.lua` — passes plugin specs to `lazy.setup`.
- `lua/core/config/winbar.lua` — custom winbar (used as `M.get_winbar()`).
- `lua/core/lazyload/plugins/ui/statusline.lua` — heirline statusline definition.
- `lua/core/lib/utils/init.lua` — buffer/window helpers consumed by winbar/statusline.
