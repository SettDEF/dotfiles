-- converted from hyprland/execs.conf


-- ── from hyprland/execs.conf ──────────────────────────────
autostart("start_geoclue_a", "~/.config/hypr/hyprland/scripts/start_geoclue_agent.sh", true)
autostart("start-quickshel", "/home/caesar/.config/hypr/hyprland/scripts/start-quickshell.sh ii", true)
autostart("__restore_video", "~/.config/hypr/custom/scripts/__restore_video_wallpaper.sh", true)
autostart("gnome-keyring-d", "gnome-keyring-daemon --start --components=secrets", true)
autostart("hypridle", "hypridle", true)
autostart("dbus-update-act", "dbus-update-activation-environment --all", true)
autostart("sleep 1", "sleep 1 && ~/.scripts/portal-env-fix")
autostart("easyeffects", "easyeffects --hide-window --service-mode", true)
autostart("start-cliphist-", "/home/caesar/.config/hypr/hyprland/scripts/start-cliphist-watch.sh ii", true)
