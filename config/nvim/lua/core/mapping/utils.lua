local M = {}

function M.save_file()
    if vim.bo.readonly then
        return
    end
    local buftype = vim.bo.buftype
    if buftype == "nofile" or buftype == "prompt" then
        return
    end
    if vim.bo.modifiable then
        vim.cmd("w!")
    end
end

M.DAP_UI_ENABLED = false
function M.dap_toggle_ui()
    require("dapui").toggle()
    M.DAP_UI_ENABLED = not M.DAP_UI_ENABLED
end

function M.dap_float_scope()
    if not M.DAP_UI_ENABLED then
        return
    end
    require("dapui").float_element("scopes")
end

function M.toggle_diffview()
    local view = require("diffview.lib").get_current_view()
    if view then
        vim.cmd("DiffviewClose")
    else
        vim.cmd("DiffviewOpen")
    end
end

function M.delete_buffer()
    vim.cmd([[:bp | bdelete #]])
end

M.virtual_diagnostics = false
function M.toggle_virtual_diagnostics()
    M.virtual_diagnostics = not M.virtual_diagnostics
    vim.diagnostic.config({ virtual_text = M.virtual_diagnostics })
    vim.cmd("redrawstatus")
end

function M.format_buffer()
    -- Remove trailing whitespace.
    local cursor_position = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_exec([[%s/\s\+$//e]], false)
    vim.cmd("noh")
    vim.api.nvim_win_set_cursor(0, cursor_position)

    -- Try to format the buffer using the attached lsp.
    local status, _ = pcall(vim.lsp.buf.format)
    if not status then
        vim.notify("Format failed")
    end
end

function M.toggle_oil()
    local U = require("core.lib.utils")
    if U.current_buffer_filetype() == "oil" then
        pcall(vim.api.nvim_command, "b#")
    else
        vim.cmd("Oil")
    end
end

-- Function to copy the last error message to the system clipboard
function M.copy_last_error_message()
    -- Retrieve the entire message log
    local messages = vim.fn.execute("messages")

    -- Check for the last line (latest message)
    local last_message = vim.split(messages, "\n")
    last_message = last_message[#last_message]

    -- Copy the last message to the system clipboard
    vim.fn.setreg("+", last_message)
    vim.notify("Last error message copied to clipboard: " .. last_message, vim.log.levels.INFO)
end

-- Helper function to add 'desc' to keymap options (can also be moved here if you prefer)
function M.add_desc(opts, description)
    opts = opts or {}
    opts.desc = description
    return opts
end

local function map_with_mode(mode)
    return function(mappings, opts_in)
        local wk = require("which-key")
        local opts = vim.tbl_extend("force", opts_in or {}, { mode = mode })
        return wk.add(mappings, opts)
    end
end

M.wk = {
    add = function(key)
        return require("which-key").add(key)
    end,
}

M.nmap = map_with_mode("n")
M.imap = map_with_mode("i")
M.xmap = map_with_mode("x")
M.vmap = map_with_mode("v")
M.omap = map_with_mode("o")

--- Utility function to create a lazy-loaded keymap group based on an event
---@param group_name string: The name for the autocommand group
---@param trigger_event string|string[]: The Vim event(s) to trigger keymap loading
---@param keymap_loader_function function: Function to execute to load keymaps
M.lazy_keymap_group = function(group_name, trigger_event, keymap_loader_function)
    local group = vim.api.nvim_create_augroup(group_name, { clear = true })
    vim.api.nvim_create_autocmd(trigger_event, {
        group = group,
        callback = function()
            keymap_loader_function()
            vim.api.nvim_echo(
                {
                    {
                        "Keymappings loaded for group: "
                            .. group_name
                            .. " on event: "
                            .. trigger_event,
                        "NormalMsg",
                    },
                },
                false,
                {}
            )
            -- One-shot: delete the augroup after running.
            -- vim.api.nvim_del_augroup_by_name(group_name)
        end,
    })
end

---sets `buffer`, `silent` and `nowait` to true
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts? {desc?: string, unique?: boolean, buffer?: number|boolean, remap?: boolean, silent?:boolean, nowait?: boolean}
function M.bufKeymap(mode, lhs, rhs, opts)
    opts = vim.tbl_extend("force", { buffer = true, silent = true, nowait = true }, opts or {})
    vim.keymap.set(mode, lhs, rhs, opts)
end

---@param text string
---@param replace string
function M.bufAbbrev(text, replace)
    vim.keymap.set("ia", text, replace, { buffer = true })
end

function M.urlportal_function(url)
    -- Your actual logic to open URL, e.g., using vim.fn.system
    vim.fn.system('urlportal "' .. url .. '"')
end

function M.open_with_urlportal(url)
    local ok, result = pcall(M.urlportal_function, url)
    if ok and result == "" then
        vim.notify("Opened URL: " .. url .. " with urlportal (CLI)")
    elseif not ok then
        vim.notify("Error on urlportal with: " .. url, vim.log.levels.ERROR)
    end
    return ok
end

return M
