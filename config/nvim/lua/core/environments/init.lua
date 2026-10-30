local M = {}

M.should_setup = true

function M.init()
    -- Editor specific configs.
    if vim.g.vscode then
        require("core.environments.vscode")
        M.should_setup = false
        return
    end

    -- Setup environment variables.
    local U = require("core.lib.utils.fn")
    local env_file = os.getenv("HOME") .. "/.private/nvim_env.lua"
    if U.file_exists(env_file) then
        vim.cmd("luafile " .. env_file)
    end

    -- This makes neovim load faster.
    vim.loader.enable()

    if vim.g.neovide then
        require("core.environments.neovide")
        return
    end

    -- Fallback: assume wezterm — every other supported env is caught above.
    require("core.environments.wezterm")
end

M.init()

return M
