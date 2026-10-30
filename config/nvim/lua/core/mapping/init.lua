local M = {}
local U = require("core.mapping.utils")
local n, i, v, t = "n", "i", "v", "t"
local ex_t = { n, i, v }
local n_v = { n, v }
local keymap = vim.keymap.set
local silent = { noremap = true, silent = true }
local opts = { noremap = true, silent = true, nowait = true }

-- Module-level utility functions
local function add_desc(options, description)
    return vim.tbl_extend("force", options or {}, { desc = description })
end

local function send_tmux_command(command)
    local ok, result = pcall(vim.fn.system, "tmux " .. command)
    if not ok then
        vim.notify("Error sending tmux command: " .. command, vim.log.levels.ERROR)
        return nil
    end
    return result
end

local function is_markdown()
    return vim.bo.filetype == "markdown"
end

local function is_tmux_pane()
    return vim.api.nvim_eval("exists('$TMUX')") == 1
end

-- Conditional keymap helper
local function conditional_keymap(
    modes,
    lhs,
    rhs,
    desc_options,
    condition,
    fallback_rhs,
    insert_rhs
)
    local bind = function()
        if condition == nil or condition() then
            if type(rhs) == "function" then
                return rhs()
            else
                keymap(modes, lhs, rhs, desc_options)
                return true
            end
        elseif vim.api.nvim_get_mode().mode == "i" and insert_rhs then
            keymap("i", lhs, insert_rhs, desc_options)
            return true
        elseif fallback_rhs then
            keymap(modes, lhs, fallback_rhs, desc_options)
            return true
        end
        return false
    end
    bind()
end

-- Neotree
M.neotree = function()
    keymap(n, "<leader>e", "<CMD>Neotree toggle<CR>", add_desc(opts, "Toggle Neotree"))
end

-- Telescope
M.telescope = function()
    keymap(n, "<leader>ff", "<CMD>Telescope find_files<CR>", add_desc(opts, "Find files"))
    keymap(n, "<leader>fg", "<CMD>Telescope live_grep<CR>", add_desc(opts, "Live grep"))
    keymap(n, "<leader>fb", "<CMD>Telescope buffers<CR>", add_desc(opts, "List buffers"))
end

-- Colorizer
M.colorizer = function()
    keymap(
        n,
        "<Leader>ch",
        ":lua require('nvim-highlight-colors').toggle()<CR>",
        add_desc(opts, "Toggle highlight colors")
    )
end

-- Completion
M.completion = function()
    local cmpstatus, cmp = pcall(require, "cmp")
    local snipstatus, luasnip = pcall(require, "luasnip")
    if snipstatus and cmpstatus then
        cmp.setup({
            mapping = {
                ["<CR>"] = cmp.mapping.confirm({ select = true }),
                ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
                ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
                ["<C-f>"] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i", "c" }),
                ["<C-b>"] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i", "c" }),
                ["<C-e>"] = cmp.mapping({
                    i = cmp.mapping.abort(),
                    c = cmp.mapping.close(),
                }),
                ["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
                --["<Tab>"] = cmp.mapping(function(fallback)
                --	if cmp.visible() then
                --		cmp.select_next_item()
                --	elseif luasnip.expand_or_jumpable() then
                --			luasnip.expand_or_jump()
                --else
                --			fallback()
                --		end
                --	end, { "i", "s" }),
                ["<S-Tab>"] = cmp.mapping(function(fallback)
                    if cmp.visible() then
                        cmp.select_prev_item()
                    elseif luasnip.jumpable(-1) then
                        luasnip.jump(-1)
                    else
                        fallback()
                    end
                end, { "i", "s" }),
                ["<C-l>"] = cmp.mapping(function(fallback)
                    if cmp.visible() and cmp.get_active_entry() then
                        cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })
                    else
                        fallback()
                    end
                end, { "i", "s" }),
                ["<C-y>"] = cmp.mapping(function()
                    if cmp.visible() then
                        cmp.confirm({ select = true })
                        vim.api.nvim_feedkeys(
                            vim.api.nvim_replace_termcodes("<C-Space>", true, true, true),
                            n,
                            true
                        )
                    end
                end, { "i", "s" }),
            },
        })
    end
end

-- Load core keymaps only; plugin keymaps are handled by lazy.nvim
function M.global()
    -- Core keymaps not tied to plugins
    -- Window navigation
    keymap(n, "<C-h>", "<C-w>h", add_desc(opts, "Move to left window"))
    keymap(n, "<C-j>", "<C-w>j", add_desc(opts, "Move to down window"))
    keymap(n, "<C-k>", "<C-w>k", add_desc(opts, "Move to up window"))
    keymap(n, "<C-l>", "<C-w>l", add_desc(opts, "Move to right window"))
    keymap(n, "<leader>h", "<C-w>h", add_desc(opts, "Move to left window"))
    keymap(n, "<leader>j", "<C-w>j", add_desc(opts, "Move to down window"))
    keymap(n, "<leader>k", "<C-w>k", add_desc(opts, "Move to up window"))
    keymap(n, "<leader>l", "<C-w>l", add_desc(opts, "Move to right window"))

    -- Scrolling
    keymap(n, "<C-d>", "<C-d>zz", add_desc(opts, "Move down half page and center cursor"))
    keymap(n, "<C-u>", "<C-u>zz", add_desc(opts, "Move up half page and center cursor"))

    -- Folding
    keymap(n, "<leader>zc", "zc", add_desc(opts, "Close fold under cursor"))
    keymap(n, "<leader>zo", "zo", add_desc(opts, "Open fold under cursor"))
    keymap(n, "<leader>za", "za", add_desc(opts, "Toggle fold under cursor"))
    keymap(n, "<leader>zR", "zR", add_desc(opts, "Open all folds"))
    keymap(n, "<leader>zM", "zM", add_desc(opts, "Close all folds"))
    keymap(n, "<leader>zj", "zj", add_desc(opts, "Move to next fold"))
    keymap(n, "<leader>zk", "zk", add_desc(opts, "Move to previous fold"))

    -- Window splitting
    keymap(n, "<leader>sv", "<C-w>v", add_desc(opts, "Split window vertically"))
    keymap(n, "<leader>sh", "<C-w>s", add_desc(opts, "Split window horizontally"))
    keymap(n, "<leader>se", "<C-w>=", add_desc(opts, "Equalize window sizes"))
    keymap(n, "<leader>sx", ":close<CR>", add_desc(opts, "Close current window"))

    -- Resizing
    keymap(n, "<leader>+", ":resize +2<CR>", add_desc(opts, "Increase window height"))
    keymap(n, "<leader>-", ":resize -2<CR>", add_desc(opts, "Decrease window height"))
    keymap(n, "<leader><", ":vertical resize -2<CR>", add_desc(opts, "Decrease window width"))
    keymap(n, "<leader>>", ":vertical resize +2<CR>", add_desc(opts, "Increase window width"))

    -- Text manipulation
    keymap(n, "<A-j>", ":m .+1<CR>==", add_desc(opts, "Move line down"))
    keymap(n, "<A-k>", ":m .-2<CR>==", add_desc(opts, "Move line up"))
    keymap("i", "<A-j>", "<Esc>:m .+1<CR>==gi", add_desc(opts, "Move line down (Insert)"))
    keymap("i", "<A-k>", "<Esc>:m .-2<CR>==gi", add_desc(opts, "Move line up (Insert)"))
    keymap("v", "<A-j>", ":m '>+1<CR>gv=gv", add_desc(opts, "Move selection down"))
    keymap("v", "<A-k>", ":m '<-2<CR>gv=gv", add_desc(opts, "Move selection up"))
    keymap("v", "J", ":m '>+1<CR>gv=gv", add_desc(opts, "Move line down in visual mode"))
    keymap("v", "K", ":m '<-2<CR>gv=gv", add_desc(opts, "Move line up in visual mode"))

    -- Yank
    keymap(n, "Y", "y$", add_desc(opts, "Yank to end of line"))
    keymap({ n, "v" }, "<leader>y", '"+y', add_desc(opts, "Yank to system clipboard"))
    keymap("i", "kj", "<ESC>", add_desc(opts, "Exit insert mode with kj"))

    -- Join lines
    keymap(n, "J", "mzJ`z", add_desc(opts, "Join lines without moving cursor"))

    -- Search
    keymap(n, n, "nzzzv", add_desc(opts, "Center search result (next)"))
    keymap(n, n, "Nzzzv", add_desc(opts, "Center search result (previous)"))

    -- Save & Quit
    -- keymap(n, "<leader>s", ":w<CR>", add_desc(opts, "Save"))
    keymap("i", "<C-s>", "<ESC>:w<CR>a", add_desc(opts, "Save (Insert)"))
    keymap(n, "<leader>q", ":qa!<CR>", add_desc(opts, "Force quit all"))

    -- Buffers
    keymap(n, "<C-S-j>", ":bnext<CR>", add_desc(opts, "Next buffer"))
    keymap(n, "<C-S-k>", ":bprevious<CR>", add_desc(opts, "Previous buffer"))
    keymap(n, "<leader>bd", ":bdelete<CR>", add_desc(opts, "Delete buffer"))
    keymap(n, "<leader>br", ":edit!<CR>", add_desc(opts, "Reload buffer"))

    -- Tabs
    -- keymap(n, '<Tab>', ':tabnext<CR>', add_desc(opts, "tabnest"))
    -- keymap(n, '<S-Tab>', ':tabprevious<CR>', add_desc(opts, "tabprevious"))
    keymap(n, "<A-p>", ":tabnext<CR>", opts)
    keymap(n, "<A-n>", ":tabprev<CR>", opts)

    -- File operations
    keymap(n, "<leader>ww", ":w<CR>", add_desc(opts, "Write current file"))

    -- Tmux integration
    keymap(n, "<leader>tp", function()
        local file_dir = vim.fn.expand("%:p:h")
        local escaped_dir = file_dir:gsub("'", "'\\''")
        local pane_width = 60
        local has_panes = vim.fn.system("tmux list-panes | wc -l"):gsub("%s+", "") ~= "1"
        if not has_panes then
            vim.fn.system(
                "tmux split-window -h -l "
                    .. pane_width
                    .. " 'cd \""
                    .. escaped_dir
                    .. "\" && DISABLE_PULL=1 zsh'"
            )
            vim.fn.system("tmux send-keys C-l")
        else
            vim.notify("Tmux pane already created", vim.log.levels.INFO)
        end
    end, add_desc(opts, "Create a tmux pane on the same directory"))

    keymap("n", "<leader>cb", function()
        local file = vim.fn.expand("%")
        local first_line = vim.fn.getline(1)
        if string.match(first_line, "^#!/") then
            local escaped_file = vim.fn.shellescape(file)
            vim.cmd(
                "silent !tmux split-window -h -l 60 'bash -c \""
                    .. escaped_file
                    .. "; echo; echo Press enter to exit...; read _\"'"
            )
        else
            vim.cmd("echo 'Not a script. Shebang line not found.'")
        end
    end, add_desc(opts, "BASH, execute file"))

    -- FIX: It's not finding a pane
    -- keymap({ n, "v", "i", "t" }, "<leader><space>", function()
    -- 	local ok, result = pcall(vim.fn.systemlist, "tmux display-message -p '#{pane_id}'")
    -- 	if not ok then
    -- 		return
    -- 	end
    -- 	if result and #result > 0 then
    -- 		local pane_id = result[1]
    -- 		if pane_id then
    -- 			local ok, result = pcall(vim.fn.systemlist, "tmux list-panes -F '#{pane_id} #{pane_active}'")
    -- 			if ok and result then
    -- 				local found_pane = nil
    -- 				for _, line in ipairs(result) do
    -- 					local id, active = line:match("(%@+) (%d+)")
    -- 					if active == "1" and not string.match(id, pane_id) then
    -- 						found_pane = id
    -- 					end
    -- 					if not found_pane then
    -- 						found_pane = id
    -- 					end
    -- 				end
    -- 				send_tmux_command("select-pane -t " .. found_pane)
    -- 			end
    -- 		end
    -- 	else
    -- 		local file_dir = vim.fn.expand("%:p:h")
    -- 		local pane_width = 60
    -- 		local escaped_dir = file_dir:gsub("'", "'\\''")
    -- 		vim.fn.system(
    -- 			"tmux split-window -h -l " .. pane_width .. " 'cd \"" .. escaped_dir .. "\" && DISABLE_PULL=1 zsh'"
    -- 		)
    -- 		vim.fn.system("tmux send-keys C-l")
    -- 	end
    -- end, add_desc(opts, "Go to tmux"))

    -- Markdown-specific keymaps (example, simplified)
    conditional_keymap(n, "<leader>md", function()
        if is_markdown() then
            local cursor_pos = vim.api.nvim_win_get_cursor(0)
            local current_buffer = vim.api.nvim_get_current_buf()
            local start_row = cursor_pos[1] - 1
            local line =
                vim.api.nvim_buf_get_lines(current_buffer, start_row, start_row + 1, false)[1]
            if line:match("^%s*%-") then
                line = line:gsub("^%s*%-", "")
            else
                line = "- " .. line
            end
            vim.api.nvim_buf_set_lines(current_buffer, start_row, start_row + 1, false, { line })
        end
    end, add_desc(opts, "Toggle bullet point (dash)"), is_markdown)

    -- Toggle executable permission
    keymap(n, "<leader>fx", function()
        local file = vim.fn.expand("%")
        local perms = vim.fn.getfperm(file)
        local is_executable = string.match(perms, "x", -1) ~= nil
        local escaped_file = vim.fn.shellescape(file)
        if is_executable then
            vim.cmd("silent !chmod -x " .. escaped_file)
            vim.notify("Removed executable permission", vim.log.levels.INFO)
        else
            vim.cmd("silent !chmod +x " .. escaped_file)
            vim.notify("Added executable permission", vim.log.levels.INFO)
        end
    end, add_desc(opts, "Toggle executable permission"))

    -- Go to the beginning/end of the line
    keymap(n, "gh", "^", add_desc(opts, "Go to the beginning of the line"))
    keymap(n, "gl", "$", add_desc(opts, "Go to the end of the line"))
    keymap("v", "gl", "$h", add_desc(opts, "Go to the end of the line"))

    -- Go to the beginning/end of the line in normal and visual modes
    keymap({ n, "v" }, "gh", "^", add_desc(opts, "Go to the beginning of the line"))
    keymap({ n, "v" }, "gl", "$", add_desc(opts, "Go to the end of the line"))

    -- Copy file path to clipboard
    keymap({ n, "v", "i" }, "<M-c>", function()
        local filePath = vim.fn.expand("%:~")
        vim.fn.setreg("+", filePath)
        vim.notify(filePath, vim.log.levels.INFO)
        vim.notify("Path copied to clipboard: ", vim.log.levels.INFO)
    end, add_desc(opts, "Copy file path to clipboard"))

    -- Open current file in Neovide
    keymap(n, "<leader>fN", function()
        local file_path = vim.fn.expand("%:p")
        if file_path ~= "" then
            local command = "neovide " .. vim.fn.shellescape(file_path)
            vim.fn.system(command)
            print("Opened file in Neovide: " .. file_path)
        else
            print("No file is currently open")
        end
    end, add_desc(opts, "Open current file in Neovide"))

    -- Smart eval: one keymap, auto-routes the current selection (or current
    -- line in normal mode) based on the buffer's filetype — lua/python/sh/
    -- bash/zsh/node/ruby/... A leading `:` forces vim command, leading `!`
    -- or `$` forces shell. See lua/core/lib/utils/eval.lua.
    keymap({ n, v }, "<leader>x", function()
        require("core.lib.utils.eval").run()
    end, add_desc(opts, "Smart eval (auto by filetype)"))

    keymap(n, "gx", function()
        local line = vim.api.nvim_get_current_line()
        local image_pattern = "%[.-%]%((.-)%)"
        local url_pattern = "https?://[^ ,;'\"<>%s)]*"
        local _, _, image_path = string.find(line, image_pattern)
        local s, e = string.find(line, url_pattern)

        if image_path and not string.sub(image_path, 1, 4) == "http" then
            vim.cmd("normal! <leader>io")
        elseif s and e then
            local url = string.sub(line, s, e)
            if not U.open_with_urlportal(url) then
                vim.notify("Could not open URL: " .. url, vim.log.levels.ERROR)
            end
        else
            vim.notify("No link or local image found under cursor", vim.log.levels.WARN)
        end
    end, add_desc(opts, "Open URL or Image with the default command"))

    keymap(n, "<leader>gu", function()
        local line = vim.api.nvim_get_current_line()
        local pattern = "https?://[^ ,;'\"><>%s)]*"
        local s, e = string.find(line, pattern)
        if s and e then
            local url = string.sub(line, s, e)
            if not open_url_with_urlportal(url) then
                vim.notify("Could not open URL: " .. url, vim.log.levels.ERROR)
            end
        else
            print("No URL found under cursor")
        end
    end, add_desc(opts, "Open URL with urlportal"))
end

return M
