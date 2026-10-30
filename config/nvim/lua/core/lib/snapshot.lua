-- Auto-init a hidden git repo in non-git directories so gitsigns / neo-tree's
-- git_status / fugitive / gitlinker all "just work" for tracking Claude's (or
-- any external tool's) edits.
--
-- The actual .git lives outside the project under stdpath('state')/snapshots/
-- keyed by a hash of the project path; the project dir gets a `.git` file
-- pointing at it. Use :SnapshotInit / :SnapshotCleanup to manage.

local M = {}

local STATE_DIR = vim.fn.stdpath("state") .. "/snapshots"

-- Directories where auto-init must never run. Stops accidental tracking of
-- $HOME, system roots, scratch dirs.
local UNSAFE = {
    [vim.env.HOME or ""] = true,
    ["/"] = true,
    ["/tmp"] = true,
    ["/var"] = true,
    ["/etc"] = true,
    ["/usr"] = true,
    ["/opt"] = true,
    ["/root"] = true,
}

local function is_unsafe(dir)
    return UNSAFE[dir] == true
end

local function is_git_repo(dir)
    local out = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--is-inside-work-tree" })
    return vim.v.shell_error == 0 and out[1] == "true"
end

local function hash_path(p)
    return vim.fn.sha256(p):sub(1, 16)
end

local function hidden_dir(cwd)
    return STATE_DIR .. "/" .. hash_path(cwd)
end

local function refresh_tools()
    pcall(function()
        require("gitsigns").refresh()
    end)
    pcall(vim.cmd, "Neotree refresh")
end

---@param opts? { silent?: boolean }
function M.init(opts)
    opts = opts or {}
    local cwd = vim.fn.getcwd()

    if is_unsafe(cwd) then
        vim.notify("Snapshot: refusing to init in " .. cwd, vim.log.levels.WARN)
        return
    end
    if is_git_repo(cwd) then
        if not opts.silent then
            vim.notify("Snapshot: already a git repo", vim.log.levels.INFO)
        end
        return
    end

    local hidden = hidden_dir(cwd)
    vim.fn.mkdir(hidden, "p")

    vim.fn.system({ "git", "init", "--separate-git-dir=" .. hidden, cwd })
    if vim.v.shell_error ~= 0 then
        vim.notify("Snapshot: git init failed", vim.log.levels.ERROR)
        return
    end

    -- Local identity so commits don't fail if global user.email is missing.
    vim.fn.system({ "git", "-C", cwd, "config", "user.email", "snapshot@local" })
    vim.fn.system({ "git", "-C", cwd, "config", "user.name", "Snapshot" })
    -- Skip hooks; we don't want pre-commit etc. from other repos to fire.
    vim.fn.system({ "git", "-C", cwd, "config", "core.hooksPath", "/dev/null" })

    vim.fn.system({ "git", "-C", cwd, "add", "-A" })
    vim.fn.system({
        "git",
        "-C",
        cwd,
        "commit",
        "-m",
        "snapshot: initial",
        "--allow-empty",
        "--quiet",
    })

    refresh_tools()
    if not opts.silent then
        vim.notify("Snapshot: initialized at " .. cwd, vim.log.levels.INFO)
    end
end

function M.cleanup()
    local cwd = vim.fn.getcwd()
    local pointer = cwd .. "/.git"
    -- Only delete if it's a file (separate-git-dir pointer), not a real .git dir.
    if vim.fn.filereadable(pointer) == 1 and vim.fn.isdirectory(pointer) == 0 then
        vim.fn.delete(pointer)
    end
    vim.fn.delete(hidden_dir(cwd), "rf")
    refresh_tools()
    vim.notify("Snapshot: cleaned up", vim.log.levels.INFO)
end

-- Re-snapshot the current state as the new baseline (clears all "modified"
-- markers, effectively saying "this is the new starting point").
function M.rebase()
    local cwd = vim.fn.getcwd()
    if not is_git_repo(cwd) then
        vim.notify("Snapshot: not initialized here; run :SnapshotInit", vim.log.levels.WARN)
        return
    end
    vim.fn.system({ "git", "-C", cwd, "add", "-A" })
    vim.fn.system({
        "git",
        "-C",
        cwd,
        "commit",
        "-m",
        "snapshot: rebase",
        "--allow-empty",
        "--quiet",
    })
    refresh_tools()
    vim.notify("Snapshot: new baseline committed", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("SnapshotInit", function()
    M.init()
end, {
    desc = "Create a hidden git repo so file changes show up in gitsigns / neo-tree",
})
vim.api.nvim_create_user_command("SnapshotCleanup", M.cleanup, {
    desc = "Remove the hidden snapshot repo for this project",
})
vim.api.nvim_create_user_command("SnapshotRebase", M.rebase, {
    desc = "Re-snapshot current state as the new baseline",
})

-- Hybrid auto-snapshot: only fire when a recognized project-marker file lives
-- in the cwd, so we never silently snapshot random scratch dirs but we DO get
-- tracking the moment you cd into a real project.
local PROJECT_MARKERS = {
    "package.json",
    "pyproject.toml",
    "Cargo.toml",
    "go.mod",
    "Gemfile",
    "build.gradle",
    "pom.xml",
    "Makefile",
    "CMakeLists.txt",
    "flake.nix",
    "shell.nix",
    "Pipfile",
    "poetry.lock",
    "requirements.txt",
    ".editorconfig",
    ".eslintrc",
    ".eslintrc.js",
    ".eslintrc.json",
    "tsconfig.json",
    "deno.json",
    "bun.lockb",
    "mix.exs",
    ".claude",
    ".cursor",
    ".aider", -- explicit AI-coding markers
}

local function has_project_marker(dir)
    for _, name in ipairs(PROJECT_MARKERS) do
        if
            vim.fn.filereadable(dir .. "/" .. name) == 1
            or vim.fn.isdirectory(dir .. "/" .. name) == 1
        then
            return true
        end
    end
    return false
end

local autoinit_group = vim.api.nvim_create_augroup("CoreSnapshotAuto", { clear = true })
local function maybe_auto_init()
    local cwd = vim.fn.getcwd()
    if is_unsafe(cwd) then
        return
    end
    if is_git_repo(cwd) then
        return
    end
    if not has_project_marker(cwd) then
        return
    end
    M.init({ silent = true })
end

vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
    group = autoinit_group,
    callback = function()
        vim.schedule(maybe_auto_init)
    end,
})

return M
