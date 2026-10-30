local U = require("core.lib.utils")

if not U.in_home_dir("TSN") and not U.in_dir("/app") then
    return {}
end

local C = require("lazyload.lang.lsp.config")

local script_file = "docker_image_runner.sh"

local function get_docker_path()
    local possible_dirs = { "/docker", "/../docker", "/../../docker" }
    local curr_dir = U.current_dir_abs()

    for _, dir in ipairs(possible_dirs) do
        local script_abs = curr_dir .. dir .. "/" .. script_file
        if U.file_exists(script_abs) then
            return curr_dir .. dir
        end
    end

    return nil
end

local function get_lsp_command()
    local docker_path = get_docker_path()
    local timeout_ms = 150
    if not docker_path then
        vim.defer_fn(function()
            vim.notify("Could not find TSN docker script for lsp", vim.log.levels.WARN)
        end, timeout_ms)
        return nil
    else
        vim.defer_fn(function()
            vim.notify('Using docker @ "' .. docker_path .. '/"', vim.log.levels.INFO)
        end, timeout_ms)
    end

    local suffix = "box4dev"
    local repos = {
        "tsnsystems_ipc",
        "tsnsystems_utils",
    }
    local curr_dir = U.current_dir_abs()
    for _, repo in ipairs(repos) do
        if string.find(curr_dir, repo) then
            suffix = repo
        end
    end

    return {
        docker_path .. "/" .. script_file,
        docker_path .. "/../docker.configs/" .. "Dockerfile." .. suffix,
        "--lsp",
        "clangd",
        "--background-index",
        "--path-mappings=" .. U.get_git_root():gsub("/$", "") .. "=/app/dev",
    }
end

local cmd = get_lsp_command()
vim.lsp.config.clangd = {
    cmd = cmd,
    capabilities = C.capabilities,
    init_options = { lsp_flags = C.lsp_flags },
    root_markers = { "compile_commands.json" },
    filetypes = { "c", "cpp", "objc", "objcpp" },
}

vim.lsp.enable("clangd")
