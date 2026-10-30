local M = {}

function M.check()
    local h = vim.health
    h.start("core.timewarrior")

    local cmd = require("core.timewarrior.config").get().cmd or "timew"
    if vim.fn.executable(cmd) == 1 then
        local ver = vim.fn.system({ cmd, "--version" }):gsub("\n", " ")
        h.ok("`" .. cmd .. "` found (" .. ver .. ")")
    else
        h.error("`" .. cmd .. "` not found on $PATH")
    end

    for _, mod in ipairs({ "nui.popup", "nui.layout", "nui.menu", "plenary.job" }) do
        local ok = pcall(require, mod)
        if ok then
            h.ok(mod .. " available")
        else
            h.error(mod .. " missing")
        end
    end
end

return M
