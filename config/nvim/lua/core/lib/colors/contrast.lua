-- High-level visibility helpers built on the WCAG primitives in format.lua
-- (contrast_ratio / ensure_contrast). These exist because the tinct-generated
-- The tinct palette occasionally collapses several roles onto the same hex value
-- (e.g. A0 == A1 == A2, B3 == editor bg). Using a role color directly is then
-- a coin flip — these functions guarantee a usable result regardless of what
-- the palette happens to contain this session.

local format = require("core.lib.colors.format")

local M = {}

-- Contrast targets (WCAG): 4.5 = AA normal text, 3.0 = AA large text / UI
-- glyphs, 7.0 = AAA. Sub-element "is it even different" threshold is ~1.3.
M.AA = 4.5
M.AA_LARGE = 3.0
M.AAA = 7.0

--- Best plain foreground (black or white) for a background — maximum contrast,
--- no hue. Use when readability matters more than matching a palette accent.
-- @param bg string|number
-- @return string "#000000" | "#ffffff"
function M.auto_fg(bg)
    return format.contrast_foreground(bg)
end

--- Returns a foreground readable on `bg`. Starts from `desired` (or, if nil,
--- the palette's natural fg) and only shifts it far enough to clear `ratio`.
--- If `desired` is already fine it is returned untouched, so palette hues are
--- preserved whenever they happen to be legible.
-- @param bg string|number
-- @param desired string|number? preferred foreground (kept if it passes)
-- @param ratio number? default M.AA
-- @return string
function M.readable_on(bg, desired, ratio)
    ratio = ratio or M.AA
    bg = format.format_color(bg)
    -- No desired color: jump straight to the guaranteed extreme.
    if not desired then
        return M.auto_fg(bg)
    end
    return format.ensure_contrast(desired, bg, ratio)
end

--- Picks the first color from `candidates` that clears `ratio` against `bg`.
--- If none do, returns whichever has the highest contrast (best effort) —
--- handy for choosing among palette roles without inventing a new color.
-- @param bg string|number
-- @param candidates (string|number)[]
-- @param ratio number? default M.AA
-- @return string chosen color, boolean whether it actually met the ratio
function M.pick_readable(bg, candidates, ratio)
    ratio = ratio or M.AA
    local best, best_ratio = nil, -1
    for _, c in ipairs(candidates) do
        local r = format.contrast_ratio(c, bg)
        if r >= ratio then
            return format.format_color(c), true
        end
        if r > best_ratio then
            best, best_ratio = c, r
        end
    end
    return format.format_color(best or "#ffffff"), false
end

--- Ensures `color` is visually distinct from `base` (a neighbouring surface).
--- This is the fix for the palette-collapse case: when a "highlight bg" or
--- "statusline bg" resolves to the same hex as the editor bg, nudge it.
--- The nudge is toward whichever of lighter/darker keeps it on-theme.
-- @param base string|number the surface it sits against
-- @param color string|number the color that must stand apart
-- @param min_ratio number? default 1.25 (just-noticeable difference)
-- @return string
function M.separate(base, color, min_ratio)
    min_ratio = min_ratio or 1.25
    base = format.format_color(base)
    color = format.format_color(color)
    if format.contrast_ratio(color, base) >= min_ratio then
        return color
    end
    -- Decide nudge direction: away from base's luminance.
    local bl = format.contrast_ratio(base, "#000000")
    -- bl is large when base is light. Light base -> darken the color, and
    -- vice versa, so the two always pull apart.
    local toward = bl > 5 and "#000000" or "#ffffff"
    local lo, hi, best = 0, 1, color
    for _ = 1, 14 do
        local mid = (lo + hi) / 2
        local cand = format.blend(toward, color, mid)
        if format.contrast_ratio(cand, base) >= min_ratio then
            best, hi = cand, mid
        else
            lo = mid
        end
    end
    return best
end

--- Guarantees an accent color reads on `bg` while keeping its hue as much as
--- possible. Alias-with-intent over ensure_contrast: use for semantic accents
--- (git/diagnostic/mode colors) where the hue carries meaning.
-- @param bg string|number
-- @param accent string|number
-- @param ratio number? default M.AA_LARGE (accents are usually glyphs/bars)
-- @return string
function M.accent_on(bg, accent, ratio)
    return format.ensure_contrast(accent, bg, ratio or M.AA_LARGE)
end

--- Builds a guaranteed-legible { fg, bg } pair from two palette roles.
--- bg is taken as-is; fg is corrected to clear `ratio`. Returns a table ready
--- to splat into nvim_set_hl.
-- @param bg string|number
-- @param fg string|number
-- @param ratio number? default M.AA
-- @return { fg: string, bg: string }
function M.safe_pair(bg, fg, ratio)
    bg = format.format_color(bg)
    return { bg = bg, fg = format.ensure_contrast(fg, bg, ratio or M.AA) }
end

return M
