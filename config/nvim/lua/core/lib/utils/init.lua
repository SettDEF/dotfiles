local M = {}

-- Configuration
M.config = {
    -- Icon style: 'glyph' or 'ascii'
    style = "glyph",
    default = {},
    directory = {},
    extension = {},
    file = {},
    filetype = {},
    lsp = {},
    os = {},
    -- Control which extensions will be considered during "file" resolution
    use_file_extension = function(ext, file)
        return true
    end,
}

-- Caching
M.cache = {}
M.cache_index = {}
M.cache_index_lookup = {}

local default_hl = "Normal"

-- Function to set cache
M.cache_set = function(cat, name, icon, hl)
    -- Initialize cache for category if it doesn't exist
    M.cache[cat] = M.cache[cat] or {}

    -- Handle fallback icon case
    if icon == nil then
        local fallback_id = M.cache[cat][true]
        if fallback_id == nil then
            return "?", default_hl, true -- Return a default icon and highlight if the fallback is missing
        end
        M.cache[cat][name] = fallback_id
        local t = M.cache_index[fallback_id]
        return t[1], t[2], true
    end

    -- Ensure cache index is computed
    local id = (M.cache_index_lookup[hl] or {})[icon]
    if id == nil then
        -- Add new unique 'icon-hl'
        table.insert(M.cache_index, { icon, hl })
        id = #M.cache_index

        -- Update the lookup table
        local hl_icons = M.cache_index_lookup[hl] or {}
        hl_icons[icon] = id
        M.cache_index_lookup[hl] = hl_icons
    end

    -- Add to cache and return result tuple
    M.cache[cat][name] = id
    return icon, hl, false
end

-- Function to get from cache
M.cache_get = function(cat, name)
    return M.cache_index[M.cache[cat] and M.cache[cat][name]]
end

-- Implementation for getting icons based on category
-- Implementation for getting icons based on category
M.get_impl = {
    default = function(name)
        M.error(vim.inspect(name) .. " is not a supported category.")
    end,
    directory = function(name)
        return require("core.lib.utils.chars").directory[name]
    end,
    extension = function(name)
        -- Built-in extensions
        local icon_data = M.extension_icons[name]
        if type(icon_data) == "string" then
            return M.get("filetype", icon_data)
        end
        if icon_data then
            return icon_data
        end

        -- Check complex extensions
        local dot = string.find(name, "%..")
        while dot do
            local ext = name:sub(dot + 1)
            if M.extension_icons[ext] or M.config.extension[ext] then
                return M.get("extension", ext)
            end
            dot = string.find(name, "%..", dot + 1)
        end

        -- Fall back to built-in filetype
        local ft = M.filetype_match("aaa." .. name)
        if ft then
            return M.get("filetype", ft)
        end
    end,
    file = function(name)
        local basename = M.fs_basename(name)

        -- User configured filenames
        if M.config.file[basename] and name ~= basename then
            return M.get("file", basename)
        end

        -- Built-in file names
        local icon_data = M.file_icons[basename]
        if type(icon_data) == "string" then
            return M.get("filetype", icon_data)
        elseif icon_data then
            return M.style_icon(icon_data.glyph, basename), icon_data.hl
        end

        -- Handle extensions
        local dot = string.find(basename, "%..", 2)
        if dot then
            local ext = basename:sub(dot + 1):lower()
            if M.config.use_file_extension(ext, name) then
                local icon, hl, is_default = M.get("extension", ext)
                if not is_default then
                    return icon, hl
                end
            end
        end

        -- Fallback to built-in filetype
        local ft = M.filetype_match(name)
        if ft then
            return M.get("filetype", ft)
        end

        -- Return full filename with extension if none found
        return basename, default_hl
    end,
    filetype = function(name)
        return require("core.lib.utils.chars").filetype_icons[name]
    end,
    lsp = function(name)
        return require("core.lib.utils.chars").lsp_icons[name]
    end,
    os = function(name)
        return require("core.lib.utils.chars").os_icons[name]
    end,
}

M.filetype_match = function(filename)
    -- Ensure always present scratch buffer to be used in `vim.filetype.match()`
    -- (needed because the function in many ambiguous cases prefers to return
    -- nothing if there is no buffer supplied)
    local buf_id = M.scratch_buf_id
    M.scratch_buf_id = (buf_id == nil or not vim.api.nvim_buf_is_valid(buf_id))
            and vim.api.nvim_create_buf(false, true)
        or buf_id
    return vim.filetype.match({ filename = filename, buf = M.scratch_buf_id })
end

-- Function to get highlight data
local get_hl_data = function(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false })
end

-- Get hex color from highlight group
local get_hex = function(hl)
    if not hl then
        return nil
    end
    local data = get_hl_data(hl)
    return string.format("#%06x", data.fg or 7176326)
end

-- Get terminal color from highlight group
local get_cterm = function(hl)
    if not hl then
        return nil
    end
    local data = get_hl_data(hl)
    return data.ctermfg or 66
end

-- Create an icon table
local make_icon_tbl = function(category, name, output_name)
    local icon, hl = M.get(category, name)
    return {
        icon = icon or "?", -- Fallback icon
        color = get_hex(hl),
        cterm_color = tostring(get_cterm(hl)),
        name = output_name,
    }
end

-- Create a category table of icons
local make_category_tbl = function(category)
    local res = {}
    for _, name in ipairs(M.list(category)) do
        res[name] = make_icon_tbl(category, name, name)
    end
    return res
end

-- List icons in a specified category
M.list = function(category)
    local category_icons = require("core.lib.utils")[category]
    if not category_icons then
        M.error(vim.inspect(category) .. " is not a supported category.")
    end

    -- Collect unique icons
    local res_map = {}
    for k in pairs(category_icons) do
        res_map[k] = true
    end
    for k in pairs(M.config[category]) do
        res_map[k] = true
    end

    local res = vim.tbl_keys(res_map)
    table.sort(res)
    return res
end

-- Get icon based on category and name
M.get = function(category, name)
    if not (type(category) == "string" and type(name) == "string") then
        M.error("Both `category` and `name` should be strings.")
    end

    local getter = M.get_impl[category]
    if not getter then
        M.error(vim.inspect(category) .. " is not a supported category.")
    end

    -- Check cache first
    name = category == "file" and name
        or (category == "directory" and M.fs_basename(name) or name:lower())
    local cached = M.cache_get(category, name)
    if cached then
        return cached[1], cached[2], cached[3] == true
    end

    -- Fetch icon
    local icon, hl = getter(name)
    if type(icon) == "table" then
        icon, hl = M.style_icon(icon.glyph, name), icon.hl
    end

    -- Save to cache and return
    return M.cache_set(category, name, icon, hl)
end

-- Get default icon
M.get_default_icon = function()
    return make_icon_tbl("default", "file", "Default")
end

-- Get all icons
M.get_icons = function()
    return vim.tbl_deep_extend(
        "force",
        { [1] = M.get_default_icon() },
        make_category_tbl("os"),
        make_category_tbl("file"),
        make_category_tbl("extension")
    )
end

-- Style icon based on the configuration
M.style_icon = function(glyph, name)
    if M.config.style ~= "ascii" then
        return glyph
    end
    return vim.fn.toupper(name:sub(1, vim.str_byteindex(name, 1)))
end

function M.get_border_chars(desc)
    local C = require("core.lib.utils.chars")

    if vim.g.neovide then
        -- Hmmmm
    end

    if desc == "completion" then
        return C.border_chars_top_only
    end
    if desc == "cmdline" then
        return C.border_chars_none
    end
    if desc == "search" then
        return C.border_chars_round
    end
    if desc == "float" then
        return C.border_chars_outer_thin
    end
    if desc == "telescope" then
        return C.border_chars_outer_thick_telescople
    end
    return C.border_chars_round
end

---@generic T
---@class DynamicList<T>: [T]
DynamicList = {}

---@generic T
---@class DynamicListOpts<T>
---@diagnostic disable-next-line: undefined-doc-name
---@field update_fn fun(list: DynamicList<T>, args: any)
---@field event? string
---@field pattern? string
DynamicListOpts = {}

---@generic T
---@param opts DynamicListOpts
---@return DynamicList<T>
function DynamicList:new(opts)
    local list = {}

    if opts.event then
        M.aucmd(opts.event, function(args)
            opts.update_fn(list, args)
        end, { pattern = opts.pattern })
    end

    return list
end

M.error = function(msg)
    error(string.format("[Error in config] %s", msg), 0)
end

M.notify = function(msg, level_name)
    vim.notify("[config] " .. msg, vim.log.levels[level_name])
end

function M.current_buffer_filetype()
    return vim.bo.filetype
end

function M.current_buffer_type()
    return vim.bo.buftype
end

function M.current_buffer_modified()
    return vim.bo.modified
end

function M.current_window_floating()
    return vim.api.nvim_win_get_config(0).relative ~= ""
end

function M.current_buffer_dir()
    return vim.api.nvim_buf_get_name(0):match("(.*" .. "/" .. ")")
end

function M.current_window()
    return vim.api.nvim_get_current_win()
end

function M.current_window_hl(hl)
    local win = M.current_window()
    vim.api.nvim_set_option_value("winhl", hl, { win = win })
end

--- Create an autocmd
--- @param events string | string[]
--- @param callback fun(...)
--- @param opts? table
function M.aucmd(events, callback, opts)
    opts = vim.tbl_extend("force", { callback = callback }, opts or {})
    vim.api.nvim_create_autocmd(events, opts)
end

--- Create a User autocmd
--- @param pattern string
--- @param callback fun(...)
--- @param opts? table
function M.user_aucmd(pattern, callback, opts)
    opts = vim.tbl_extend("force", { pattern = pattern, callback = callback }, opts or {})
    vim.api.nvim_create_autocmd("User", opts)
end

---Helper function to help write constructors
---@generic T: table
---@param class table
---@param default T
---@return T
function M.new_object(class, default)
    default = default or {}
    setmetatable(default, class)
    class.__index = class
    return default
end

---@generic T
---@class CachedDict<T>: { [string]: T }
---@field _cache table
M.CachedDict = {}

---Create a new [CachedDict<T>] object
---@generic T
---@param cacher fun(key: string): T
---@return CachedDict<T>
function M.CachedDict.new(self, cacher)
    local obj = {
        _cache = {},
    }
    setmetatable(obj, {
        __index = function(table, key)
            if key == "reset" then
                return function()
                    table._cache = {}
                end
            elseif key == "load" then
                return function(hls, group)
                    hls._cache[group] = cacher(group)
                    return hls._cache[group]
                end
            end
            if not table._cache[key] then
                table._cache[key] = cacher(key)
            end
            return table._cache[key]
        end,
    })
    return obj
end

---Create a new lazy-loaded object
---@generic T
---@param init fun(): T
---@param reset_on_colorscheme_change boolean | nil
---@return T
function M.lazy_init(init, reset_on_colorscheme_change)
    local obj = {
        _cache = {},
    }
    setmetatable(obj, {
        __index = function(table, key)
            if key == "reset" then
                return function()
                    table._cache = {}
                end
            end
            if #table._cache == 0 then
                table._cache = init()
            end
            return table._cache[key]
        end,
    })

    if reset_on_colorscheme_change then
        require("core.lib.events").on_colorscheme_change(function()
            obj:reset()
        end)
    end

    return obj
end

---@param path string
---@param on_event fun(filename: string, events: string[], handle: uv_fs_event_t)
---@param flags? table
function M.watch_file(path, on_event, flags)
    local handle = assert(vim.uv.new_fs_event(), "Failed to create fs_event handle")

    handle:start(path, flags or {}, function(err, filename, events)
        if err then
            error("Error in fs_event: " .. err)
            handle:stop()
        else
            on_event(filename, events, handle)
        end
    end)

    return handle
end

---@class MyCommand
---@field cmd string[]
---@field callback fun(lines: string[])
---@field ignore_errors boolean | nil

---@param commands MyCommand[]
---@param finally fun() | nil
function M.chain_system_commands(commands, finally)
    vim.system(commands[1].cmd, {}, function(result)
        if result.code ~= 0 and not commands[1].ignore_errors then
            vim.notify(
                "Error in system command: " .. vim.inspect(commands[1].cmd) .. "\n" .. result.stderr,
                vim.log.levels.ERROR
            )
            if finally then
                finally()
            end
        else
            commands[1].callback(vim.split(result.stdout, "\n", { trimempty = true }))

            if #commands > 1 then
                M.chain_system_commands(vim.list_slice(commands, 2, #commands), finally)
            elseif finally then
                finally()
            end
        end
    end)
end

---@param func fun(...)
---@param delay? number
---@return fun(...), uv_timer_t
function M.debounce(func, delay)
    delay = delay or 50
    local timer = vim.uv.new_timer()

    local wrapped_fn = function(...)
        local argv = { ... }
        local argc = select("#", ...)

        timer:start(delay, 0, function()
            pcall(vim.schedule_wrap(func), unpack(argv, 1, argc))
        end)
    end

    return wrapped_fn, timer
end

---Run a function for all buffers, and aggregate the results
---@generic T
---@param func fun(bufnr: number): T
---@return T[]
function M.for_all_buffers(func)
    local ret = {}

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        table.insert(ret, 0, func(bufnr))
    end

    return ret
end

---@generic T
---@class DynamicList<T>: [T]
M.DynamicList = {}

---@generic T
---@class DynamicListOpts<T>
---@field update_fn fun(list: DynamicList<T>, args: any)
---@field event? string
---@field pattern? string

---@generic T
---@param opts DynamicListOpts
---@return DynamicList<T>
function M.DynamicList.new(self, opts)
    local list = {}

    if opts.event then
        M.aucmd(opts.event, function(args)
            opts.update_fn(list, args)
        end, { pattern = opts.pattern })
    end

    return list
end

function M.current_buffer_modifiable()
    local buftype = M.current_buffer_type()
    if buftype == "nofile" or buftype == "prompt" or buftype == "help" then
        return false
    end
    if vim.bo.readonly then
        return false
    end
    return true
end

function M.current_buffer_filename()
    local bufname = vim.api.nvim_buf_get_name(0)
    return bufname ~= "" and vim.fn.fnamemodify(bufname, ":t") or ""
end

function M.current_buffer_icon()
    local c = M.current_buffer_filetype()

    if c == "help" then
        return "󰞋"
    end

    local I = require("nvim-web-devicons")
    local icon = I.get_icon_by_filetype(c)
    return icon
end

function M.current_buffer_parent()
    local current_buffer = vim.api.nvim_get_current_buf()
    local current_file = vim.api.nvim_buf_get_name(current_buffer)
    local parent = vim.fn.fnamemodify(current_file, ":h:t")
    if parent == "." then
        return ""
    end
    return parent .. "/"
end

function M.current_buffer_lsp()
    local buf_ft = M.current_buffer_filetype()
    local clients = vim.lsp.get_clients()
    if next(clients) == nil then
        return ""
    end
    local current_clients = ""

    for _, client in ipairs(clients) do
        local filetypes = client.config.filetypes
        if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
            current_clients = current_clients .. client.name .. " "
        end
    end

    return current_clients
end

function M.is_recording()
    return vim.fn.reg_recording() ~= ""
end

function M.get_recording_icon()
    if M.is_recording() then
        return "  "
    else
        return ""
    end
end

-- Function to check if the current directory is the notes directory
function M.is_notes_dir()
    local cwd = vim.fn.getcwd()
    --  Modify this path to match the exact path of your notes directory
    local notes_dir = os.getenv("HOME") .. "Documents/notes" -- Replace with your actual path
    return cwd == notes_dir
end

function M.link_hl(target, link)
    vim.api.nvim_set_hl(0, target, { link = link })
end

M.to_macos_keys = function(keymap)
    return keymap
        :gsub("CR", "↩")
        :gsub("<", "")
        :gsub(">", "")
        :gsub("-", " ")
        :gsub("D", "⌘")
        :gsub("A", "⌥")
        :gsub("C", "⌃")
        :gsub("BS", "⌫")
        :gsub("leader", vim.g.mapleader .. " ")
end

M.exclude_ft_table = {
    ["neo-tree"] = true,
    ["neo-tree-popup"] = true,
    lazyterm = true,
    aerial = true,
    dashboard = true,
    help = true,
    lspinfo = true,
    lspsagafinder = true,
    packer = true,
    checkhealth = true,
    man = true,
    mason = true,
    NvimTree = true,
    plugin = true,
    lazy = true,
    TelescopePrompt = true,
    terminal = true,
    nofile = true,
    [""] = true, -- because TelescopePrompt will set a empty ft, so add this.
    alpha = true,
    toggleterm = true,

    noice = true,
    text = true,
    dropbar_menu = true,

    DressingInput = true,
    NeogitStatus = true,
    ssr = true,

    NeogitCommitMessage = true,
}

M.load_highlight = function(group)
    for hl, col in pairs(group) do
        vim.api.nvim_set_hl(0, hl, col)
    end
end

M.keymap_factory = function(mode)
    return function(keybind, custom, description, opts)
        local options = { noremap = true, silent = true }

        if opts then
            options = vim.tbl_extend("force", options, opts)
        end

        if description then
            options = vim.tbl_extend("force", options, { desc = description })
        end

        vim.keymap.set(mode, keybind, custom, options)
    end
end

M.termcodes = function(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end

M.focus_nvim_tree = function(key)
    local k = key or ""

    return function()
        local bufname = vim.api.nvim_buf_get_name(0)

        if string.find(bufname, "NvimTree") then
            vim.api.nvim_input("<C-w>h")
            return
        end

        vim.api.nvim_input(k .. "<C-w>l")
    end
end

M.text_padding = function(str)
    return "\n" .. str:gsub("([^\n]+)", "      %1      ") .. "\n"
end

M.cmd = function(str)
    return "<cmd> " .. str .. " <CR>"
end

M.load_plugin = function(name)
    return function()
        require("plugins." .. name)
    end
end

M.schedule = function(fn, ms)
    ms = ms or 5
    local timer = vim.uv.new_timer()
    timer:start(ms, 0, vim.schedule_wrap(fn))
end

M.preserve_cursor_position = function(fn)
    local line, col = unpack(vim.api.nvim_win_get_cursor(0))
    fn()

    M.schedule(function()
        local lastline = vim.fn.line("$")
        if line > lastline then
            line = lastline
        end
        vim.api.nvim_win_set_cursor(0, { line, col })
    end)
end

M.normalize_path = function(path)
    local Path = require("plenary.path")
    local cwd = vim.fn.getcwd()
    return Path:new(path):normalize(cwd)
end

M.get_selected_content = function()
    local curr_buffer = vim.fn.bufnr("%")
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" then
        start_pos = vim.fn.getpos("'<")
        end_pos = vim.fn.getpos("'>")
        end_pos[3] = vim.fn.col("'>")
    else
        local cursor = vim.fn.getpos(".")
        start_pos = cursor
        end_pos = start_pos
    end

    local content = table.concat(
        vim.api.nvim_buf_get_text(
            curr_buffer,
            start_pos[2] - 1,
            start_pos[3] - 1,
            end_pos[2] - 1,
            end_pos[3] - 1,
            {}
        ),
        "\n"
    )

    return content
end

---Helper function, as some LSPs like `ltex` do not support ignore files
---@param client vim.lsp.Client
---@param bufnr integer
function M.detachIfObsidianOrIcloud(client, bufnr)
    local path = vim.api.nvim_buf_get_name(bufnr)
    local obsiDir = #vim.fs.find(
            ".obsidian",
            { path = path, upward = true, type = "directory" }
        ) > 0
    local iCloudDocs = vim.startswith(path, os.getenv("HOME") .. "/Library/Mobile Documents/")
    if obsiDir or (iCloudDocs and client.name ~= "ltex_plus") then
        -- defer to ensure client is already attached
        vim.defer_fn(function()
            vim.lsp.buf_detach_client(bufnr, client.id)
        end, 500)
    end
end

-- Mimics lspconfig.util.root_pattern
function M.root_pattern(...)
    local patterns = { ... }
    return function(fname)
        local filepath = fname or vim.api.nvim_buf_get_name(0)
        local dir = vim.fs.dirname(filepath)
        for _, pattern in ipairs(patterns) do
            local found = vim.fs.find(pattern, { upward = true, path = dir, type = "file" })
            if #found > 0 then
                return vim.fs.dirname(found[1])
            end
        end
        -- Fallback to git root or current directory
        return U.get_git_root() or dir
    end
end

return M
