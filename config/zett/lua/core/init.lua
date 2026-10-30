-- Entry point: options first, then plugins and the theme, language servers, keys, autocommands.
require("core.config.options")
require("core.plugins")
require("core.lsp")
require("core.mapping")
require("core.config.autocmds")
