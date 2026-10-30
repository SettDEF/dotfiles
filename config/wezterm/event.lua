local wezterm = require("wezterm")

wezterm.on("bell", function()
	-- Use your preferred sound player and the path to your sound file
	-- wezterm.log_info("Playing custom ring sound...")
	-- wezterm.run_child_process({ "mpv", "--no-terminal",
	--		"/mnt/lib/Resouces/Audio/Packs000/Lmgmadeit Ezzential Rock Kit/Drumkit™/z™ Texturez_Atmoz/Radio @lmgmadeit.wav" })
end)

wezterm.on("toggle-tab-bar", function(window, pane)
	local overrides = window:get_config_overrides() or {}
	if overrides.enable_tab_bar == nil then
		overrides.enable_tab_bar = true
	else
		overrides.enable_tab_bar = not overrides.enable_tab_bar
	end
	window:set_config_overrides(overrides)
end)

return {
	-- Enable audible bell so the "bell" event triggers
	audible_bell = "Disabled",
	visual_bell = {
		fade_in_duration_ms = 150,
		fade_out_duration_ms = 150
	}
}
