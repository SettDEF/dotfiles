local M = {}

--- Converts a hex color string "#RRGGBB" to an RGB table with values 0–255.
-- @param hex string: Color in hex format (with or without leading #)
-- @return table: { r, g, b } where each component is an integer 0–255
function M.hex_to_rgb(hex)
    hex = hex:gsub("#", "")
    assert(#hex == 6, "hex_to_rgb: invalid hex string length")
    return {
        tonumber(hex:sub(1, 2), 16), -- Red
        tonumber(hex:sub(3, 4), 16), -- Green
        tonumber(hex:sub(5, 6), 16), -- Blue
    }
end

--- Ensures a color is returned as a lowercase hex string.
-- Accepts both string hex colors and Neovim highlight numbers.
-- @param color string|number: The input color
-- @return string: Lowercase "#rrggbb" hex string
function M.format_color(color)
    if type(color) == "string" then
        return color:lower():match("^#") and color:lower() or color
    elseif type(color) == "number" then
        return string.format("#%06x", color)
    end
end

--- Blends two colors together using alpha (0.0 – 1.0).
-- 0.0 = fully background, 1.0 = fully foreground.
-- @param fg string|number: Foreground color (blended on top)
-- @param bg string|number: Background color
-- @param alpha number: Blend amount (clamped to 0–1)
-- @return string: Resulting hex color
function M.blend(fg, bg, alpha)
    fg = M.format_color(fg)
    bg = M.format_color(bg)
    alpha = math.max(0, math.min(1, alpha))

    local fg_rgb = M.hex_to_rgb(fg)
    local bg_rgb = M.hex_to_rgb(bg)

    local function blend_channel(f, b)
        return math.floor(alpha * f + (1 - alpha) * b + 0.5)
    end

    return string.format(
        "#%02x%02x%02x",
        blend_channel(fg_rgb[1], bg_rgb[1]),
        blend_channel(fg_rgb[2], bg_rgb[2]),
        blend_channel(fg_rgb[3], bg_rgb[3])
    )
end

--- Darkens a color by blending it toward black.
-- Higher amount = darker.
-- @param hex string|number: Base color
-- @param amount number: 0.0 (no change) to 1.0 (fully black)
-- @return string: Darkened hex color
function M.darken(hex, amount)
    hex = M.format_color(hex)
    amount = math.max(0, math.min(1, amount))
    -- Blend black on top of the color
    return M.blend("#000000", hex, amount)
end

--- Lightens a color by blending it toward white.
-- Higher amount = lighter.
-- @param hex string|number: Base color
-- @param amount number: 0.0 (no change) to 1.0 (fully white)
-- @return string: Lightened hex color
function M.lighten(hex, amount)
    hex = M.format_color(hex)
    amount = math.max(0, math.min(1, amount))
    -- Blend white on top of the color
    return M.blend("#ffffff", hex, amount)
end

--- Calculates relative luminance of an sRGB color (WCAG standard).
local function luminance(r, g, b)
    local function srgb_to_linear(c)
        c = c / 255
        return c <= 0.04045 and (c / 12.92) or ((c + 0.055) / 1.055) ^ 2.4
    end
    r, g, b = srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

local function relative_luminance(hex)
    local rgb = M.hex_to_rgb(hex)
    return luminance(rgb[1], rgb[2], rgb[3])
end

--- WCAG contrast ratio between two colors. Range 1 (identical) to 21 (black/white).
-- @param a string|number
-- @param b string|number
-- @return number
function M.contrast_ratio(a, b)
    local la = relative_luminance(M.format_color(a))
    local lb = relative_luminance(M.format_color(b))
    local lighter, darker = math.max(la, lb), math.min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)
end

--- Adjusts `fg` so that it has at least `min_ratio` WCAG contrast against `bg`.
-- Hue is preserved as much as possible: fg is blended with whichever of black or
-- white moves it away from bg's luminance, only as far as needed (binary search).
-- Useful for icon foregrounds whose natural color collides with a pill bg.
-- @param fg string|number
-- @param bg string|number
-- @param min_ratio number? default 4.5 (WCAG AA for normal text)
-- @return string
function M.ensure_contrast(fg, bg, min_ratio)
    fg = M.format_color(fg)
    bg = M.format_color(bg)
    min_ratio = min_ratio or 4.5
    if M.contrast_ratio(fg, bg) >= min_ratio then
        return fg
    end

    -- Try both directions (toward black and toward white) and pick whichever
    -- reaches the threshold first; if neither can, pick the one with the
    -- highest achievable contrast. Mid-gray backgrounds need this — pushing
    -- toward only one extreme can never cross 4.5.
    local function search(target)
        local lo, hi, best = 0, 1, M.blend(target, fg, 1)
        for _ = 1, 14 do
            local mid = (lo + hi) / 2
            local candidate = M.blend(target, fg, mid)
            if M.contrast_ratio(candidate, bg) >= min_ratio then
                best = candidate
                hi = mid
            else
                lo = mid
            end
        end
        return best
    end

    local toward_black = search("#000000")
    local toward_white = search("#ffffff")
    local rb = M.contrast_ratio(toward_black, bg)
    local rw = M.contrast_ratio(toward_white, bg)

    -- Prefer whichever crosses the threshold; among those that do, prefer the
    -- one with smaller hue shift (closer to the original luminance side).
    local black_ok = rb >= min_ratio
    local white_ok = rw >= min_ratio
    if black_ok and white_ok then
        return relative_luminance(fg) < 0.5 and toward_black or toward_white
    elseif black_ok then
        return toward_black
    elseif white_ok then
        return toward_white
    end
    return rb > rw and toward_black or toward_white
end

--- Returns the best contrasting foreground (black or white) for a background.
-- Uses standard WCAG relative luminance – reliable and widely accepted.
-- @param background string|number: Background color
-- @return string: "#000000" (black) or "#ffffff" (white)
function M.contrast_foreground(background)
    background = M.format_color(background)
    local rgb = M.hex_to_rgb(background)
    local l = luminance(rgb[1], rgb[2], rgb[3])
    -- Threshold around 0.5 gives good results; WCAG uses sqrt(1.05 * 0.05) ≈ 0.179 but 0.5 is common for black/white
    return l > 0.5 and "#000000" or "#ffffff"
end

return M
