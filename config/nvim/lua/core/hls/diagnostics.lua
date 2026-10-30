-- Diagnostic highlight groups, styled from the live tinct palette.
--
-- Each severity gets a fg accent + a tinted bg (darker version of the
-- editor bg biased toward the severity color) so both virtual-text and
-- signcolumn read cleanly against any wallpaper-derived palette.

local CC = require("core.lib.colors")
local P = require("core.hls.palette")

-- Blend factor for the severity color into the editor bg.
-- Lower = more saturated tint (more visible).
local TINT_TEXT_ERROR = 0.9
local TINT_TEXT       = 0.95
local TINT_UNDERLINE  = 0.8

local function tint(severity_fg, amount)
    return CC.darken(P.background, amount, severity_fg)
end

local SEVERITIES = {
    { level = "Error", fg = P.error, tint = TINT_TEXT_ERROR, bold = true, blend = 20 },
    { level = "Warn",  fg = P.warn,  tint = TINT_TEXT },
    { level = "Info",  fg = P.info,  tint = TINT_TEXT },
    { level = "Hint",  fg = P.hint,  tint = TINT_TEXT },
}

local hl = {}
for _, s in ipairs(SEVERITIES) do
    hl["Diagnostic" .. s.level] = {
        fg = s.fg,
        bg = tint(s.fg, s.tint),
        bold = s.bold,
        blend = s.blend,
    }
    hl["DiagnosticUnderline" .. s.level] = {
        undercurl = true,
        sp = s.fg,
        bg = tint(s.fg, TINT_UNDERLINE),
    }
end

return { hl = hl }
