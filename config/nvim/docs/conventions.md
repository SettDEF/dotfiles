# Conventions

Coding rules used across this config. Keep new code consistent with these so file-to-file style stays uniform.

## Indentation

- Most files use **tabs** for indent. Some older files use spaces — preserve whatever the file already uses; do not mix in a single file.

## Comments

- Plain comments only. No glyphs, icons, or decorative banners.
- Comments explain **why**, not what. Avoid restating identifiers.
- Don't write multi-paragraph docstrings on Lua functions; one line max if needed.

## Plugin specs

- Disabled plugins stay in the spec with `enabled = false`. Don't delete them.
- Only declare options in `opts` / `setup({ ... })` that **differ from the upstream default**. Lines that re-declare defaults get stripped.
- Keep `keys`, `event`, `cmd`, `ft`, `dependencies`, `build`, `init` — those are intentional load triggers, not config options.

## Modules

- Each file returns a single table. Local helpers stay file-local; only what other modules need is exposed on `M`.
- Avoid creating top-level globals. If you see a global declaration in older code (e.g. `DynamicList = {}`), check it isn't referenced elsewhere before consolidating onto the module table.

## Highlights

- All highlight definitions live under `lua/core/hls/`. Do not call `nvim_set_hl` from feature code.
- Palette comes from tinct (`~/.local/state/quickshell/user/generated/nvim_colors.lua`, loaded by tinct.nvim). Reference colors via `core.hls.cocoa`, not hard-coded hex.

## API surface

- Prefer `vim.uv` over `vim.loop` (the latter is deprecated).
- Prefer `vim.lsp.get_clients()` over `vim.lsp.get_active_clients()`.
- Prefer `vim.lsp.config` + `vim.lsp.enable` over the older `lspconfig[name].setup({ ... })` style for new servers.

## File placement

- Pure-vim feature without plugins → `lua/core/config/`.
- Lazy plugin spec → `lua/core/lazyload/plugins/<group>.lua`.
- Language tooling (LSP/lint/format/DAP setup) → `lua/core/lazyload/lang/`.
- Filetype-specific runtime config → `after/ftplugin/<ft>.lua`.
- Project-internal docs → `docs/`.
