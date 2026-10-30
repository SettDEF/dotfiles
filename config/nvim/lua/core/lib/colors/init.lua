local U = require("core.lib.utils")
local format = require("core.lib.colors.format") -- pure functions

local M = {}

--  Defaults from Normal highlight
local function normal_colors()
    local n = vim.api.nvim_get_hl(0, { name = "Normal" })
    M.bg = n.bg and string.format("#%06x", n.bg) or "#010101"
    M.fg = n.fg and string.format("#%06x", n.fg) or "#FEFEFE"
end
normal_colors()

--  Cached highlight lookup
local cache = U.CachedDict:new(function(key)
    return vim.api.nvim_get_hl(0, { name = key, link = false })
end)

vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
        cache:reset()
        normal_colors()
    end,
})

M.hl = cache

--  Palette (identical to original)
function M.palette()
    local raw = { lost = "#300303" }
    local out = {}
    for name, col in pairs(raw) do
        if type(col) == "table" then
            for sub, subcol in pairs(col) do
                out[sub] = subcol
            end
        else
            out[name] = col
        end
    end
    return out
end

--  Re-export **every** public function from format.lua
for k, v in pairs(format) do
    M[k] = v
end

--  Re-export the high-level visibility helpers (readable_on, pick_readable,
--  separate, accent_on, safe_pair, auto_fg, plus the AA/AAA constants).
local contrast = require("core.lib.colors.contrast")
for k, v in pairs(contrast) do
    M[k] = v
end

--  Override darken / lighten so they use the *real* M.bg / M.fg
-- Darken a color by blending it with black (or a provided background color)
-- @param hex string: The original color in hex format
-- @param amount number: Blend factor (0 to 1)
-- @param bg string (optional): Background color to blend with (defaults to black)
-- @return string: The darkened color
M.darken = function(hex, amount, bg)
    return M.blend(hex, bg or M.bg, math.abs(amount))
end

-- Lighten a color by blending it with white (or a provided foreground color)
-- @param hex string: The original color in hex format
-- @param amount number: Blend factor (0 to 1)
-- @param fg string (optional): Foreground color to blend with (defaults to M.fg, white)
-- @return string: The lightened color
M.lighten = function(hex, amount, fg)
    return M.blend(hex, fg or M.fg, math.abs(amount))
end

return M
