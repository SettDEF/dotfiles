-- Written by the shell (Palette > Glass): blur settings and per-app window
-- rules, so they survive `hyprctl reload`. The two parts are separate files
-- because the shell re-sends them separately.
pcall(require, "lua.glass_blur")
pcall(require, "lua.glass_rules")
