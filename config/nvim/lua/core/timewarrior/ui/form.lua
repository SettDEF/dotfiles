local config = require("core.timewarrior.config")
local parse = require("core.timewarrior.parse")
local cli = require("core.timewarrior.cli")
local echo = require("core.timewarrior.ui.echo")

local Popup = require("nui.popup")
local Layout = require("nui.layout")
local event = require("nui.utils.autocmd").event

local M = {}

local function default_backdate()
    local t = os.date("*t")
    local from_h = t.hour > 0 and (t.hour - 1) or 0
    return string.format("from %02d:%02d to %02d:%02d", from_h, t.min, t.hour, t.min)
end

local function popup(title)
    return Popup({
        enter = false,
        focusable = true,
        border = {
            style = "rounded",
            text = { top = " " .. title .. " ", top_align = "left" },
        },
        buf_options = { modifiable = true, readonly = false },
        -- Normal:NormalFloat (not Normal:Normal) so the border-row cells
        -- share the popup's interior background. Otherwise themes whose
        -- NormalFloat differs from Normal show a brighter halo around
        -- the border characters.
        win_options = { winblend = 0, winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder" },
    })
end

local function get_lines(buf)
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function set_lines(buf, lines)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

-- Tag picker helpers — toggle-on-cursor model.
-- Visual glyphs over text checkboxes; per-tag highlight from config.colors
-- when defined, otherwise Comment for unchecked and Special for checked.
local TAG_NS = vim.api.nvim_create_namespace("core.timewarrior.tags")
local GLYPH_ON = "▣"
local GLYPH_OFF = "▢"

local function render_tags(buf, all_tags, selected, freeform)
    local cfg_colors = require("core.timewarrior.config").get().colors or {}
    local lines = {}
    for i, t in ipairs(all_tags) do
        local glyph = selected[t] and GLYPH_ON or GLYPH_OFF
        -- Number prefix (1-9) so the keyboard shortcut is discoverable.
        local idx = i <= 9 and tostring(i) or " "
        table.insert(lines, string.format("%s  %s  %s", idx, glyph, t))
    end
    if freeform and freeform ~= "" then
        table.insert(lines, "+  ⊕  " .. freeform)
    end
    set_lines(buf, lines)

    -- Decorate: glyph color, label color, dim the digit prefix.
    vim.api.nvim_buf_clear_namespace(buf, TAG_NS, 0, -1)
    for i, t in ipairs(all_tags) do
        local row = i - 1
        local glyph_hl = selected[t] and "Special" or "Comment"
        local label_hl = cfg_colors[t] or (selected[t] and "Normal" or "Comment")
        -- digit prefix (cols 0-1) → Comment
        vim.api.nvim_buf_add_highlight(buf, TAG_NS, "Comment", row, 0, 3)
        -- glyph (col 3-6, Unicode glyph is 3 bytes) → glyph_hl
        vim.api.nvim_buf_add_highlight(buf, TAG_NS, glyph_hl, row, 3, 6)
        -- label (col 8 onward) → label_hl
        vim.api.nvim_buf_add_highlight(buf, TAG_NS, label_hl, row, 8, -1)
    end
end

-- mode: "start" | "track"
function M.open(mode, on_submit)
    local cfg = config.get()
    local backdate = popup("Backdate")
    local description = popup("Description")
    local tag = popup("Tag")

    local layout = Layout(
        {
            position = "50%",
            relative = "editor",
            size = {
                width = math.floor(vim.o.columns * cfg.popup.width),
                height = math.floor(vim.o.lines * cfg.popup.height),
            },
        },
        Layout.Box({
            Layout.Box(backdate, { size = "20%" }),
            Layout.Box(description, { size = "30%" }),
            Layout.Box(tag, { size = "50%" }),
        }, { dir = "col" })
    )

    set_lines(backdate.bufnr, { default_backdate() })
    set_lines(description.bufnr, { "" })

    local selected = {}
    render_tags(tag.bufnr, cfg.tags, selected, nil)
    vim.bo[tag.bufnr].modifiable = false

    local order = { backdate, description, tag }
    local index = 1
    local function focus(i)
        index = ((i - 1) % #order) + 1
        vim.api.nvim_set_current_win(order[index].winid)
    end

    local function close()
        layout:unmount()
    end

    local function submit()
        local bd_line = (get_lines(backdate.bufnr)[1] or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local desc_lines = get_lines(description.bufnr)
        local desc = table.concat(desc_lines, " "):gsub("^%s+", ""):gsub("%s+$", "")
        local tags = {}
        for t, on in pairs(selected) do
            if on then
                table.insert(tags, t)
            end
        end

        local payload = { tags = tags, description = desc }
        if mode == "track" then
            local parsed, err = parse.parse_backdate(bd_line)
            if not parsed then
                echo.show("Backdate parse error: " .. err)
                return
            end
            payload.from = parsed.from
            payload.to = parsed.to
        else
            -- start mode: only honour from if user changed default and only "from HH:MM" portion is needed
            local fh, fm = bd_line:match("from%s+(%d+):(%d+)")
            if fh then
                local now = os.date("*t")
                payload.from = string.format(
                    "%04d-%02d-%02dT%02d:%02d:00",
                    now.year,
                    now.month,
                    now.day,
                    tonumber(fh),
                    tonumber(fm)
                )
            end
        end

        close()
        if on_submit then
            on_submit(payload)
        end
    end

    -- Buffer-local maps shared by all three popups.
    local function bind(buf)
        local map = function(lhs, rhs)
            vim.keymap.set({ "n", "i" }, lhs, rhs, { buffer = buf, nowait = true, silent = true })
        end
        map("<Esc>", function()
            close()
        end)
        map("<C-CR>", function()
            submit()
        end)
        map("<C-Tab>", function()
            focus(index + 1)
        end)
        map("<Tab>", function()
            focus(index + 1)
        end)
        map("<S-Tab>", function()
            focus(index - 1)
        end)
    end

    layout:mount()
    bind(backdate.bufnr)
    bind(description.bufnr)
    bind(tag.bufnr)

    -- Tag-picker specific maps.
    local function rerender()
        vim.bo[tag.bufnr].modifiable = true
        render_tags(tag.bufnr, cfg.tags, selected, nil)
        vim.bo[tag.bufnr].modifiable = false
    end
    local function toggle_row(row)
        local t = cfg.tags[row]
        if not t then
            return
        end
        selected[t] = not selected[t]
        rerender()
        vim.api.nvim_win_set_cursor(0, { row, 0 })
    end

    -- <Space> and <CR>: toggle at cursor.
    vim.keymap.set("n", "<Space>", function()
        toggle_row(vim.api.nvim_win_get_cursor(0)[1])
    end, { buffer = tag.bufnr, silent = true })
    vim.keymap.set("n", "<CR>", function()
        toggle_row(vim.api.nvim_win_get_cursor(0)[1])
    end, { buffer = tag.bufnr, silent = true })

    -- 1-9: jump-toggle. Way faster than navigating with j/k.
    for i = 1, 9 do
        vim.keymap.set("n", tostring(i), function()
            toggle_row(i)
        end, { buffer = tag.bufnr, silent = true })
    end

    -- a / A: select all / clear all.
    vim.keymap.set("n", "a", function()
        for _, t in ipairs(cfg.tags) do
            selected[t] = true
        end
        rerender()
    end, { buffer = tag.bufnr, silent = true, desc = "Select all tags" })
    vim.keymap.set("n", "A", function()
        for _, t in ipairs(cfg.tags) do
            selected[t] = nil
        end
        rerender()
    end, { buffer = tag.bufnr, silent = true, desc = "Clear tag selection" })

    -- + : add a new tag inline (was `i` — freed up so `i` keeps its
    -- standard "enter insert" meaning in the description popup pattern).
    vim.keymap.set("n", "+", function()
        vim.ui.input({ prompt = "New tag: " }, function(t)
            if t and t ~= "" then
                table.insert(cfg.tags, t)
                selected[t] = true
                rerender()
            end
        end)
    end, { buffer = tag.bufnr, silent = true, desc = "Add new tag" })

    -- Auto-close when user clicks elsewhere (BufLeave on the layout's root).
    for _, p in ipairs(order) do
        p:on(event.BufLeave, function()
            vim.defer_fn(function()
                local cur = vim.api.nvim_get_current_buf()
                local in_form = false
                for _, q in ipairs(order) do
                    if q.bufnr == cur then
                        in_form = true
                        break
                    end
                end
                if not in_form then
                    close()
                end
            end, 50)
        end, { once = false })
    end

    focus(1)
end

return M
