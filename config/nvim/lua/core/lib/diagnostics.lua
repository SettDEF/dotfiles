local colors = require("core.lib.colors")

local severities = {
    vim.diagnostic.severity.ERROR,
    vim.diagnostic.severity.WARN,
    vim.diagnostic.severity.INFO,
    vim.diagnostic.severity.HINT,
}

--- Calls the given callback for each diagnostic severity.
--- @param callback fun(severity: number)
local function for_each_severity(callback)
    for _, severity in ipairs(severities) do
        callback(severity)
    end
end

-- Defaults used before the lazy-loaded diagnostic config runs
-- (heirline can call into these on the very first draw during :Lazy update,
-- while signs is still `true` / vim's default). Matches the glyph set
-- configured in core/lazyload/lang/diagnostic.lua.
local DEFAULT_SIGN_TEXT = {
    [vim.diagnostic.severity.ERROR] = " ",
    [vim.diagnostic.severity.WARN] = " ",
    [vim.diagnostic.severity.INFO] = " ",
    [vim.diagnostic.severity.HINT] = " ",
}
local DEFAULT_SIGN_NUMHL = {
    [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
    [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
    [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
    [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
}
local DEFAULT_SIGN_LINEHL = {
    [vim.diagnostic.severity.ERROR] = "DiagnosticLineError",
    [vim.diagnostic.severity.WARN] = "DiagnosticLineWarn",
    [vim.diagnostic.severity.INFO] = "DiagnosticLineInfo",
    [vim.diagnostic.severity.HINT] = "DiagnosticLineHint",
}

--- Returns the current diagnostic.config().signs table if it's actually a
--- table; otherwise nil (which callers treat as "use defaults").
local function signs_table()
    local cfg = vim.diagnostic.config()
    if cfg and type(cfg.signs) == "table" then
        return cfg.signs
    end
    return nil
end

--- @return string
local function sign(severity)
    local s = signs_table()
    local text = (s and type(s.text) == "table") and s.text or DEFAULT_SIGN_TEXT
    return text[severity] or DEFAULT_SIGN_TEXT[severity] or "•"
end

local function sign_hl(severity)
    local s = signs_table()
    local map = (s and type(s.numhl) == "table") and s.numhl or DEFAULT_SIGN_NUMHL
    local name = map[severity] or DEFAULT_SIGN_NUMHL[severity]
    return colors.hl[name]
end

local function line_hl(severity)
    local s = signs_table()
    local map = (s and type(s.linehl) == "table") and s.linehl or DEFAULT_SIGN_LINEHL
    local name = map[severity] or DEFAULT_SIGN_LINEHL[severity]
    return colors.hl[name]
end

---@type integer[][]
local buffer_diags = DynamicList:new({
    event = "DiagnosticChanged",
    update_fn = function(buffers, args)
        local diagnostics = args.data.diagnostics
        local diags = {}

        for _, diag in ipairs(diagnostics) do
            local current_severity = diags[diag.lnum + 1] or 4
            diags[diag.lnum + 1] = math.min(current_severity, diag.severity)
        end

        buffers[args.buf] = diags
    end,
})

return {
    for_each_severity = for_each_severity,
    sign = sign,
    sign_hl = sign_hl,
    line_hl = line_hl,
    buffer_diags = buffer_diags,
}
