-- converted from custom/rules.conf


-- ── from custom/rules.conf ──────────────────────────────
hl.window_rule({
    name  = "custom-rules-windowrule-1",
    match = { class = "^(gimp.*)$", title = "^(?!.*GIMP).*$" },
    float = true,
})
hl.window_rule({
    name  = "custom-rules-windowrule-2",
    match = { class = "^(gimp.*)$", title = "^(?!.*GIMP).*$" },
    stay_focused = true,
})
hl.window_rule({
    name  = "custom-rules-windowrule-3",
    match = { class = "^(org\\.kde\\.kioclient)$" },
    float = true,
})
hl.window_rule({
    name  = "custom-rules-windowrule-4",
    match = { class = "^(org\\.kde\\.kioclient)$" },
    center = true,
})
hl.window_rule({
    name  = "custom-rules-windowrule-5",
    match = { class = "^(org\\.kde\\.kioclient)$" },
    size = "(monitor_w*.34) (monitor_h*.72)",
})
hl.window_rule({
    name  = "custom-rules-windowrule-6",
    match = { class = ".*[Mm]inimeters.*" },
    float = true,
})
hl.window_rule({
    name  = "custom-rules-windowrule-7",
    match = { class = ".*[Mm]inimeters.*" },
    pin = true,
})
hl.window_rule({
    name  = "custom-rules-windowrule-8",
    match = { class = ".*[Mm]inimeters.*" },
    no_initial_focus = true,
})
hl.window_rule({
    name  = "custom-rules-windowrule-9",
    match = { class = ".*[Mm]inimeters.*" },
    border_size = 0,
})
hl.window_rule({
    name  = "custom-rules-windowrule-10",
    match = { class = ".*[Mm]inimeters.*" },
    no_shadow = true,
})
hl.window_rule({
    name  = "custom-rules-windowrule-11",
    match = { class = ".*[Mm]inimeters.*" },
    no_blur = true,
})
-- device block: convert with hl.device({ name = ..., ... })
-- name = "elan9008:00-04f3:43c7-stylus",
-- output = "eDP-1",
-- left_handed = false,
hl.layer_rule({
    name  = "custom-rules-layerrule-12",
    match = { namespace = "MiniMeters" },
    order = 1,
})
hl.window_rule({
    name  = "custom-rules-windowrule-13",
    match = { class = "^(org\\.quickshell)$", title = "(.*)— Dock$" },
    float = true,
})
hl.window_rule({
    name  = "custom-rules-windowrule-14",
    match = { class = "^(org\\.quickshell|kalends)$", title = "^Kalends$" },
    float = true,
})
hl.window_rule({
    name  = "custom-rules-windowrule-15",
    match = { class = "^(org\\.quickshell|kalends)$", title = "^Kalends$" },
    size = "900 620",
})
hl.window_rule({
    name  = "custom-rules-windowrule-16",
    match = { class = "^(org\\.quickshell|kalends)$", title = "^Kalends$" },
    center = true,
})
hl.layer_rule({
    name  = "custom-rules-layerrule-17",
    match = { namespace = "quickshell:popup" },
    no_anim = true,
})
hl.layer_rule({
    name  = "custom-rules-layerrule-18",
    match = { namespace = "zash-desktop" },
    blur = true,
})
hl.layer_rule({
    name  = "custom-rules-layerrule-19",
    match = { namespace = "zash-desktop" },
    ignore_alpha = 0,
})
hl.layer_rule({
    name  = "custom-rules-layerrule-20",
    match = { namespace = "zash-desktop" },
    no_anim = true,
})
hl.window_rule({
    name  = "custom-rules-windowrule-21",
    match = { class = "^(zash-float)$" },
    float = true,
})
hl.window_rule({
    name  = "custom-rules-windowrule-22",
    match = { class = "^(zash-float)$" },
    center = true,
})
