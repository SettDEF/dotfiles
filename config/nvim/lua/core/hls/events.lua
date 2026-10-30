-- Re-apply our custom highlights whenever the colorscheme changes, so theme
-- swaps / tinct-driven palette refreshes don't clobber statusline/tabline
-- transparency and other overrides.
local group = vim.api.nvim_create_augroup("CoreHighlightsReapply", { clear = true })

local function strip_statusline_bg()
    -- Copy Normal.bg so the statusline/tabline row matches the editor area.
    -- Using "NONE" would expose the terminal bg through — which visibly
    -- differs from Normal.bg when the colorscheme (tinct) tints the editor.
    local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
    local bg = normal and normal.bg and string.format("#%06x", normal.bg) or "NONE"

    for _, g in ipairs({
        "StatusLine",
        "StatusLineNC",
        "TabLine",
        "TabLineFill",
        "TabLineSel",
        "WinBar",
        "WinBarNC",
        "CustomTabline",
        "CustomTablineFill",
        "CustomTablineLogo",
    }) do
        pcall(vim.cmd, string.format("highlight %s guibg=%s ctermbg=NONE", g, bg))
    end
    -- The core/colors module caches nvim_get_hl results until ColorScheme.
    -- Statusline components closed over the OLD cached bg, so heirline's
    -- generated Stl_* groups still draw the old palette bg. Reset the
    -- cache and force heirline to regenerate.
    local ok_c, colors = pcall(require, "core.lib.colors")
    if ok_c and colors.hl and colors.hl.reset then
        pcall(colors.hl.reset)
    end
    local ok_h, heirline = pcall(require, "heirline")
    if ok_h and heirline.reset_highlights then
        pcall(heirline.reset_highlights)
    end
    pcall(vim.cmd, "redrawstatus!")
    pcall(vim.cmd, "redrawtabline")
end

local function reapply()
    require("core.hls").load()
    strip_statusline_bg()
end

vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
        vim.schedule(reapply)
    end,
})

-- tinct re-applies its groups on a palette reload (SIGUSR1 / file watch)
-- WITHOUT firing ColorScheme, so subscribe directly. Subscribe on the module
-- instance that owns the watcher: tinct wipes its own package.loaded entry
-- on reload, so a later require() would register on a dead instance.
local ok_t, tinct = pcall(require, "tinct")
if ok_t and type(tinct.subscribe) == "function" then
    tinct.subscribe(function()
        vim.schedule(reapply)
    end)
end

-- Also strip after lazy finishes loading plugins, in case a theme plugin
-- applies its highlights after the initial ColorScheme event.
vim.api.nvim_create_autocmd("User", {
    pattern = "LazyDone",
    group = group,
    callback = function()
        vim.schedule(strip_statusline_bg)
    end,
})

-- And once at module-load time, defensively.
vim.schedule(strip_statusline_bg)
