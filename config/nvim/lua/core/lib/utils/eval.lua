-- Smart selection runner.
--
-- Grab whatever's under the cursor (visual selection, or current line in
-- normal mode) and route it to the right interpreter:
--   :cmd    → vim command
--   !cmd    → shell command
--   $cmd    → shell command
-- Otherwise routed by buffer filetype (lua/python/node/sh/bash/zsh/...).
-- Falls back to lua for unknown filetypes so `some.var.path` prints its
-- value and `1 + 2` returns 3.
--
-- Bound to <leader>x in core.mapping.init (M.global).

local M = {}

-- ── selection capture ──────────────────────────────────────────────────────
-- Yank-into-register is the most portable way to get the visual selection
-- from inside a keymap callback: works for v / V / <C-v>, doesn't depend on
-- '< '> marks being set (they aren't yet when the callback fires from
-- visual mode), and preserves the user's registers.
local function get_selection()
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
        local saved = vim.fn.getreg("z")
        local saved_type = vim.fn.getregtype("z")
        vim.cmd('noautocmd normal! "zy')
        local text = vim.fn.getreg("z")
        vim.fn.setreg("z", saved, saved_type)
        return text
    end
    return vim.api.nvim_get_current_line()
end

-- ── output display ─────────────────────────────────────────────────────────
-- Short single-line output → notify. Anything larger → centered scratch
-- float. `q` / `<Esc>` closes it.
local function show(title, text)
    if text == nil then text = "" end
    if type(text) ~= "string" then text = vim.inspect(text) end
    text = text:gsub("\r\n", "\n"):gsub("[ \t\n]+$", "")
    if text == "" then
        vim.notify("(empty)", vim.log.levels.INFO, { title = title })
        return
    end
    local lines = vim.split(text, "\n", { plain = true })
    if #lines == 1 and #lines[1] <= 200 then
        vim.notify(lines[1], vim.log.levels.INFO, { title = title })
        return
    end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local width = math.min(120, math.floor(vim.o.columns * 0.7))
    local height = math.min(#lines + 1, math.floor(vim.o.lines * 0.6))
    vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        style = "minimal",
        border = "rounded",
        title = " " .. title .. " ",
        title_pos = "center",
    })
    vim.wo.wrap = true
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = buf, nowait = true, silent = true })
end

-- ── runners ────────────────────────────────────────────────────────────────
local function run_vim(text)
    local ok, out = pcall(vim.api.nvim_exec2, text, { output = true })
    show(ok and "vim" or "vim error", ok and out.output or tostring(out))
end

local function run_lua(text)
    -- Try expression form first so `1 + 2`, `vim.g.foo`, `require("x").y`
    -- print their value. Fall back to statement form for full chunks.
    local chunk, err = loadstring("return (" .. text .. "\n)")
    if not chunk then
        chunk, err = loadstring(text)
    end
    if not chunk then
        show("lua parse error", err or "?")
        return
    end
    local ok, result = pcall(chunk)
    if not ok then
        show("lua error", tostring(result))
        return
    end
    if result == nil then
        show("lua", "(no return value)")
    else
        show("lua", type(result) == "string" and result or vim.inspect(result))
    end
end

-- Run argv, capture both stdout and stderr, render them together so silently-
-- failing commands surface. Uses vim.system (nvim 0.10+); falls back to
-- systemlist with a 2>&1 shim if unavailable.
local function run_captured(argv, title)
    if vim.system then
        local result = vim.system(argv, { text = true }):wait()
        local out, err = result.stdout or "", result.stderr or ""
        local pieces = {}
        if out ~= "" then table.insert(pieces, (out:gsub("\n+$", ""))) end
        if err ~= "" then
            table.insert(pieces, "── stderr ──\n" .. (err:gsub("\n+$", "")))
        end
        local status = result.code or 0
        local final_title = status == 0 and title or (title .. " (exit " .. status .. ")")
        show(final_title, table.concat(pieces, "\n"))
    else
        local out = vim.fn.systemlist(argv)
        local status = vim.v.shell_error
        show(
            status == 0 and title or (title .. " (exit " .. status .. ")"),
            table.concat(out, "\n")
        )
    end
end

local function run_with(argv, title, text)
    argv = vim.list_extend(vim.deepcopy(argv), { text })
    run_captured(argv, title)
end

local function run_shell(text, shell)
    shell = shell
        or (vim.env.SHELL and vim.fn.fnamemodify(vim.env.SHELL, ":t"))
        or "sh"
    if vim.fn.executable(shell) == 0 then
        show("shell error", "shell not executable: " .. shell)
        return
    end
    run_captured({ shell, "-c", text }, shell)
end

local RUNNERS = {
    vim = run_vim,
    lua = run_lua,
    shell = function(t) run_shell(t) end,
    sh = function(t) run_shell(t, "sh") end,
    bash = function(t) run_shell(t, "bash") end,
    zsh = function(t) run_shell(t, "zsh") end,
    fish = function(t) run_shell(t, "fish") end,
    python = function(t) run_with({ "python3", "-c" }, "python", t) end,
    node = function(t) run_with({ "node", "-e" }, "node", t) end,
    ruby = function(t) run_with({ "ruby", "-e" }, "ruby", t) end,
    perl = function(t) run_with({ "perl", "-e" }, "perl", t) end,
    php = function(t) run_with({ "php", "-r" }, "php", t) end,
    typescript = function(t)
        if vim.fn.executable("tsx") == 1 then
            run_with({ "tsx", "-e" }, "tsx", t)
        else
            run_with({ "npx", "-y", "ts-node", "-e" }, "ts-node", t)
        end
    end,
}

-- ── mode detection ─────────────────────────────────────────────────────────
local FT_TO_MODE = {
    lua = "lua",
    vim = "vim",
    python = "python",
    sh = "sh",
    bash = "bash",
    zsh = "zsh",
    fish = "fish",
    javascript = "node",
    javascriptreact = "node",
    typescript = "typescript",
    typescriptreact = "typescript",
    ruby = "ruby",
    perl = "perl",
    php = "php",
}

local function detect(text, ft)
    local trimmed = vim.trim(text)
    if trimmed == "" then return nil, nil end
    local first = trimmed:sub(1, 1)
    if first == ":" then return "vim", trimmed:sub(2) end
    if first == "!" or first == "$" then return "shell", vim.trim(trimmed:sub(2)) end
    local ft_mode = FT_TO_MODE[ft]
    if ft_mode then return ft_mode, text end
    -- unknown filetype: guess from shape
    if trimmed:match("^[%w_.:%[%]\"'()]+$") then return "lua", trimmed end
    return "lua", text
end

-- ── public ─────────────────────────────────────────────────────────────────
function M.run(mode_override)
    local text = get_selection()
    if not text or vim.trim(text) == "" then
        vim.notify("eval: nothing to run", vim.log.levels.WARN)
        return
    end
    local mode, payload
    if mode_override then
        mode, payload = mode_override, text
    else
        mode, payload = detect(text, vim.bo.filetype)
    end
    local runner = RUNNERS[mode]
    if not runner then
        vim.notify("eval: no runner for `" .. tostring(mode) .. "`", vim.log.levels.ERROR)
        return
    end
    runner(payload)
end

function M.prompt()
    vim.ui.input({ prompt = "eval> " }, function(input)
        if not input or input == "" then return end
        local mode, payload = detect(input, vim.bo.filetype)
        if not mode then return end
        RUNNERS[mode](payload)
    end)
end

return M
