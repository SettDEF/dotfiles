local wezterm = require("wezterm")

local M = {}

-- Each entry contains a 'name' (for the toast) and the 'font_obj' (the actual setting)
local font_cycles = {
    {
        name = "MonaspiceNe",
        font_obj = wezterm.font_with_fallback({
            { family = "MonaspiceNe Nerd Font", weight = "Regular", stretch = "Normal" },
            { family = "Noto Color Emoji" }, -- Always keep emoji fallback
        }),
    },
    {
        name = "JetBrains Mono",
        font_obj = wezterm.font_with_fallback({
            { family = "JetBrainsMono Nerd Font", weight = "Regular" },
            { family = "Noto Color Emoji" },
        }),
    },
    {
        name = "Fira Code",
        font_obj = wezterm.font_with_fallback({
            { family = "FiraCode Nerd Font Mono", weight = 450 },
            { family = "Noto Color Emoji" },
        }),
    },
    {
        name = "Victor Mono",
        font_obj = wezterm.font_with_fallback({
            { family = "VictorMono Nerd Font", weight = 600 },
            { family = "Noto Color Emoji" },
        }),
    },
}

-- Apply static config and initialize the first font

function M.setup(config)
    -- Apply the default font (Index 1)
    config.font = font_cycles[1].font_obj

    -- Your General Font Settings
    config.font_size = 11.5
    config.underline_thickness = "200%"
    config.underline_position = "0pt"
    config.adjust_window_size_when_changing_font_size = true

    -- Rendering Settings
    config.freetype_load_target = "Light"
    config.freetype_render_target = "Light"
    config.front_end = "OpenGL" -- or "WebGpu"
    config.webgpu_power_preference = "HighPerformance"

    -- Ligature/Feature Settings
    config.harfbuzz_features = {
        "cv06=1",
        "cv14=1",
        "cv32=1",
        "ss04=1",
        "ss07=1",
        "ss09=1",
    }
end

-- Returns the action to trigger the toggle

function M.toggle_action()
    return wezterm.action.EmitEvent("toggle-font")
end

local window_font_index = {}

wezterm.on("toggle-font", function(window, pane)
    local wid = window:window_id()
    local current_index = window_font_index[wid] or 1
    local next_index = current_index + 1
    if next_index > #font_cycles then
        next_index = 1
    end
    window_font_index[wid] = next_index

    local selected = font_cycles[next_index]
    local overrides = window:get_config_overrides() or {}
    overrides.font = selected.font_obj
    window:set_config_overrides(overrides)

    window:toast_notification("wezterm", "Font switched to: " .. selected.name, nil, 4000)
end)

return M
