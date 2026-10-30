# Keymaps

Global keymaps live in **two** places:

| File | What goes here |
|------|----------------|
| `lua/core/mapping/global.lua` | Project-wide, vim-standard-style maps loaded at startup via `core.mapping.global()`. |
| `lua/core/keymaps/init.lua` | Feature-driven maps that depend on plugins (telescope, harpoon, etc.) — loaded lazily from plugin specs. |

`lua/core/mapping/utils.lua` and `lua/core/keymaps/utils.lua` provide thin `map()` wrappers (description, mode, defaults). Use them instead of raw `vim.keymap.set` for consistency.

`lua/core/mapping/functions.lua` holds named functions used as keymap RHSs so the binding tables stay readable.

## Plugin-local keys

Lazy specs declare keys via `keys = { ... }` in `lua/core/lazyload/plugins/*.lua`. These trigger the plugin to load on first press. Keep plugin-specific bindings here (not in `mapping/global.lua`) so the plugin stays lazy.

## Adding a binding

- **Global, immediate:** add it to `mapping/global.lua` using the `map` helper from `mapping/utils.lua`.
- **Plugin-triggering:** put it in that plugin's spec under `keys = { ... }`.
- **Buffer-local (filetype):** drop it in `after/ftplugin/<ft>.lua`.

## Discovering bindings

`folke/which-key.nvim` is registered in `ui/init.lua`. Press `<leader>` and wait — the popup lists every map in scope.

## Conventions

- Always set `desc =` so which-key has a label.
- Use the `map` helper rather than `vim.keymap.set` directly.
- Group related leader prefixes consistently (e.g. `<leader>g*` git, `<leader>t*` terminal/tracker, `<leader>f*` find/format — see existing code for current usage).
