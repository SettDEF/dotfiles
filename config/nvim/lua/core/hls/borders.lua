-- Popup borders that belong to their popup.
--
-- Measured before this existed: floats were #211f21 on a transparent editor,
-- FloatBorder a fixed #4a454d unrelated to that box, and plugins with their
-- own panel colours (telescope, noice, which-key…) drew borders from yet
-- another role. The edge of every popup looked pasted on.
--
-- Rule: a border is the popup's OWN background, lifted a little toward its
-- own text colour, and its cells are painted with that background, so the
-- rounded corners carry no halo. Computed at apply time from whatever each
-- panel currently uses, so it holds for every theme tinct produces.
local format = require("core.lib.colors.format")

local M = {}

local LIFT = 0.20

-- border group → the Normal group whose box it outlines
local PAIRS = {
    FloatBorder = "NormalFloat",
    FloatTitle = "NormalFloat",
    TelescopeBorder = "TelescopeNormal",
    TelescopePromptBorder = "TelescopePromptNormal",
    TelescopeResultsBorder = "TelescopeResultsNormal",
    TelescopePreviewBorder = "TelescopePreviewNormal",
    NoiceCmdlinePopupBorder = "NoiceCmdlinePopup",
    NoicePopupBorder = "NoicePopup",
    NoicePopupmenuBorder = "NoicePopupmenu",
    NoiceConfirmBorder = "NoiceConfirm",
    WhichKeyBorder = "WhichKeyNormal",
    LazyBorder = "LazyNormal",
    MasonBorder = "MasonNormal",
    CmpBorder = "Pmenu",
    BlinkCmpMenuBorder = "BlinkCmpMenu",
    BlinkCmpDocBorder = "BlinkCmpDoc",
    BlinkCmpSignatureHelpBorder = "BlinkCmpSignatureHelp",
    DressingBorder = "NormalFloat",
    LspInfoBorder = "NormalFloat",
}

local function hex(n) return n and string.format("#%06x", n) or nil end

local function box(name)
    local h = vim.api.nvim_get_hl(0, { name = name, link = false })
    local f = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false })
    local n = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    return hex(h.bg) or hex(f.bg) or hex(n.bg), hex(h.fg) or hex(f.fg) or hex(n.fg)
end

function M.apply()
    for border, normal in pairs(PAIRS) do
        local bg, fg = box(normal)
        if bg and fg then
            local spec = { fg = format.blend(fg, bg, LIFT), bg = bg }
            if border == "FloatTitle" then spec = { fg = fg, bg = bg, bold = true } end
            vim.api.nvim_set_hl(0, border, spec)
        end
    end
end

return M
