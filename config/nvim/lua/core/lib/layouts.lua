-- Window layout cycling. Call cycle_layout() to step through the available
-- layouts. The current index wraps around when it reaches the end of the list.

local function get_num_windows()
    return #vim.api.nvim_list_wins()
end

local layout_names = {
    "Simple Tiling",
    "Horizontal Tiling",
    "Vertical Tiling",
    "Floating",
    "One Master",
    "Max-Window",
    "Two Master",
}

-- Returns only windows that correspond to real, visible file buffers.
-- Sidebar/popup windows (neotree, telescope, nvim-tree, hidden bufs) are excluded
-- so layouts operate on editor content only.
local function filter_windows(windows)
    local filtered = {}
    for _, win in ipairs(windows) do
        local buf = vim.api.nvim_win_get_buf(win)
        local buf_name = vim.api.nvim_buf_get_name(buf)
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
        local hidden = vim.api.nvim_get_option_value("bufhidden", { buf = buf })

        local is_real = buf_name ~= ""
            and buftype ~= "nofile"
            and buftype ~= "prompt"
            and not buf_name:match("^neotree_")
            and not buf_name:match("^telescope_")
            and not buf_name:match("^nvim%-tree_")
            and hidden ~= "hide"

        if is_real then
            table.insert(filtered, win)
        end
    end
    return filtered
end

local layouts = {
    -- 1. Simple Tiling: arranges windows in an equal-size grid.
    function(num_windows)
        if num_windows <= 0 then
            return
        end
        local rows = math.ceil(math.sqrt(num_windows))
        local cols = math.ceil(num_windows / rows)
        local windows = filter_windows(vim.api.nvim_list_wins())
        local win_w = math.floor(vim.o.columns / cols)
        local win_h = math.floor(vim.o.lines / rows)

        for i, win in ipairs(windows) do
            local row = math.floor((i - 1) / cols)
            local col = (i - 1) % cols
            vim.api.nvim_win_set_config(win, {
                relative = "editor",
                width = win_w,
                height = win_h,
                row = row * win_h,
                col = col * win_w,
            })
        end
    end,

    -- 2. Horizontal Tiling: equal-height rows stacked vertically.
    function(num_windows)
        if num_windows <= 0 then
            return
        end
        local windows = filter_windows(vim.api.nvim_list_wins())
        local win_h = math.floor(vim.o.lines / num_windows)

        for i, win in ipairs(windows) do
            vim.api.nvim_win_set_config(win, {
                relative = "editor",
                width = vim.o.columns,
                height = win_h,
                row = (i - 1) * win_h,
                col = 0,
            })
        end
    end,

    -- 3. Vertical Tiling: equal-width columns side by side.
    function(num_windows)
        if num_windows <= 0 then
            return
        end
        local windows = filter_windows(vim.api.nvim_list_wins())
        local win_w = math.floor(vim.o.columns / num_windows)

        for i, win in ipairs(windows) do
            vim.api.nvim_win_set_config(win, {
                relative = "editor",
                width = win_w,
                height = vim.o.lines,
                row = 0,
                col = (i - 1) * win_w,
            })
        end
    end,

    -- 4. Floating: every window occupies the full editor area (layered).
    function(num_windows)
        if num_windows <= 0 then
            return
        end
        local windows = filter_windows(vim.api.nvim_list_wins())

        for _, win in ipairs(windows) do
            vim.api.nvim_win_set_config(win, {
                relative = "editor",
                width = vim.o.columns,
                height = vim.o.lines,
                row = 0,
                col = 0,
            })
        end
    end,

    -- 5. One Master: top two-thirds for the first window, rest splits below.
    function(num_windows)
        if num_windows <= 0 then
            return
        end
        local windows = filter_windows(vim.api.nvim_list_wins())
        local master_h = math.floor(vim.o.lines * 2 / 3)
        local stack_h = vim.o.lines - master_h

        vim.api.nvim_win_set_config(windows[1], {
            relative = "editor",
            width = vim.o.columns,
            height = master_h,
            row = 0,
            col = 0,
        })

        for i = 2, num_windows do
            local win_h = math.floor(stack_h / (num_windows - 1))
            vim.api.nvim_win_set_config(windows[i], {
                relative = "editor",
                width = vim.o.columns,
                height = win_h,
                row = master_h + (i - 2) * win_h,
                col = 0,
            })
        end
    end,

    -- 6. Max-Window: shows only the first window, closes all others.
    function(num_windows)
        if num_windows <= 0 then
            return
        end
        local windows = filter_windows(vim.api.nvim_list_wins())

        vim.api.nvim_win_set_config(windows[1], {
            relative = "editor",
            width = vim.o.columns,
            height = vim.o.lines,
            row = 0,
            col = 0,
        })

        for i = 2, num_windows do
            vim.api.nvim_win_close(windows[i], true)
        end
    end,

    -- 7. Two Master: two equal columns; overflow windows tile in the left column.
    function(num_windows)
        if num_windows <= 0 then
            return
        end
        local windows = filter_windows(vim.api.nvim_list_wins())
        local half_w = math.floor(vim.o.columns / 2)

        vim.api.nvim_win_set_config(windows[1], {
            relative = "editor",
            width = half_w,
            height = vim.o.lines,
            row = 0,
            col = 0,
        })

        if windows[2] then
            vim.api.nvim_win_set_config(windows[2], {
                relative = "editor",
                width = half_w,
                height = vim.o.lines,
                row = 0,
                col = half_w,
            })
        end

        for i = 3, num_windows do
            local win_h = math.floor(vim.o.lines / (num_windows - 2))
            vim.api.nvim_win_set_config(windows[i], {
                relative = "editor",
                width = half_w,
                height = win_h,
                row = (i - 3) * win_h,
                col = 0,
            })
        end
    end,
}

local current_layout_index = 1

local function cycle_layout()
    current_layout_index = (current_layout_index % #layouts) + 1
    local num_windows = get_num_windows()

    if layouts[current_layout_index] then
        layouts[current_layout_index](num_windows)
        vim.notify(
            "Layout: " .. layout_names[current_layout_index],
            vim.log.levels.INFO,
            { title = "Window Layout" }
        )
    end
end

return {
    get_num_windows = get_num_windows,
    layout_names = layout_names,
    layouts = layouts,
    cycle_layout = cycle_layout,
}
