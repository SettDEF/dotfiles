-- converted from custom/env.conf


-- ── from custom/env.conf ──────────────────────────────
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("GDK_SCALE", "1")
hl.env("FILMCRAFT_DATA_DIR", "/mnt/storage/Videos/FilmCraft")
hl.env("PHOTOCRAFT_CONTROL_PORT", "7878")
hl.env("PHOTOCRAFT_CONTROL_TOKEN_FILE", os.getenv("HOME") .. "/.config/photocraft-brushset/token")
hl.env("PHOTOCRAFT_AUTOMATION_READ_ROOT", os.getenv("HOME") .. "/.cache/photocraft-brushset")
