# `timewarrior.nvim` — implementation plan

A small in-config Neovim plugin that wraps the `timew` CLI in a `nui.nvim`-driven UI.
Inspired by the screenshots: a command palette ("TimeTracker"), a structured entry form
(Backdate / Description / Tag), and a thin wrapper around the actual `timew` output.

> **Lives in this Neovim config**, not as an external Lazy plugin.
> Path: `lua/core/lazyload/plugins/timewarrior/` (module name: `core.timewarrior`).

---

## 1. Goals

- One keystroke (e.g. `<leader>tt`) opens a **TimeTracker palette** listing actions.
- Single-letter accelerators (`r`/`s`/`c`/`a`/`t`/`d`/`w` …) jump straight to actions.
- Structured **add/edit form** for `start (custom input)` and `add entry`:
  - `Backdate` — `from HH:MM to HH:MM` with sensible defaults.
  - `Description` — free text (becomes `timew annotate` or `timew start … "<text>"`).
  - `Tag` — multi-select from a known list, with new tags allowed.
- Render reports (`day` / `yesterday` / `week`) in a scratch buffer with syntax highlighting.
- Show `timew`'s own notifications/info in a small floating echo at the bottom.
- **Status bar component** showing the active tracker (lualine integration optional).

## 2. Non-goals

- Replacing `timew` config or hooks. Plugin only invokes the CLI.
- Database editing — anything risky goes through the form, not a free buffer.
- Calendar/Gantt rendering. Reports stay textual.

---

## 3. Dependencies

| Package | Why |
|---|---|
| `MunifTanjim/nui.nvim` | All UI primitives (Popup, Input, Menu, Layout). |
| `nvim-lua/plenary.nvim` *(already in tree)* | `Job:new` for async `timew` calls, async paths. |
| `timew` (system binary) | Nothing runs without it. Hard-fail on `:checkhealth`. |

`nui.nvim` is the only **new** dependency. Add to existing `ui/init.lua` lazy spec:

```lua
{ "MunifTanjim/nui.nvim", lazy = true },
```

The plugin spec itself loads on `cmd = { "TimeTracker", … }` and on the leader keymap.

---

## 4. File layout

```
lua/core/lazyload/plugins/timewarrior/
├── init.lua                 -- lazy spec + setup() entrypoint
├── config.lua               -- defaults (keys, tags, colors, paths)
├── cli.lua                  -- async timew wrappers (start/stop/track/...)
├── parse.lua                -- timew text → tables (timew @id parser, summary parser)
├── ui/
│   ├── palette.lua          -- "TimeTracker" command-list popup (NuiMenu)
│   ├── form.lua             -- Backdate / Description / Tag (NuiLayout + NuiPopup)
│   ├── report.lua           -- scratch buffer for day/week reports
│   └── echo.lua             -- floating notification line
└── statusline.lua           -- get_active() string for lualine
```

Tests live next to each file as `*_spec.lua` (plenary.busted). Skipped when `timew` isn't on `$PATH`.

---

## 5. Public API

```lua
local tw = require("core.timewarrior")

tw.setup({
  keymap = "<leader>tt",
  tags   = { "Research", "Personal", "Reading", "Learning", "Other", "Break" },
  colors = { Personal = "DiagnosticError", Other = "DiagnosticError" }, -- highlight-group names
})

tw.open()                   -- opens the palette
tw.start({ tags = {...} })  -- shortcut, no UI
tw.stop()                   -- shortcut, no UI
tw.report("day")            -- "day" | "yesterday" | "week"
tw.statusline()             -- string for lualine: " Research · 00:42"
```

`:TimeTracker` (no arg) = `tw.open()`.
`:TimeTracker {action}` for scriptable use (`start`, `stop`, `cancel`, …).

---

## 6. UI breakdown

### 6.1 Palette (`ui/palette.lua`)

Built with `NuiMenu`. Each entry `{key, label, action}`:

```
r  start
   start (custom input)
s  stop
c  cancel
   resume last entry
   resume
   add entry
   delete entry
a  add description
t  set tag
d  today report
   yesterday report
w  current week report
```

- Header text: `TimeTracker` (matches the screenshot's pill header).
- Live filter input on `/` (NuiInput) — narrows by label.
- Footer counter: `n / total`.
- Single-letter accelerators bound on the popup buffer (`r`, `s`, `c`, `a`, `t`, `d`, `w`).
- `<CR>` triggers selected action; `<Esc>` closes.

### 6.2 Form (`ui/form.lua`)

Three stacked `NuiPopup`s wrapped in a `NuiLayout`:

1. **Backdate** — single-line, parsed `from HH:MM to HH:MM`. Auto-fills:
   - From: round-down current time minus 1 h.
   - To: now.
2. **Description** — multi-line text, ~3 rows.
3. **Tag** — list with multi-select (`<Space>` toggles, j/k moves). Built-in tags from `config.tags`; user-typed tags accepted. Highlight group from `config.colors[tag]`.

Footer: `(⌘ ↩) Confirm    (Esc) Cancel` (use `<C-CR>` on linux).
On confirm: dispatches to `cli.start` or `cli.track` depending on context.

### 6.3 Report (`ui/report.lua`)

Open a vertical split scratch buffer (`buftype=nofile`, `bufhidden=wipe`).
Run `timew {summary|day|week}` async, pipe stdout into the buffer.
Filetype set to a small custom syntax (`timew_report`) for highlighting durations.
`q` closes the split.

### 6.4 Echo (`ui/echo.lua`)

A 3-line floating window anchored to bottom-right.
After every CLI call, parse the `INFO`/`Note:` lines from stderr+stdout and stream
them in (matches screenshot 3). Auto-fades after 4 seconds; appended to a session log
viewable via `:TimeTracker log`.

---

## 7. CLI wrapper (`cli.lua`)

All calls async via `plenary.job`. Never block the editor. Each helper returns a
plenary `Job` so the caller can chain `:after_success(...)`.

```lua
M.start(opts)        -- opts.tags? opts.description? opts.from?
M.stop()
M.cancel()
M.track(opts)        -- opts.from, opts.to, opts.tags, opts.description (REQUIRED both times)
M.annotate(id, text) -- timew annotate @id "text"
M.tag(id, tags)      -- timew tag @id ...
M.untag(id, tags)
M.delete(id)
M.summary(range)     -- "day" | "yesterday" | "week"
M.active()           -- timew get dom.active.* → table or nil
```

Notes:
- Always quote arguments — `timew` parses `to` keyword positionally, mishandled spaces break it.
- For `track`, format times as `YYYY-MM-DDTHH:MM:SS` (ISO-8601, like screenshot 3).
- All commands run from `$HOME` by default; configurable.

---

## 8. Statusline component

`statusline.lua` polls `cli.active()` once on `BufEnter`, then refreshes via
`vim.uv.new_timer` (60 s interval). Returns:

```
" Research · 00:42"          -- when running
""                              -- when idle
```

Drop-in for lualine:

```lua
sections = {
  lualine_x = { require("core.timewarrior.statusline").get },
}
```

---

## 9. Keymaps (defaults — overridable in `setup`)

| Key             | Action                          |
|-----------------|---------------------------------|
| `<leader>tt`    | open palette                    |
| `<leader>ts`    | start (last tags)               |
| `<leader>tS`    | stop                            |
| `<leader>tr`    | today report                    |
| `<leader>tw`    | week report                     |
| `<leader>ta`    | add entry (form)                |

Inside the palette: `r/s/c/a/t/d/w`, `j/k`, `/`, `<CR>`, `<Esc>`.
Inside the form: `<Tab>/<S-Tab>` between sections, `<C-CR>` confirm, `<Esc>` cancel,
`<Space>` toggles tag, `i` adds free-text tag.

---

## 10. Config defaults (`config.lua`)

```lua
return {
  keymap = "<leader>tt",
  cmd    = "timew",                      -- override for portable timew
  tags   = { "Research", "Personal", "Reading", "Learning", "Other", "Break" },
  colors = {                             -- highlight groups by tag name
    Personal = "DiagnosticError",
    Other    = "DiagnosticError",
  },
  popup = {
    width  = 0.55,                       -- ratio of editor width
    height = 0.50,
    border = "rounded",
  },
  echo = { duration = 4000, position = "bottomright" },
  statusline = { interval_ms = 60000, format = "%s · %s" },  -- tag · elapsed
}
```

---

## 11. Build order (suggested)

1. `cli.lua` + `parse.lua` (no UI). Verify `:lua print(vim.inspect(require("core.timewarrior.cli").active()))`.
2. `ui/palette.lua` — palette opens, accelerators trigger CLI helpers.
3. `ui/echo.lua` — wire CLI output to the floating echo.
4. `ui/form.lua` — Backdate/Description/Tag.
5. `ui/report.lua` — day/week reports.
6. `statusline.lua` + lualine wiring.
7. `:checkhealth` (`core.timewarrior.health`): verify `timew --version`, nui.nvim, plenary.

Each step ships independently; the palette already feels useful at step 2.

---

## 12. Risks / gotchas

- **`timew` interactive prompts** — `track` and a few destructive ops can prompt. Always pass `:yes` or use the `--yes` style if available; otherwise pipe `yes |`.
- **Locale-dependent date parsing** — coerce locale via `LC_TIME=C` when calling `timew` to keep parsing stable.
- **No JSON output for most reports** — `timew export` IS json (use that for parsed data); the textual `summary` is for humans only.
- **Empty database** — `timew` returns non-zero on some commands when no entries exist. Treat exit codes 0/1 as "non-fatal" and inspect output instead.
- **nui popups + Esc** — make sure to map `<Esc>` on every popup buffer; nui doesn't auto-close them.

---

## 13. Out of scope (could come later)

- Pomodoro mode (auto-stop after N minutes).
- Auto-tag from cwd / git remote.
- Plot week summary as a Unicode bar chart.
- Export today's tracked time straight into a journal note.

---

*Created: 2026-05-03. Update this file as the plugin lands.*
