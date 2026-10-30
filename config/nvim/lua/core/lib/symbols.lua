local U = require("core.lib.utils")
local cached_signs = U.CachedDict:new(function(key)
    return vim.fn.sign_getdefined(key)[1].text ---@type string
end)

local define_signs = function(signs)
    for name, definition in pairs(signs) do
        vim.fn.sign_define(name, definition)
    end
end

return {
    signs = cached_signs,
    define_signs = define_signs,
}
