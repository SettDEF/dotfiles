# Plugins

Specs live under `lua/core/lazyload/plugins/`. Each file returns a list table consumed by `lazy.setup`. Plugins listed with `enabled = false` stay in the spec but are not installed.

## `completion.lua`

| Plugin | Purpose |
|--------|---------|
| `hrsh7th/nvim-cmp` | Completion engine. Custom format function adds source labels and inline color swatches for LSP color values. |
| `hrsh7th/cmp-omni`, `cmp-nvim-lsp`, `cmp-buffer`, `cmp-path`, `cmp-cmdline`, `cmp-calc`, `cmp-emoji`, `cmp-async-path`, `cmp-nvim-tags` | Completion sources. |
| `dmitmel/cmp-cmdline-history` | History source for cmdline. |
| `lukas-reineke/cmp-rg` | Ripgrep source (only loaded if `rg` is on PATH). |
| `saadparwaiz1/cmp_luasnip` + `L3MON4D3/LuaSnip` (+ `friendly-snippets`) | Snippet engine. Loads VSCode snippets from `~/.config/nvim/snippets`. |
| `chrisgrieser/cmp_yanky` | Completes from yank history. |
| `Exafunction/codeium.vim` | AI completion. **disabled.** |
| `saghen/blink.cmp` | Alternative engine. **disabled.** |

## `edit.lua`

| Plugin | Purpose |
|--------|---------|
| `echasnovski/mini.comment` (+ `nvim-ts-context-commentstring`) | Commenting with treesitter-aware commentstrings. |
| `Wansmer/treesj` | Toggle multi-line / single-line code blocks. |
| `nmac427/guess-indent.nvim` | Auto-detect indent on buffer load. |
| `johmsalas/text-case.nvim` | Case conversion (`snake_case`, `camelCase`, …). |
| `echasnovski/mini.surround` | Surround-text operators. |
| `stevearc/oil.nvim` | Edit the filesystem like a buffer. |
| `echasnovski/mini.move` | Move lines/blocks with arrows. |
| `echasnovski/mini.align` | Visual alignment. |
| `folke/flash.nvim` | Jump motion (overlaps with leap/flit). |
| `ggandor/leap.nvim` (+ `flit.nvim`) | Older 2-char jump motion. |
| `gbprod/yanky.nvim` | Yank ring with telescope picker. |
| `gbprod/substitute.nvim` | Operator-style substitute. |
| `chrisgrieser/nvim-spider` | Smarter `w`/`b`/`e` for camelCase identifiers. |
| `stevearc/quicker.nvim` | Improved quickfix UI. |
| `cshuaimin/ssr.nvim` | Structural search and replace. |
| `OXY2DEV/markview.nvim` | Markdown preview rendering. |
| `lervag/vimtex` | LaTeX support. |
| `Thiago4532/mdmath.nvim` | Render LaTeX math in Markdown. |

## `browsing.lua`

| Plugin | Purpose |
|--------|---------|
| `nvim-telescope/telescope.nvim` (+ `media-files`, `symbols`, `Marskey/telescope-sg`) | Fuzzy picker. |
| `nvim-neo-tree/neo-tree.nvim` | File explorer sidebar. |

## `git.lua`

| Plugin | Purpose |
|--------|---------|
| `sindrets/diffview.nvim` | Diff/merge UI. |
| `lewis6991/gitsigns.nvim` | Sign-column git markers and hunk ops. |
| `tpope/vim-fugitive` | `:G` git commands. |
| `pwntester/octo.nvim` | GitHub PR/issue client. |
| `ruifm/gitlinker.nvim` | Generate permalinks to remote files. |
| `topaxi/gh-actions.nvim` | View GitHub Actions runs. |

## `lsp.lua`

`neovim/nvim-lspconfig` plus deps: `mason.nvim`, `mason-lspconfig.nvim`, `neoconf.nvim`, `schemastore.nvim`, `fidget.nvim`. Also `folke/lazydev.nvim` (with `wezterm-types`, `luvit-meta`), `mrcjkb/rustaceanvim`, and `nvim-neotest/neotest` (+ `nvim-nio`, `neotest-elixir`). Server-specific config lives in `lua/core/lazyload/lang/lsp/`.

## `syntax.lua`

| Plugin | Purpose |
|--------|---------|
| `nvim-treesitter/nvim-treesitter` | Parsers and highlighting. |
| `nvim-treesitter/nvim-treesitter-context` | Sticky context line. |
| `nvim-treesitter/playground` | Tree inspector (deprecated; use `:InspectTree`). |
| `ziontee113/syntax-tree-surfer` | Treesitter-driven node movement. |
| `folke/todo-comments.nvim` | Highlight and search `TODO/NOTE/FIX:` comments. |

## `theme.lua`

| Plugin | Purpose |
|--------|---------|
| `catppuccin/nvim` | Colorscheme (currently disabled at top of file). |
| `williamkiddy/cocoa.nvim` | Custom colorscheme. |

## `formatting.lua`

`stevearc/conform.nvim` — formatter dispatcher driven by per-filetype tables.

## `utils.lua`

| Plugin | Purpose |
|--------|---------|
| `olimorris/persisted.nvim` | Session persistence. |
| `dstein64/vim-startuptime` | `:StartupTime` profiler. |
| `akinsho/toggleterm.nvim` | Persistent terminal splits. |
| `chrisgrieser/nvim-early-retirement` | Auto-close idle buffers. |
| `glacambre/firenvim` | Embed Neovim in browser textareas. |
| `direnv/direnv.vim` | Load `.envrc` per directory. |

## `ui/init.lua`

| Plugin | Purpose |
|--------|---------|
| `rebelot/heirline.nvim` | Statusline framework (config in `ui/statusline.lua`). |
| `mvllow/modes.nvim` | Mode-driven cursor-line color. |
| `folke/noice.nvim` | Cmdline / messages UI. **disabled.** |
| `stevearc/dressing.nvim` | Better `vim.ui.select`. |
| `lukas-reineke/indent-blankline.nvim` | Indent guides. **disabled.** |
| `shellRaining/hlchunk.nvim` | Chunk highlight. **disabled.** |
| `rcarriga/nvim-notify` | Notification UI. |
| `folke/which-key.nvim` | Pop-up keymap reference. |
| `echasnovski/mini.hipatterns` | Pattern highlighter. **disabled.** |
| `folke/paint.nvim` | Token highlighter for arbitrary patterns. |
| `uga-rosa/ccc.nvim` | Color picker / inline color highlighter. |
| `folke/edgy.nvim` | Sidebar/window manager. |

## `ui/` extras

- `statusline.lua` — heirline statusline definition (custom code, no upstream defaults).
- `winbar.lua` — `b0o/incline.nvim` winbar tags.
- `windowline.lua` — heirline-based per-window decoration.
- `upscreen.lua` — top-of-screen UI fragments.
- `utils.lua` — shared statusline helpers (`build_pill`, separators).

## Disabled plugins (`enabled = false`) kept in the spec

`codeium.vim`, `blink.cmp`, `noice.nvim`, `indent-blankline.nvim`, `hlchunk.nvim`, `mini.hipatterns`. Re-enable by flipping the flag.
