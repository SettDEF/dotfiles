-- core.utils.contrast — WCAG contrast helpers for tinct-derived palettes.
--
-- Why: the tinct palette tracks the wallpaper. On some wallpapers the
-- generated `on_surface` / `primary` / etc. can land at borderline contrast
-- against the surface — readable in some, not in others. This module
-- enforces a minimum contrast ratio at theme-apply time by nudging HSL
-- lightness until the ratio clears.
--
-- WCAG 2.1 minimums used:
--   * 4.5  — normal body text
--   * 3.0  — large text, accents, syntax keywords (perceptual not strict)
--   * 7.0  — AAA for the principal text colour
-- Caller chooses per role.

local M = {}

-- ── Conversion helpers ─────────────────────────────────────────────────────
local function hex_to_rgb(hex)
    if not hex then
        return 0, 0, 0
    end
    hex = hex:gsub("#", "")
    if #hex < 6 then
        return 0, 0, 0
    end
    return tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255
end

local function clamp01(v)
    return math.min(1, math.max(0, v))
end

local function rgb_to_hex(r, g, b)
    return string.format(
        "#%02x%02x%02x",
        math.floor(clamp01(r) * 255 + 0.5),
        math.floor(clamp01(g) * 255 + 0.5),
        math.floor(clamp01(b) * 255 + 0.5)
    )
end

-- sRGB → linear (gamma decode) per WCAG.
local function srgb_to_linear(c)
    if c <= 0.04045 then
        return c / 12.92
    end
    return ((c + 0.055) / 1.055) ^ 2.4
end

function M.luminance(hex)
    local r, g, b = hex_to_rgb(hex)
    return 0.2126 * srgb_to_linear(r) + 0.7152 * srgb_to_linear(g) + 0.0722 * srgb_to_linear(b)
end

function M.contrast_ratio(fg, bg)
    local lf = M.luminance(fg)
    local lb = M.luminance(bg)
    local hi, lo = math.max(lf, lb), math.min(lf, lb)
    return (hi + 0.05) / (lo + 0.05)
end

-- ── HSL (keep hue, nudge lightness) ────────────────────────────────────────
local function rgb_to_hsl(r, g, b)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local h, s, l = 0, 0, (mx + mn) / 2
    if mx ~= mn then
        local d = mx - mn
        s = (l > 0.5) and (d / (2 - mx - mn)) or (d / (mx + mn))
        if mx == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif mx == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
    end
    return h, s, l
end

local function hue_to_rgb(p, q, t)
    if t < 0 then
        t = t + 1
    end
    if t > 1 then
        t = t - 1
    end
    if t < 1 / 6 then
        return p + (q - p) * 6 * t
    end
    if t < 1 / 2 then
        return q
    end
    if t < 2 / 3 then
        return p + (q - p) * (2 / 3 - t) * 6
    end
    return p
end

local function hsl_to_rgb(h, s, l)
    if s == 0 then
        return l, l, l
    end
    local q = (l < 0.5) and (l * (1 + s)) or (l + s - l * s)
    local p = 2 * l - q
    return hue_to_rgb(p, q, h + 1 / 3), hue_to_rgb(p, q, h), hue_to_rgb(p, q, h - 1 / 3)
end

-- Push `fg` toward white or black (whichever direction increases contrast
-- against `bg`) in 3 % lightness steps until ratio >= min_ratio. Hue and
-- saturation are preserved so the colour identity stays recognizable.
-- Returns the fixed hex; if even pure white/black don't satisfy, returns
-- the appropriate extreme.
function M.ensure_contrast(fg, bg, min_ratio)
    if not fg or not bg then
        return fg
    end
    min_ratio = min_ratio or 4.5
    if M.contrast_ratio(fg, bg) >= min_ratio then
        return fg
    end

    -- Direction: bg dark → push fg lighter; bg light → push fg darker.
    local push_up = M.luminance(bg) < 0.5

    local r, g, b = hex_to_rgb(fg)
    local h, s, l = rgb_to_hsl(r, g, b)

    for _ = 1, 40 do
        if push_up then
            l = math.min(1, l + 0.03)
        else
            l = math.max(0, l - 0.03)
        end
        local nr, ng, nb = hsl_to_rgb(h, s, l)
        local hex = rgb_to_hex(nr, ng, nb)
        if M.contrast_ratio(hex, bg) >= min_ratio then
            return hex
        end
        if l <= 0 or l >= 1 then
            break
        end
    end

    return push_up and "#ffffff" or "#000000"
end

-- Convenience: blend two colours by `alpha` (0 → b, 1 → a). Used for the
-- subtle UI surfaces (sidebar, statusline borders) where tinct's surface_*
-- siblings are sometimes too close in luminance to distinguish.
function M.blend(a, b, alpha)
    if not a or not b then
        return a or b
    end
    local ar, ag, ab = hex_to_rgb(a)
    local br, bg_, bb = hex_to_rgb(b)
    local function mix(x, y)
        return alpha * x + (1 - alpha) * y
    end
    return rgb_to_hex(mix(ar, br), mix(ag, bg_), mix(ab, bb))
end

-- Convenience: separate two surfaces by `min_delta` luminance units. If
-- they're too close, push the second one slightly darker/lighter than the
-- first so panes are visible against each other.
function M.ensure_separation(base, surface, min_delta)
    min_delta = min_delta or 0.05
    if not base or not surface then
        return surface
    end
    local lb, ls = M.luminance(base), M.luminance(surface)
    if math.abs(ls - lb) >= min_delta then
        return surface
    end
    if lb < 0.5 then
        return M.blend("#ffffff", surface, min_delta)
    else
        return M.blend("#000000", surface, min_delta)
    end
end

return M
