-- Persistent view of external (Claude) edits: added lines tinted, removed
-- lines shown as virtual lines. Shimmer animates and fades; this stays until
-- dismissed. Diffs against the buffer as it was before the first external write.
local M = {}

local ns = vim.api.nvim_create_namespace("ai_changes")
local base, last, active, hunks = {}, {}, {}, {}
local MAX_DEL = 25

local function lines_of(buf)
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function text(lines)
    return #lines > 0 and (table.concat(lines, "\n") .. "\n") or ""
end

local function render(buf)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    hunks[buf] = nil
    if not active[buf] then
        return
    end
    local cur = lines_of(buf)
    local idx = vim.diff(text(base[buf]), text(cur), { result_type = "indices", algorithm = "histogram" })
    local found, add, del = {}, 0, 0
    for _, h in ipairs(idx) do
        local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
        add, del = add + cb, del + ca
        for l = sb, sb + cb - 1 do
            vim.api.nvim_buf_set_extmark(buf, ns, l - 1, 0, {
                line_hl_group = "AiChangeAdd",
                number_hl_group = "AiChangeAddNr",
                priority = 20,
            })
        end
        if ca > 0 then
            local virt = {}
            for i = sa, math.min(sa + ca - 1, sa + MAX_DEL - 1) do
                virt[#virt + 1] = { { "- " .. base[buf][i]:gsub("\t", "    "), "AiChangeDel" } }
            end
            if ca > MAX_DEL then
                virt[#virt + 1] = { { ("  … %d more removed"):format(ca - MAX_DEL), "AiChangeDel" } }
            end
            local row = cb > 0 and sb - 1 or sb -- deletion only: sb is the line before it
            local above = cb > 0 or row == 0
            vim.api.nvim_buf_set_extmark(buf, ns, math.max(row - (cb > 0 and 0 or 1), 0), 0, {
                virt_lines = virt,
                virt_lines_above = above,
                priority = 20,
            })
        end
        found[#found + 1] = math.max(cb > 0 and sb or sb, 1)
    end
    hunks[buf] = found
    vim.b[buf].ai_changes = (#found > 0) and ("+%d −%d"):format(add, del) or nil
    if #found == 0 then
        active[buf] = nil
    end
end

local function on_read(args)
    local buf = args.buf
    if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) == "" then
        return
    end
    local cur = lines_of(buf)
    if not last[buf] then
        base[buf] = cur
    elseif not vim.deep_equal(last[buf], cur) then
        active[buf] = true
    end
    last[buf] = cur
    render(buf)
end

function M.clear(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    active[buf] = nil
    base[buf] = lines_of(buf)
    last[buf] = base[buf]
    render(buf)
end

function M.jump(dir)
    local buf = vim.api.nvim_get_current_buf()
    local rows = hunks[buf]
    if not rows or #rows == 0 then
        return vim.notify("No external changes in this buffer", vim.log.levels.INFO)
    end
    local cur = vim.api.nvim_win_get_cursor(0)[1]
    local target
    if dir > 0 then
        for _, r in ipairs(rows) do
            if r > cur then target = r break end
        end
        target = target or rows[1]
    else
        for i = #rows, 1, -1 do
            if rows[i] < cur then target = rows[i] break end
        end
        target = target or rows[#rows]
    end
    vim.api.nvim_win_set_cursor(0, { math.min(target, vim.api.nvim_buf_line_count(buf)), 0 })
    vim.cmd("normal! zz")
end

function M.quickfix()
    local items = {}
    for buf, rows in pairs(hunks) do
        for _, r in ipairs(rows) do
            items[#items + 1] = {
                bufnr = buf,
                lnum = r,
                text = vim.api.nvim_buf_get_lines(buf, r - 1, r, false)[1] or "",
            }
        end
    end
    if #items == 0 then
        return vim.notify("No external changes", vim.log.levels.INFO)
    end
    vim.fn.setqflist({}, " ", { title = "External changes", items = items })
    vim.cmd("copen")
end

function M.setup()
    local g = vim.api.nvim_create_augroup("AiChanges", { clear = true })
    vim.api.nvim_create_autocmd("BufReadPost", { group = g, callback = on_read })
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = g,
        callback = function(args)
            last[args.buf] = lines_of(args.buf)
            if active[args.buf] then render(args.buf) end
        end,
    })
    vim.api.nvim_create_autocmd("BufWipeout", {
        group = g,
        callback = function(args)
            base[args.buf], last[args.buf], active[args.buf], hunks[args.buf] = nil, nil, nil, nil
        end,
    })
    -- Buffers already open when this loads.
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) then on_read({ buf = b }) end
    end

    vim.keymap.set("n", "]a", function() M.jump(1) end, { desc = "Next external change" })
    vim.keymap.set("n", "[a", function() M.jump(-1) end, { desc = "Prev external change" })
    vim.keymap.set("n", "<leader>ax", function() M.clear() end, { desc = "Dismiss external changes" })
    vim.keymap.set("n", "<leader>aq", M.quickfix, { desc = "External changes → quickfix" })
    vim.api.nvim_create_user_command("AiChangesClear", function() M.clear() end, {})
end

return M
