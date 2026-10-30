local CMP = require("cmp")
local UC = require("core.lib.utils.chars")

-- Main.
local sources = CMP.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "path" },
    { name = "crates" },
    { name = "async_path", priority = 30, group_index = 5 },
    { name = "calc", priority = 10, group_index = 9 },
    {
        name = "buffer",
        max_item_count = 5,
        keyword_length = 2,
        priority = 50,
        entry_filter = function(entry)
            return not entry.exact
        end,
        option = {
            -- Index all loaded buffers but skip very large ones, so buffer
            -- completion stays fast in big sessions.
            get_bufnrs = function()
                local bufs = {}
                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_loaded(buf) then
                        local bytes =
                            vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf))
                        if bytes > 0 and bytes < 1024 * 1024 then
                            bufs[buf] = true
                        end
                    end
                end
                return vim.tbl_keys(bufs)
            end,
        },
        group_index = 4,
    },
    {
        name = "emoji",
        priority = 10,
        group_index = 9,
        entry_filter = function()
            if vim.bo.filetype ~= "gitcommit" then
                return false
            end
            return true
        end,
    },
    {
        name = "cmp_yanky",
        option = {
            -- only suggest items which match the current filetype
            -- onlyCurrentFiletype = false,
            -- only suggest items with a minimum length
            -- minLength = 3,
        },
    },
    -- {
    -- 	name = "fish",
    -- 	priority = 10,
    -- 	group_index = 9,
    -- 	entry_filter = function()
    -- 		if vim.bo.filetype ~= "gitcommit" then
    -- 			return false
    -- 		end
    -- 		return true
    -- 	end,
    -- },
    {
        name = "rg",
        keyword_length = 5,
        max_item_count = 5,
        option = {
            additional_arguments = "--smart-case --hidden",
        },
        priority = 80,
        group_index = 3,
    },
})
local snippet = {
    expand = function(args)
        require("luasnip").lsp_expand(args.body)
    end,
}
CMP.setup({
    sources = sources,
    snippet = snippet,
})

-- Tex.
local tex = {
    sources = {
        { name = "nvim_lsp" },
        -- { name = "luasnip" },
        { name = "latex_symbols" },
    },
}
CMP.setup.filetype({ "tex", "latex" }, tex)

-- Cmdline.
local cmdline_window = {
    completion = CMP.config.window.bordered({
        winhighlight = "Normal:None,FloatBorder:None,Search:None",
        scrollbar = true,
        border = UC.get_border_chars("cmdline"),
        col_offset = -4,
        side_padding = 0,
    }),
}
local cmdline = {
    window = cmdline_window,
    mapping = CMP.mapping.preset.cmdline(),
    sources = CMP.config.sources({
        { name = "cmdline" },
        { name = "cmdline_history", history_type = ":", priority = 10 },
        { name = "path" },
    }),
}
CMP.setup.cmdline({ ":", ":!" }, cmdline)

-- Search.
local search_window = {
    completion = CMP.config.window.bordered({
        winhighlight = "Normal:Pmenu,FloatBorder:SpecialCmpBorder,Search:None",
        scrollbar = true,
        border = UC.get_border_chars("search"),
        col_offset = -1,
        side_padding = 0,
    }),
}
local search = {
    window = search_window,
    mapping = CMP.mapping.preset.cmdline(),
    sources = CMP.config.sources({ { name = "buffer" } }),
}
CMP.setup.cmdline({ "/", "?" }, search)

require("core.mapping").completion()
