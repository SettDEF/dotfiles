-- converted from custom/env.conf
-- this machine's folders from ~/.config/paths.env (STORAGE, PROJECTS_DIR, VIDEOS_DIR …), for every program started here
local P = {}
do
    local f = io.popen(". \"$HOME/.config/paths.env\" 2>/dev/null; env")
    for line in (f and f:read("*a") or ""):gmatch("[^\n]+") do
        local k, v = line:match("^([A-Z_]+_DIR)=(.*)$")
        if not k then k, v = line:match("^(STORAGE)=(.*)$") end
        if not k then k, v = line:match("^(USERDATA)=(.*)$") end
        if not k then k, v = line:match("^(DEV_CACHE)=(.*)$") end
        if not k then k, v = line:match("^(CARGO_TARGET_DIR)=(.*)$") end
        if k then P[k] = v; hl.env(k, v) end
    end
    if f then f:close() end
end


-- ── from custom/env.conf ──────────────────────────────
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("GDK_SCALE", "1")
hl.env("FILMCRAFT_DATA_DIR", (P.VIDEOS_DIR or (os.getenv("HOME") .. "/Videos")) .. "/FilmCraft")
hl.env("PHOTOCRAFT_CONTROL_PORT", "7878")
hl.env("PHOTOCRAFT_CONTROL_TOKEN_FILE", os.getenv("HOME") .. "/.config/photocraft-brushset/token")
hl.env("PHOTOCRAFT_AUTOMATION_READ_ROOT", os.getenv("HOME") .. "/.cache/photocraft-brushset")
