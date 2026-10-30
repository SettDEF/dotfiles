-- Centralised autocmd definitions.
--
-- Each function is scoped under its own augroup via the `augroup()` helper so
-- reloading this file clears the previous handlers. Behaviour that lives in
-- discrete plugin modules (snapshot, git polling, ai-pulse) stays in those
-- modules and is only wired in here.

local M = {}

local function augroup(name)
    return vim.api.nvim_create_augroup("alex_" .. name, { clear = true })
end

-- Highlight yanked text briefly.
vim.api.nvim_create_autocmd("TextYankPost", {
    group = augroup("highlight_yank"),
    callback = function()
        (vim.hl or vim.highlight).on_yank()
    end,
})

-- Resize splits when the terminal window is resized.
vim.api.nvim_create_autocmd("VimResized", {
    group = augroup("resize_splits"),
    callback = function()
        local current_tab = vim.fn.tabpagenr()
        vim.cmd("tabdo wincmd =")
        vim.cmd("tabnext " .. current_tab)
    end,
})

-- Return to the last cursor position when reopening a file (skip commits).
vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup("last_loc"),
    callback = function(event)
        local exclude = { "gitcommit", "gitrebase" }
        local buf = event.buf
        if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].last_loc then
            return
        end
        vim.b[buf].last_loc = true
        local mark = vim.api.nvim_buf_get_mark(buf, '"')
        local lcount = vim.api.nvim_buf_line_count(buf)
        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

-- Close specific filetypes with `q`.
vim.api.nvim_create_autocmd("FileType", {
    group = augroup("close_with_q"),
    pattern = {
        "PlenaryTestPopup", "checkhealth", "dbout", "gitsigns-blame",
        "grug-far", "help", "lspinfo", "notify", "qf", "spectre_panel",
        "startuptime", "tsplayground", "neotest-output", "neotest-summary",
        "neotest-output-panel",
    },
    callback = function(event)
        vim.bo[event.buf].buflisted = false
        vim.schedule(function()
            vim.keymap.set("n", "q", function()
                vim.cmd("close")
                pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
            end, { buffer = event.buf, silent = true, desc = "Quit buffer" })
        end)
    end,
})

-- Prune dead paths from v:oldfiles when nvim exits so the next launch has
-- a clean list written to shada. Alpha's theta MRU stats every oldfile on
-- render; stale paths (moved/deleted files, unmounted volumes) block the
-- UI thread for seconds when the shada list is dirty.
--
-- Guard against wiping the list in short-lived / headless sessions where
-- shada may not have been loaded — if there are zero entries we assume the
-- session never touched oldfiles and leave shada alone.
vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup("prune_oldfiles"),
    callback = function()
        local current = vim.v.oldfiles or {}
        if #current == 0 then return end
        local pruned = {}
        for _, f in ipairs(current) do
            if vim.fn.filereadable(f) == 1 then
                table.insert(pruned, f)
            end
        end
        vim.v.oldfiles = pruned
    end,
})

M.augroup = augroup
return M
