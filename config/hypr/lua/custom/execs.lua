-- converted from custom/execs.conf


-- ── from custom/execs.conf ──────────────────────────────
hl.exec_cmd("~/.config/hypr/hyprland/scripts/sync-kde-theme.sh")
autostart("watch-kde-theme", "~/.config/hypr/hyprland/scripts/watch-kde-theme.sh", true)
autostart("python3", "python3 ~/.scripts/apps/browser/gravity_drop.py", true)
autostart("lua", "lua ~/.config/hypr/hyprland/scripts/monitor-overlap-watch.lua", true)
autostart("lua", "lua ~/.config/hypr/hyprland/scripts/cursor-follow-workspace.lua", true)
autostart("clip-x11-bridge", "~/.config/hypr/custom/scripts/clip-x11-bridge", true)
