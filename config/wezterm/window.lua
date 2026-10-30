local wezterm = require("wezterm")

local function setup(config)
	config.window_decorations = "NONE"
	config.window_padding = {
		left = "0cell",
		right = "0cell",
		top = "0cell",
		bottom = "0cell",
	}
	config.window_frame = {
		font = wezterm.font({ family = "Noto Sans", weight = "Regular" }),
		font_size = 12.0,
	}
	config.use_fancy_tab_bar = false
	config.enable_tab_bar = false
end

return {
	setup = setup,
}
