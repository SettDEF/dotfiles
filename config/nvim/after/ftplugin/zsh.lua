-- ABBREVIATIONS
local abbr = require("core.mapping.utils").bufAbbrev

abbr("//", "#")
abbr("delay", "sleep")
abbr("const", "local")
abbr("let", "local")
abbr("~=", "=~") -- lua uses `=~`
