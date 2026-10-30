local wezterm = require("wezterm")
local global = require("global")
local keybinds = require("keybinds")
local mousebinds = require("mousebinds")
local fonts = require("fonts")
local theme = require("theme")
local window = require("window")
-- require("status")
require("event")

local M = {}

-- Configuration builder
if wezterm.config_builder then
    M = wezterm.config_builder()
end

-- Native Wayland (default falls back to XWayland, which drops some input
-- events and looks blurry on hidpi).
M.enable_wayland = true

-- Appearance
M.default_cursor_style = "BlinkingBlock"
M.force_reverse_video_cursor = true
M.animation_fps = 20
M.max_fps = 60
M.cursor_blink_rate = 1000
M.cursor_blink_ease_in = "Linear"
M.cursor_blink_ease_out = "Linear"
M.colors = theme.cirqla_x.colors
-- Invalidate Lua's require cache before reloading the tinct palette.
-- Without this, wezterm's auto-reload re-executes wezterm.lua but the
-- `require("tinct_colors")` call returns the cached table from the
-- first launch — so any window started before the latest wallpaper
-- change stays stuck on its original palette, while freshly-started
-- windows see the new colours. Resetting the cache forces a re-read
-- from disk on every reload.
package.loaded["tinct_colors"] = nil
-- Make sure wezterm actually reloads when tinct rewrites the file:
-- by default it only watches wezterm.lua; add the tinct file too
-- so its mtime change kicks an automatic config reload.
wezterm.add_to_config_reload_watch_list(wezterm.config_dir .. "/tinct_colors.lua")
local ok, tinct_colors = pcall(require, "tinct_colors")
if ok and tinct_colors then
    for k, v in pairs(tinct_colors) do
        M.colors[k] = v
    end
end

-- Fonts
fonts.setup(M)

-- Window-specific settings
window.setup(M)

-- Keybindings and mouse bindings
M.leader = keybinds.leader
M.key_tables = keybinds.key_tables
M.mouse_bindings = mousebinds.mouse_bindings
M.disable_default_key_bindings = true
M.keys = keybinds.keys

-- Miscellaneous
M.use_resize_increments = true
M.line_height = 1
M.use_ime = true
M.initial_rows = 30
M.initial_cols = 120
M.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
M.enable_kitty_graphics = true

-- Glass: written by the shell's Palette > Glass panel. Absent or empty = opaque.
wezterm.add_to_config_reload_watch_list(wezterm.config_dir .. "/glass.lua")
local glass_ok, glass = pcall(dofile, wezterm.config_dir .. "/glass.lua")
if glass_ok and type(glass) == "table" and glass.opacity then
    M.window_background_opacity = glass.opacity
    -- Makes cells with an explicit colour (tmux pills, nvim) see-through
    -- too. Off: the solid pills look better; tmux uses bg=default instead.
    -- M.text_background_opacity = glass.opacity
end

return M
