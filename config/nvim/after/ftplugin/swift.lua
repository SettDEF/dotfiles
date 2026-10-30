-- formatters prescribe comments being separated by two spaces
vim.opt_local.listchars:append({ multispace = " " })

--------------------------------------------------------------------------------

local abbr = require("core.mapping.utils").bufAbbrev
abbr("--", "//")
abbr("local", "let")
abbr("const", "let")
