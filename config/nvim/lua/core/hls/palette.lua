-- ─────────────────────────────────────────────────────────────────────────
-- core.hls.palette — the ONE palette source for every highlight module.
-- ─────────────────────────────────────────────────────────────────────────
--
-- Reads the live palette from tinct.nvim (`require("tinct").palette()`) and
-- exposes it under the semantic keys that the core.hls.* modules and the
-- heirline statusline actually consume.
--
--
-- Layout:
--   • Semantic MD3 keys       (primary, on_primary, surface, on_surface, ...)
--   • Human-readable aliases  (fg, fg_dark, bg, bg_highlight, ...)
--   • Legacy alphanumeric     (A0..A6, B0..B4, C0..C15) — deprecated
--   • Diagnostics             (error, warn, info, hint)
--   • Git / diff              (git.add, git.change, git.delete, git.warning)
--
-- Refresh model: `require` caches this table. core.hls.load() evicts it (and
-- the modules built from it) from package.loaded on every tinct reload.
-- ─────────────────────────────────────────────────────────────────────────

-- Get the raw Material palette from tinct.nvim; falls back gracefully to
-- the built-in FALLBACK if tinct isn't on the runtimepath yet.
local function raw()
    local ok, tinct = pcall(require, "tinct")
    if ok and type(tinct.palette) == "function" then
        return tinct.palette()
    end
    local pok, tp = pcall(require, "tinct.palette")
    if pok then
        return tp.load()
    end
    -- Very last resort — bare defaults so the file never returns nil.
    return {
        background = "#131315", on_background = "#e4e2e3",
        surface = "#131315", on_surface = "#e4e2e3",
        on_surface_variant = "#c8c6c7",
        surface_container_low = "#171719", surface_container = "#1b1b1d",
        surface_container_high = "#252526", surface_container_highest = "#302f30",
        primary = "#c2c6d6", secondary = "#c4c6d0", tertiary = "#bfc6dc",
        primary_container = "#424753", secondary_container = "#44474f",
        tertiary_container = "#8991a5",
        on_primary = "#2b303c", on_error = "#690005",
        error = "#ffb4ab", error_container = "#93000a",
        outline = "#8f9098", outline_variant = "#3f4147",
    }
end

local function build()
    local p = raw()

    -- ── Fixed semantic colors ─────────────────────────────────────────
    -- Yellow/green/red for warnings, add/delete stats — Material doesn't
    -- publish yellow/green channels distinct from primary/tertiary hue
    -- rotations, so pin these so git/diagnostic UI stays semantically
    -- readable regardless of the wallpaper.
    local WARN_YELLOW = "#fabd2f"
    local ADD_GREEN   = "#8ec07c"

    return {
        -- ── Material Design 3 semantic roles (preferred) ────────────
        background                = p.background,
        on_background             = p.on_background,
        surface                   = p.surface,
        on_surface                = p.on_surface,
        on_surface_variant        = p.on_surface_variant,
        surface_container_lowest  = p.surface_container_lowest,
        surface_container_low     = p.surface_container_low,
        surface_container         = p.surface_container,
        surface_container_high    = p.surface_container_high,
        surface_container_highest = p.surface_container_highest,

        primary                   = p.primary,
        on_primary                = p.on_primary,
        primary_container         = p.primary_container,
        secondary                 = p.secondary,
        secondary_container       = p.secondary_container,
        tertiary                  = p.tertiary,
        tertiary_container        = p.tertiary_container,

        outline                   = p.outline,
        outline_variant           = p.outline_variant,

        -- ── Human-readable aliases (statusline / hls modules) ───────
        fg          = p.on_surface,
        fg_dark     = p.on_surface_variant,
        fg_inactive = p.outline,
        bg          = p.background,
        bg_dark     = p.surface_container_low,
        bg_highlight= p.surface_container,

        -- ── Semantic diagnostic accents (fixed hues) ────────────────
        -- Deliberately NOT palette-derived: users expect errors red,
        -- warnings yellow, info blue, hints teal regardless of
        -- wallpaper. Monochromatic palettes (all-green, all-blue)
        -- would otherwise collapse every severity onto one hue.
        error = "#f38ba8", -- red
        warn  = WARN_YELLOW,
        info  = "#89b4fa", -- blue
        hint  = "#94e2d5", -- teal

        -- ── Git / diff colors ───────────────────────────────────────
        git = {
            add     = ADD_GREEN,
            change  = WARN_YELLOW,
            delete  = p.error,
            warning = WARN_YELLOW,
        },
    }
end

return build()
