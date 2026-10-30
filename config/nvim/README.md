# Neovim

My Neovim configuration. Colours come from tinct (the desktop's wallpaper
palette) and follow the wallpaper live; contrast helpers in
`lua/core/lib/colors/` keep text readable when the palette shifts.

## Where things are

- `init.lua`: entry point.
- `lua/core/config/`: options, autocommands, status column, winbar, terminal.
- `lua/core/lazyload/`: plugin specs, loaded lazily.
- `lua/core/lib/`: colours, layouts, diagnostics, snapshots.
- `after/ftplugin/`: per-filetype settings.
- `docs/`: structure, conventions, keymaps, LSP and plugin notes.

The config started from another person's dotfiles and has since been
rebuilt around this desktop.
