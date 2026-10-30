local M = {}

-- These modules bake palette hex values in at require-time, so they must be
-- evicted from package.loaded before every (re)apply or they replay stale colors.
local MODULES = { "core.hls.palette", "core.hls.nui", "core.hls.custom", "core.hls.borders" }

function M.load_highlight(groups)
    for hl, col in pairs(groups) do
        vim.api.nvim_set_hl(0, hl, col)
    end
end

-- Extra appliers (diagnostics, plugin overrides) that must re-run on every
-- reload. Each is called after the palette modules were evicted, so a fresh
-- require("core.hls.palette") inside it sees the new colors.
local extra = {}
function M.register(fn)
    extra[#extra + 1] = fn
    pcall(fn)
end

function M.load()
    for _, mod in ipairs(MODULES) do
        package.loaded[mod] = nil
    end
    for _, mod in ipairs({ "core.hls.nui", "core.hls.custom" }) do
        local ok, m = pcall(require, mod)
        if ok and m.hl then
            M.load_highlight(m.hl)
        elseif not ok then
            vim.notify("hls: " .. mod .. " failed: " .. tostring(m), vim.log.levels.WARN)
        end
    end
    for _, fn in ipairs(extra) do
        pcall(fn)
    end
    -- last: borders are derived from the panel colours everything above set
    pcall(function() require("core.hls.borders").apply() end)
end

function M.highlight(group, color)
    if color.style then
        for _, style in ipairs(color.style) do
            color[style] = true
        end
    end
    color.style = nil -- Remove style key after applying
    vim.api.nvim_set_hl(0, group, color)
end

function M.syntax(tbl)
    for group, colors in pairs(tbl) do
        M.highlight(group, colors)
    end
end

function M.events()
    require("core.hls.events")
end

return M
