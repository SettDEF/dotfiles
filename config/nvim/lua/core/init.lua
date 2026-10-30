-- Entry point. Load order matters.
require("core.config.options")
require("core.lazyload")
require("core.config")
require("core.mapping").global()
require("core.lib.snapshot")
require("core.lib.ai_pulse")
require("core.lib.ai_changes").setup()
