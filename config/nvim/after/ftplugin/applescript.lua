vim.bo.commentstring = "-- %s"
vim.opt_local.comments = { ":#", ":--" }

--------------------------------------------------------------------------------
-- ABBREVIATIONS
local abbr = require("core.mapping.utils").bufAbbrev

abbr("sleep", "delay")
abbr("//", "--")
