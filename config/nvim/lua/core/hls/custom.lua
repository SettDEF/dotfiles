local C = require("core.hls.palette")

local colors = require("core.lib.colors")
local ct = require("core.lib.colors.contrast")
local fmtc = require("core.lib.colors.format").format_color
local darken = colors.darken
local lighten = colors.lighten
local hl = {}

-- The tinct palette frequently collapses roles onto identical hex values,
-- so we never trust a role pairing blindly:
--   safe_pair(bg, fg) -> { fg, bg } with fg corrected for AA contrast
--   accent(fg, bg)    -> fg corrected to read on bg, hue preserved
--   sep(base, color)  -> color nudged apart from base when they're identical
local safe_pair = ct.safe_pair
local function accent(fg, bg)
    return ct.accent_on(bg, fg, ct.AA_LARGE)
end
local sep = ct.separate

local editor_bg = fmtc(C.bg)

-- Shared elevated background for info sections / modes. separate() guarantees
-- it stays visually distinct from the editor bg even if lighten() is a no-op
-- (which happens when the palette's bg is already light).
local info_bg = sep(editor_bg, lighten(editor_bg, 0.08), 1.12)

-- The bottom panel: the statusline strip and the which-key panel above it share
-- one surface a step brighter than the buffer, so they read as one docked bar.
local panel_bg = sep(editor_bg, colors.blend("#ffffff", editor_bg, 0.05), 1.06)   -- 5% white over the buffer (colors.lighten() inverts its amount)
hl.WhichKeyNormal = { bg = panel_bg }
hl.WhichKeyTitle  = { bg = panel_bg, fg = fmtc(C.fg), bold = true }
-- the statusline takes panel_bg only while which-key is open (lazyload/plugins/ui)
vim.g.ii_panel_bg = panel_bg

-- ═══════════════════════════════════════════════════════════════════════
-- Statusline / Tabline / Heirline pills
-- ═══════════════════════════════════════════════════════════════════════
-- Layout: [mode | git] ══════ [tabs] ══════ [diagnostics | lsp | cursor]
-- Each pill segment gets its own tinted background from the tinct palette
-- so left/right sides read as colored strips, not a flat info-bg block.
--
-- Backgrounds use the EDITOR bg explicitly. bg = "NONE" does NOT show
-- Normal through — it falls through to the *terminal's* default bg
-- ($term0), which differs from nvim's `surface` editor bg, so the bar
-- rendered as a visibly different strip. Painting editor_bg makes the bar
-- seamless with the buffer, and pills still look like they float on it.

-- ── Base surfaces ──────────────────────────────────────────────────────
hl.CustomTablineFill  = { bg = editor_bg }
hl.CustomTabline      = { fg = fmtc(C.fg_inactive), bg = editor_bg } -- inactive tabs
hl.StatusLine         = { bg = editor_bg, fg = fmtc(C.fg_inactive) }
hl.StatusLineNC       = { bg = editor_bg, fg = fmtc(C.fg_inactive) }
hl.TabLine            = { bg = editor_bg, fg = fmtc(C.fg_inactive) }
hl.TabLineFill        = { bg = editor_bg }
hl.TabLineSel         = { bg = editor_bg, fg = fmtc(C.fg) }

-- ── Tab pills ──────────────────────────────────────────────────────────
hl.CustomTablineSel    = safe_pair(fmtc(C.primary_container), fmtc(C.bg))           -- active tab (tertiary_container was a loud yellow)
hl.CustomTablineNot    = safe_pair(fmtc(C.bg_highlight), fmtc(C.on_surface_variant)) -- inactive tab
hl.CustomTablineNumber = { fg = fmtc(C.fg), bold = true }
hl.CustomTablineLogo   = { fg = accent(fmtc(C.secondary), editor_bg), bg = editor_bg }

-- ── Segment-tint helper ────────────────────────────────────────────────
-- Nudges info_bg toward a semantic color just enough to make each pill
-- segment visually distinct while keeping the pill silhouette cohesive.
local function tint(anchor_bg, color_hex, amount)
    local blended = colors.blend(fmtc(color_hex), anchor_bg, amount or 0.18)
    return sep(anchor_bg, blended, 1.06) -- guarantee perceptible against baseline
end

-- Palette shorthand for git semantic colors — falls back to fixed hexes if
-- the running palette doesn't publish a git.* subtable (tinct fallback).
local G_ADD    = fmtc((C.git and C.git.add)     or "#8ec07c")
local G_CHANGE = fmtc((C.git and C.git.change)  or "#fabd2f")
local G_DELETE = fmtc((C.git and C.git.delete)  or "#fb4934")
local G_WARN   = fmtc((C.git and C.git.warning) or "#fabd2f")

-- ── Per-segment tinted backgrounds ─────────────────────────────────────
-- Palette roles: B0=primary orange/red, B1=primary-accent blue,
-- B2=insert-green, B3=tertiary, B4=secondary, C4=selection blue,
-- C5=terminal cyan, C6=cwd-purple.
--                                                      role       amount
local git_icon_bg     = tint(info_bg, fmtc(C.primary),       0.22)  -- primary
local git_branch_bg   = tint(info_bg, fmtc(C.surface_container_low),       0.18)  -- tertiary
local stash_bg        = tint(info_bg, fmtc(C.tertiary),       0.20)  -- cwd-purple
local diff_add_bg     = tint(info_bg, G_ADD,            0.20)
local diff_change_bg  = tint(info_bg, G_CHANGE,         0.20)
local diff_delete_bg  = tint(info_bg, G_DELETE,         0.20)
local lsp_icon_bg     = tint(info_bg, G_WARN,           0.20)
local lsp_active_bg   = tint(info_bg, G_ADD,            0.22)
local lsp_inactive_bg = tint(info_bg, G_DELETE,         0.22)
local cursor_bg       = tint(info_bg, fmtc(C.secondary),       0.24)  -- primary-accent

-- ── Left pill: git ─────────────────────────────────────────────────────
hl.CustomTablineGitIcon      = { fg = accent(fmtc(C.secondary),  git_icon_bg),     bg = git_icon_bg }
hl.CustomTablineGitBranch    = { fg = accent(fmtc(C.surface_container_highest),  git_branch_bg),   bg = git_branch_bg }
hl.CustomTablineGitStash     = { fg = accent(fmtc(C.tertiary),  stash_bg),        bg = stash_bg }
hl.CustomTablineDiffAdd      = { fg = accent(G_ADD,       diff_add_bg),     bg = diff_add_bg }
hl.CustomTablineDiffChange   = { fg = accent(G_CHANGE,    diff_change_bg),  bg = diff_change_bg }
hl.CustomTablineDiffDelete   = { fg = accent(G_DELETE,    diff_delete_bg),  bg = diff_delete_bg }

-- ── Center pill: tabs + modifiers ──────────────────────────────────────
hl.CustomTablineModifiedIcon = { fg = accent(fmtc(C.tertiary),  info_bg),         bg = info_bg }
hl.CustomTablineCwd          = { fg = accent(fmtc(C.surface_container_highest),  info_bg),         bg = info_bg }
hl.CustomTablineCwdIcon      = { fg = accent(fmtc(C.surface_container_low),  info_bg),         bg = info_bg }
hl.CustomTablinePillIcon     = { fg = accent(fmtc(C.tertiary),  info_bg),         bg = info_bg }
hl.CustomTablinePillIconSel  = { fg = accent(fmtc(C.secondary),  info_bg),         bg = info_bg }

-- ── Right pill: LSP + cursor ───────────────────────────────────────────
hl.CustomTablineLsp          = { fg = accent(fmtc(C.surface_container_low),  lsp_icon_bg),     bg = lsp_icon_bg }
hl.CustomTablineLspActive    = { fg = accent(G_ADD,       lsp_active_bg),   bg = lsp_active_bg }
hl.CustomTablineLspInactive  = { fg = accent(fmtc(C.error), lsp_inactive_bg), bg = lsp_inactive_bg }
hl.CustomTablineCursor       = { fg = accent(fmtc(C.surface_container_highest),  cursor_bg),       bg = cursor_bg }
hl.CustomTablineCursorIcon   = { fg = accent(fmtc(C.tertiary_container),  cursor_bg),       bg = cursor_bg }

-- Neovim logo cap on the left of the mode pill. We want the icon punchy,
-- so use a darker cap bg and a bright Neovim green with WCAG AA contrast
-- (4.5) to guarantee it stands out — plain accent() at AA_LARGE was too
-- close in luminance to read at small glyph size.
local nvim_logo_bg = colors.blend("#0f2a12", info_bg, 0.75) -- deep forest green
hl.CustomModeLogo = {
    fg = colors.ensure_contrast("#83e26e", nvim_logo_bg, ct.AA),
    bg = nvim_logo_bg,
    bold = true,
}

-- Mode indicators — one distinct fg per mode on the shared mode bg.
-- Each entry uses a hue-distinct palette role so the mode pill is
-- immediately recognizable at a glance. accent() enforces AA_LARGE
-- contrast against mode_bg so no mode ever collapses to invisible.
local mode_bg = editor_bg
hl.ModeNormal   = { fg = accent(fmtc(C.primary),          mode_bg), bg = mode_bg }
hl.ModeInsert   = { fg = accent(G_ADD,                    mode_bg), bg = mode_bg }
hl.ModeVisual   = { fg = accent(fmtc(C.tertiary),         mode_bg), bg = mode_bg }
hl.ModeReplace  = { fg = accent(fmtc(C.error),            mode_bg), bg = mode_bg }
hl.ModeCommand  = { fg = accent(G_WARN,                   mode_bg), bg = mode_bg }
hl.ModeOperator = { fg = accent(fmtc(C.secondary),        mode_bg), bg = mode_bg }
hl.ModePrompt   = { fg = accent(fmtc(C.secondary),        mode_bg), bg = mode_bg }
hl.ModeTerminal = { fg = accent(fmtc(C.tertiary_container), mode_bg), bg = mode_bg }
hl.MacroRecording = vim.tbl_extend("force", safe_pair(fmtc(C.error), fmtc(C.bg)), { bold = true })

-- === Incline.nvim ===
-- bg_highlight / bg_dark can collapse onto the editor bg; sep() keeps the
-- window-name chip distinguishable. fg is then corrected against that bg.
local incline_bg = sep(editor_bg, fmtc(C.bg_highlight), 1.15)
local incline_bg_nc = sep(editor_bg, fmtc(C.bg_dark), 1.08)
-- fg_inactive on the NC chip was near-invisible (dark-on-dark); guarantee a
-- dim-but-legible level against the chip's actual bg.
local incline_fg_nc = colors.ensure_contrast(fmtc(C.fg_inactive), incline_bg_nc, 3.0)
hl.InclineNormal = safe_pair(incline_bg, fmtc(C.fg))
hl.InclineNormalNC = { fg = incline_fg_nc, bg = incline_bg_nc }
hl.InclineFilename = safe_pair(incline_bg, fmtc(C.fg))
hl.InclineFilenameNC = { fg = incline_fg_nc, bg = incline_bg_nc }
local incline_mod_bg = darken(fmtc(C.outline_variant), 0.3)
hl.InclineModified = safe_pair(incline_mod_bg, fmtc(C.outline_variant))
hl.InclineModifiedNC = { fg = incline_fg_nc, bg = incline_bg_nc }
hl.InclineSep = { fg = incline_bg, bg = incline_bg_nc }

-- === Git diff colors ===
-- Semantic accents: corrected to read on the editor bg (signcolumn / tree row
-- share that background). accent() preserves the hue so green/yellow/red stay
-- recognizable even after the contrast nudge.
local git_add = accent(fmtc((C.git and C.git.add) or "#8ec07c"), editor_bg)
local git_change = accent(fmtc((C.git and C.git.change) or "#fabd2f"), editor_bg)
local git_delete = accent(fmtc((C.git and C.git.delete) or "#fb4934"), editor_bg)

-- Neo-tree git status
hl.NeoTreeGitAdded = { fg = git_add }
hl.NeoTreeGitUntracked = { fg = git_add }
hl.NeoTreeGitStaged = { fg = git_add }
hl.NeoTreeGitModified = { fg = git_change }
hl.NeoTreeGitUnstaged = { fg = git_change }
hl.NeoTreeGitRenamed = { fg = git_change }
hl.NeoTreeGitDeleted = { fg = git_delete }
hl.NeoTreeGitConflict = { fg = git_delete, bold = true }
hl.NeoTreeGitIgnored = { fg = fmtc(C.fg_inactive) }

-- Gitsigns — the palette's defaults are monochrome grays; use the corrected accents.
hl.GitSignsAdd = { fg = git_add }
hl.GitSignsChange = { fg = git_change }
hl.GitSignsDelete = { fg = git_delete }
hl.GitSignsTopdelete = { fg = git_delete }
hl.GitSignsChangedelete = { fg = git_change }
hl.GitSignsUntracked = { fg = git_add }

-- === Comments ===
-- the palette sets Comment to fg_dark (the A3 role), which tinct routinely
-- collapses onto a near-bg value (ratio ~1.1 = invisible). Correct it to a
-- dim-but-legible level: ratio 3.0 keeps comments de-emphasized vs. code
-- while staying readable. @comment links to Comment so this covers treesitter.
local comment_fg = colors.ensure_contrast(fmtc(C.fg_dark), editor_bg, ct.AA_LARGE)
hl.Comment = { fg = comment_fg, italic = true }
hl["@comment"] = { fg = comment_fg, italic = true }
-- Semantic comment variants — keep their hue, guarantee they read.
hl["@comment.hint"] = { fg = accent(fmtc(C.surface_container_high), editor_bg) }
hl["@comment.info"] = { fg = accent(fmtc(C.tertiary), editor_bg) }
hl["@comment.warning"] = { fg = accent(fmtc(C.tertiary_container), editor_bg) }

-- === Variables / identifiers / inlay hints ===
-- the palette.nvim maps @variable, @lsp.type.variable, Identifier to A5
-- (#3d322f on this palette — a border/outline tone) and LspInlayHint
-- to A3 (#322825 — visual bg). Against editor bg #231815 those land
-- at contrast ratios ~1.7 and ~1.3, well under WCAG AA; identifier
-- names and inlay-hint type boxes become invisible.
-- Force identifiers to the regular fg (A4), and inlay hints to a
-- contrast-guaranteed dim level (same treatment as Comment above).
local identifier_fg = fmtc(C.fg)
hl["@variable"] = { fg = identifier_fg }
hl["@variable.parameter"] = { fg = identifier_fg }
hl["@variable.member"] = { fg = identifier_fg }
hl["@lsp.type.variable"] = { fg = identifier_fg }
hl["@lsp.type.parameter"] = { fg = identifier_fg }
hl.Identifier = { fg = identifier_fg }

local inlay_fg = colors.ensure_contrast(fmtc(C.fg_dark), editor_bg, ct.AA_LARGE)
hl.LspInlayHint = { fg = inlay_fg, bg = "NONE" }
hl.InlayHint = { fg = inlay_fg, bg = "NONE" }

-- Property / field names — QML buffers are 90% `property foo:` lines and
-- member accesses, and the palette leaves @property on a dim near-bg tone.
-- Same treatment as variables: the regular readable fg.
hl["@property"] = { fg = identifier_fg }
hl["@field"] = { fg = identifier_fg }
hl["@variable.other.member"] = { fg = identifier_fg }
hl["@lsp.type.property"] = { fg = identifier_fg }

-- === Operators, builtins, types ===
-- the palette picks B3 (surface_container_low, e.g. #231917) for Operator and
-- @variable.builtin — that's a background tint, so `=`, `*`, `:`, `self`,
-- `Self` vanish. It also picks C4 (tertiary_container, e.g. #1d424e dark
-- teal) for Type / @type, giving ratio ~1.5:1 against bg — type names like
-- `Lanes`, `f32` go nearly invisible. Force these to legible accents.
local operator_fg = accent(fmtc(C.tertiary), editor_bg) -- sky/cyan accent, hue preserved
local type_fg = accent(fmtc(C.tertiary), editor_bg) -- info/cyan accent, distinct from variables
local builtin_fg = accent(fmtc(C.primary), editor_bg) -- primary accent for `self`

hl.Operator = { fg = operator_fg }
hl["@operator"] = { fg = operator_fg }
hl["@variable.builtin"] = { fg = builtin_fg, italic = true }
hl.Type = { fg = type_fg }
hl["@type"] = { fg = type_fg }
hl["@type.builtin"] = { fg = type_fg, bold = true }
hl["@lsp.type.builtinType"] = { fg = type_fg, bold = true }
hl["@lsp.type.selfKeyword"] = { fg = builtin_fg, italic = true }
hl["@lsp.type.selfTypeKeyword"] = { fg = builtin_fg, italic = true }

-- === Preprocessing & Includes (imports, requires) ===
-- the palette maps PreProc and related to colors.C9 (#1f201f), which is a background
-- tone. This makes `import` statements virtually invisible. Override to bright blue.
-- C11 is the tertiary role — identical to the Type color (C6), so `import`
-- lines and type names were indistinguishable. Primary matches the keyword
-- family, which is what imports are.
local preproc_fg = accent(fmtc(C.primary), editor_bg)
hl.PreProc = { fg = preproc_fg, italic = true }
hl.Include = { fg = preproc_fg }
hl.Define = { fg = preproc_fg }
hl.Macro = { fg = preproc_fg }
hl.PreCondit = { fg = preproc_fg }
hl["@keyword.import"] = { fg = preproc_fg, bold = true }
hl["@keyword.directive"] = { fg = preproc_fg }
hl["@keyword.directive.define"] = { fg = preproc_fg }

-- === Strings & Characters ===
-- the palette maps String to C3 (#3a4a45) which is a very dark green. Override
-- to contrast-ensured bright green/teal.
local string_fg = accent(fmtc(C.secondary), editor_bg)
hl.String = { fg = string_fg }
hl.Character = { fg = string_fg }
hl["@string"] = { fg = string_fg }

-- === Booleans ===
-- the palette maps Boolean to colors.B3 (#1b1c1b), making true/false invisible.
-- Map to bright cyan/accent.
local boolean_fg = accent(fmtc(C.primary), editor_bg)
hl.Boolean = { fg = boolean_fg, bold = true }
hl["@boolean"] = { fg = boolean_fg, bold = true }

-- === Delimiters & Specials ===
-- the palette maps Special and Delimiter to B3 (almost black). Force to readable
-- outline gray and accent tones.
local special_fg = accent(fmtc(C.primary), editor_bg)
-- 3.0 proved too dim in practice (dots in `qs.modules.common` vanished) — 4.0
-- keeps punctuation quieter than identifiers but actually visible.
local delimiter_fg = colors.ensure_contrast(fmtc(C.outline_variant), editor_bg, 4.0)
hl.Special = { fg = special_fg }
hl.SpecialChar = { fg = special_fg }
hl.Delimiter = { fg = delimiter_fg }
hl["@punctuation.delimiter"] = { fg = delimiter_fg }
hl["@punctuation.bracket"] = { fg = delimiter_fg }

-- === Line numbers ===
-- Relative numbers stay dim but guaranteed legible; the current line number
-- gets the primary accent so it pops for relative jumps.
hl.LineNr = { fg = colors.ensure_contrast(fmtc(C.fg_dark), editor_bg, 3.0) }
hl.LineNrAbove = { link = "LineNr" }
hl.LineNrBelow = { link = "LineNr" }
hl.CursorLineNr = { fg = accent(fmtc(C.primary), editor_bg), bold = true }

-- === Todo ===
-- the palette maps Todo to B3. Override to warning accent.
hl.Todo = { fg = accent(fmtc(C.tertiary_container), editor_bg), bg = info_bg, bold = true }

-- ============================================================================
-- IDE plugin theming — DAP UI, neotest, nvim-notify, conform status pills.
-- All colors are derived from the the palette palette so they retrack with tinct.
-- Each surface uses the shared visibility helpers (accent / safe_pair / sep)
-- so nothing can silently collapse when the palette rotates.
-- ============================================================================

-- Reused semantic colors from the palette, with tinct-collapse fallbacks.
local sem_error = fmtc((C.git and C.git.delete) or C.error or "#fb4934")
local sem_warn = fmtc((C.git and C.git.warning) or C.warn or "#fabd2f")
local sem_info = fmtc(C.info or C.tertiary or "#7aa2f7")
local sem_hint = fmtc(C.hint or C.secondary or "#b57edc")
local sem_ok = fmtc((C.git and C.git.add) or C.secondary or "#8ec07c")

-- === DAP breakpoint / stopped signs ===
hl.DapBreakpoint = { fg = accent(sem_error, editor_bg) }
hl.DapBreakpointCondition = { fg = accent(sem_warn, editor_bg) }
hl.DapBreakpointRejected = { fg = accent(fmtc(C.fg_inactive), editor_bg) }
hl.DapLogPoint = { fg = accent(sem_info, editor_bg) }
hl.DapStopped = { fg = accent(sem_ok, editor_bg), bold = true }
hl.DapStoppedLine = { bg = colors.blend(sem_ok, editor_bg, 0.12) }

-- === DAP UI (rcarriga/nvim-dap-ui) ===
local dap_bg = sep(editor_bg, colors.blend(sem_info, editor_bg, 0.08), 1.10)
hl.DapUINormal = { bg = dap_bg }
hl.DapUIFloatBorder = { fg = accent(sem_info, dap_bg), bg = dap_bg }
hl.DapUIScope = { fg = accent(sem_info, dap_bg), bg = dap_bg, bold = true }
hl.DapUIType = { fg = accent(sem_hint, dap_bg), bg = dap_bg }
hl.DapUIValue = { fg = accent(fmtc(C.fg), dap_bg), bg = dap_bg }
hl.DapUIVariable = { fg = accent(fmtc(C.on_surface or C.fg), dap_bg), bg = dap_bg }
hl.DapUIModifiedValue = { fg = accent(sem_warn, dap_bg), bg = dap_bg, bold = true }
hl.DapUIDecoration = { fg = accent(sem_info, dap_bg), bg = dap_bg }
hl.DapUIThread = { fg = accent(sem_ok, dap_bg), bg = dap_bg }
hl.DapUIStoppedThread = { fg = accent(sem_warn, dap_bg), bg = dap_bg }
hl.DapUIFrameName = { fg = accent(fmtc(C.fg), dap_bg), bg = dap_bg }
hl.DapUISource = { fg = accent(sem_hint, dap_bg), bg = dap_bg }
hl.DapUILineNumber = { fg = accent(sem_info, dap_bg), bg = dap_bg }
hl.DapUIBreakpointsPath = { fg = accent(sem_info, dap_bg), bg = dap_bg }
hl.DapUIBreakpointsLine = { fg = accent(sem_info, dap_bg), bg = dap_bg, bold = true }
hl.DapUIBreakpointsInfo = { fg = accent(sem_ok, dap_bg), bg = dap_bg }
hl.DapUIBreakpointsCurrentLine = { fg = accent(sem_warn, dap_bg), bg = dap_bg, bold = true }
hl.DapUIBreakpointsDisabledLine = { fg = accent(fmtc(C.fg_inactive), dap_bg), bg = dap_bg }
hl.DapUIWatchesEmpty = { fg = accent(sem_error, dap_bg), bg = dap_bg }
hl.DapUIWatchesValue = { fg = accent(sem_ok, dap_bg), bg = dap_bg }
hl.DapUIWatchesError = { fg = accent(sem_error, dap_bg), bg = dap_bg }
-- Playback controls in the REPL toolbar.
hl.DapUIPlayPause = { fg = accent(sem_ok, dap_bg), bg = dap_bg }
hl.DapUIRestart = { fg = accent(sem_info, dap_bg), bg = dap_bg }
hl.DapUIStop = { fg = accent(sem_error, dap_bg), bg = dap_bg }
hl.DapUIStepOver = { fg = accent(sem_info, dap_bg), bg = dap_bg }
hl.DapUIStepInto = { fg = accent(sem_info, dap_bg), bg = dap_bg }
hl.DapUIStepOut = { fg = accent(sem_info, dap_bg), bg = dap_bg }
hl.DapUIStepBack = { fg = accent(sem_info, dap_bg), bg = dap_bg }
hl.DapUIUnavailable = { fg = accent(fmtc(C.fg_inactive), dap_bg), bg = dap_bg }

-- === neotest ===
hl.NeotestAdapterName = { fg = accent(sem_hint, editor_bg), bold = true }
hl.NeotestBorder = { fg = accent(sem_info, editor_bg) }
hl.NeotestDir = { fg = accent(sem_info, editor_bg) }
hl.NeotestFile = { fg = accent(fmtc(C.fg), editor_bg) }
hl.NeotestNamespace = { fg = accent(sem_hint, editor_bg) }
hl.NeotestTest = { fg = accent(fmtc(C.fg), editor_bg) }
hl.NeotestPassed = { fg = accent(sem_ok, editor_bg) }
hl.NeotestFailed = { fg = accent(sem_error, editor_bg), bold = true }
hl.NeotestRunning = { fg = accent(sem_warn, editor_bg) }
hl.NeotestSkipped = { fg = accent(fmtc(C.fg_inactive), editor_bg), italic = true }
hl.NeotestFocused = { bg = colors.blend(sem_info, editor_bg, 0.15), bold = true }
hl.NeotestExpandMarker = { fg = accent(fmtc(C.fg_inactive), editor_bg) }
hl.NeotestIndent = { fg = accent(fmtc(C.fg_inactive), editor_bg) }
hl.NeotestMarked = { fg = accent(sem_warn, editor_bg), bold = true }
hl.NeotestTarget = { fg = accent(sem_info, editor_bg) }
hl.NeotestUnknown = { fg = accent(fmtc(C.fg_inactive), editor_bg) }
hl.NeotestWinSelect = { fg = accent(sem_info, editor_bg) }

-- === nvim-notify ===
-- Give each severity its own border/icon/title with contrast-safe fg.
for level, sem in pairs({
    ERROR = sem_error,
    WARN = sem_warn,
    INFO = sem_info,
    DEBUG = sem_hint,
    TRACE = sem_hint,
}) do
    local body_bg = sep(editor_bg, colors.blend(sem, editor_bg, 0.08), 1.10)
    hl["Notify" .. level .. "Border"] = { fg = accent(sem, body_bg), bg = body_bg }
    hl["Notify" .. level .. "Icon"] = { fg = accent(sem, body_bg), bg = body_bg, bold = true }
    hl["Notify" .. level .. "Title"] = { fg = accent(sem, body_bg), bg = body_bg, bold = true }
    hl["Notify" .. level .. "Body"] = { fg = accent(fmtc(C.fg), body_bg), bg = body_bg }
end

-- === nvim-lint virtual-text-severity floats (fallbacks — LSP already covers most) ===
hl.LintError = { fg = accent(sem_error, editor_bg) }
hl.LintWarn = { fg = accent(sem_warn, editor_bg) }
hl.LintInfo = { fg = accent(sem_info, editor_bg) }
hl.LintHint = { fg = accent(sem_hint, editor_bg) }

-- === conform.nvim status buffer border (used by :ConformInfo) ===
hl.ConformProgress = { fg = accent(sem_info, editor_bg), bold = true }

-- === External (Claude) edits: persistent added / removed markers ===
hl.AiChangeAdd = { bg = colors.blend(git_add, editor_bg, 0.14) }
hl.AiChangeAddNr = { fg = git_add, bold = true }
hl.AiChangeDel = {
    fg = colors.ensure_contrast(colors.blend(git_delete, editor_bg, 0.85), editor_bg, ct.AA_LARGE),
    bg = colors.blend(git_delete, editor_bg, 0.12),
    italic = true,
}

-- === Transparent mode: side panels must match the editor, not the palette ===
-- With transparent bg the editor shows the terminal colour, so any panel painted
-- with a solid palette bg reads as a tinted rectangle next to it.
if vim.api.nvim_get_hl(0, { name = "Normal" }).bg == nil then
    for _, g in ipairs({
        "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeEndOfBuffer",
        "NeoTreeWinSeparator", "NeoTreeVertSplit", "EdgyNormal", "EdgyWinBar", "EdgyTitle",
    }) do
        local cur = vim.api.nvim_get_hl(0, { name = g, link = false })
        cur.bg = nil
        cur.ctermbg = nil
        cur.force = nil
        hl[g] = cur
    end
    -- Same for the statusline/tabline surfaces: painted editor_bg they showed
    -- the palette's brown as a strip beside the pills (the centring padding),
    -- while the %= fill fell through to the terminal. Anything that is plain
    -- editor_bg here becomes see-through; tinted pills keep their colour.
    for _, v in pairs(hl) do
        if type(v) == "table" and v.bg == editor_bg then v.bg = nil end
    end
end

return { hl = hl }
