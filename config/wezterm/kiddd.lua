local wezterm = require 'wezterm'
local M = {}

local main_palette = {
	["000000"] = '#1E1E24',
	["000001"] = '#2D2D35',
	["000010"] = '#3A3E4B',
	["000011"] = '#5E646D',
	["000100"] = '#4B3D5B',
	["000101"] = '#5C4A77',
	["000110"] = '#A6488D',
	["000111"] = '#D22B50',
	["001000"] = '#D76D31',
	["001001"] = '#B3A45E',
	["001010"] = '#7B8D1C',
	["001011"] = '#5A9F5D',
	["001100"] = '#47B3D0',
	["001101"] = '#B5B94D',
	["001110"] = '#C7A1B8',
	["001111"] = '#D2C0D1',
	["010000"] = '#C0D6E0',
	["010001"] = '#83B0C2',
	["010010"] = '#A8D8F6',
	["010011"] = '#4F5C5D',
	["010100"] = '#E4B38D',
	["010101"] = '#D4D8DB',
	["010110"] = '#D3C6FF',
	["010111"] = '#A1B1C4',
	["011000"] = '#E0E6EA',
	["011001"] = '#F2E0E0',
	["011010"] = '#FFE7A3',
	["011011"] = '#C0E6F4',
	["011100"] = '#C37EB5',
	["011101"] = '#B8C7D4',
	["011110"] = '#F5B4C7',
	["011111"] = '#ffffff',
}

local main_active_tab = {
	bg_color = main_palette["000001"],
	fg_color = main_palette["011111"],
}

local main_inactive_tab = {
	bg_color = main_palette["000000"],
	fg_color = main_palette["000011"],
}

function M.colors()
	return {
		foreground = main_palette["011111"], -- #D6DBDF ersetzt
		background = main_palette["000000"], -- #1E1E24 ersetzt
		cursor_bg = main_palette["000110"], -- #C25095 ersetzt
		cursor_border = main_palette["000111"], -- #D55B71 ersetzt
		cursor_fg = main_palette["011111"], -- #FFFFFF ersetzt
		selection_bg = main_palette["001011"], -- #5A9F5D ersetzt
		selection_fg = main_palette["000000"], -- #1E1E24 ersetzt
		ansi = {
			main_palette["000000"],       -- Black
			main_palette["000111"],       -- Red
			main_palette["001100"],       -- Green
			main_palette["001000"],       -- Yellow
			main_palette["000100"],       -- Blue
			main_palette["000110"],       -- Magenta
			main_palette["001100"],       -- Cyan
			main_palette["011111"],       -- White
		},
		brights = {
			main_palette["010000"], -- Bright Black
			main_palette["001111"], -- Bright Red
			main_palette["001011"], -- Bright Green
			main_palette["010100"], -- Bright Yellow
			main_palette["010111"], -- Bright Blue
			main_palette["010110"], -- Bright Magenta
			main_palette["011000"], -- Bright Cyan
			main_palette["011110"], -- Bright White
		},
		tab_bar = {
			background = main_palette["000000"],
			active_tab = main_active_tab,
			inactive_tab = main_inactive_tab,
			inactive_tab_hover = main_active_tab,
			new_tab = main_inactive_tab,
			new_tab_hover = main_active_tab,
			inactive_tab_edge = main_palette["000011"],
		},
	}
end

function M.window_frame()
	return {
		font = wezterm.font({ family = "JetBrainsMono Nerd Mono", weight = "Bold" }),
		font_size = 11.5,
		active_titlebar_bg = main_palette["000000"],
		inactive_titlebar_bg = main_palette["000000"],
		active_titlebar_fg = main_palette["011000"],
		inactive_titlebar_fg = main_palette["010111"],
		inactive_titlebar_border_bottom = main_palette["000000"],
		active_titlebar_border_bottom = main_palette["000011"],
		button_fg = main_palette["011001"],
		button_bg = main_palette["000011"],
		button_hover_fg = main_palette["011111"],
		button_hover_bg = main_palette["010001"],
		border_left_width = '0cell',
		border_right_width = '0cell',
		border_bottom_height = '0cell',
		border_top_height = '0cell',
	}
end

return {
	cirqla_x = M
}
