-- converted from hyprland/rules.conf


-- ── from hyprland/rules.conf ──────────────────────────────
hl.window_rule({
    name  = "hyprland-rules-windowrule-1",
    match = { class = "^()$", title = "^()$" },
    no_blur = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-2",
    match = { class = ".*" },
    no_blur = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-3",
    match = { title = "^(Open File)(.*)$" },
    center = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-4",
    match = { title = "^(Open File)(.*)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-5",
    match = { title = "^(Select a File)(.*)$" },
    center = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-6",
    match = { title = "^(Select a File)(.*)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-7",
    match = { title = "^(Choose wallpaper)(.*)$" },
    center = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-8",
    match = { title = "^(Choose wallpaper)(.*)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-9",
    match = { title = "^(Choose wallpaper)(.*)$" },
    size = "(monitor_w*.60) (monitor_h*.65)",
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-10",
    match = { title = "^(Open Folder)(.*)$" },
    center = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-11",
    match = { title = "^(Open Folder)(.*)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-12",
    match = { title = "^(Save As)(.*)$" },
    center = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-13",
    match = { title = "^(Save As)(.*)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-14",
    match = { title = "^(Library)(.*)$" },
    center = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-15",
    match = { title = "^(Library)(.*)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-16",
    match = { title = "^(File Upload)(.*)$" },
    center = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-17",
    match = { title = "^(File Upload)(.*)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-18",
    match = { title = "^(.*)(wants to save)$" },
    center = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-19",
    match = { title = "^(.*)(wants to save)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-20",
    match = { title = "^(.*)(wants to open)$" },
    center = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-21",
    match = { title = "^(.*)(wants to open)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-22",
    match = { class = "^(blueberry\\.py)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-23",
    match = { class = "^(guifetch)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-24",
    match = { class = "^(pavucontrol)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-25",
    match = { class = "^(pavucontrol)$" },
    size = "(monitor_w*.45) (monitor_h*.45)",
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-26",
    match = { class = "^(pavucontrol)$" },
    center = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-27",
    match = { class = "^(org.pulseaudio.pavucontrol)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-28",
    match = { class = "^(org.pulseaudio.pavucontrol)$" },
    size = "(monitor_w*.45) (monitor_h*.45)",
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-29",
    match = { class = "^(org.pulseaudio.pavucontrol)$" },
    center = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-30",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-31",
    match = { class = "^(nm-connection-editor)$" },
    size = "(monitor_w*.45) (monitor_h*.45)",
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-32",
    match = { class = "^(nm-connection-editor)$" },
    center = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-33",
    match = { class = ".*plasmawindowed.*" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-34",
    match = { class = "kcm_.*" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-35",
    match = { class = ".*bluedevilwizard" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-36",
    match = { title = ".*Welcome" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-37",
    match = { title = "^(illogical-impulse Settings)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-38",
    match = { title = ".*Shell conflicts.*" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-39",
    match = { class = "org.freedesktop.impl.portal.desktop.kde" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-40",
    match = { class = "org.freedesktop.impl.portal.desktop.kde" },
    size = "(monitor_w*.60) (monitor_h*.65)",
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-41",
    match = { class = "^(Zotero)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-42",
    match = { class = "^(Zotero)$" },
    size = "(monitor_w*.45) (monitor_h*.45)",
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-43",
    match = { class = "^$", title = ".+ / .+ / .+" },
    no_anim = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-44",
    match = { class = "^$", title = ".+ / .+ / .+" },
    no_blur = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-45",
    match = { class = "^$", title = ".+ / .+ / .+" },
    no_shadow = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-46",
    match = { class = "^(plasma-changeicons)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-47",
    match = { class = "^(plasma-changeicons)$" },
    no_initial_focus = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-48",
    match = { class = "^(plasma-changeicons)$" },
    move = "999999 999999",
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-49",
    match = { title = "^(Copying — Dolphin)$" },
    move = "40 80",
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-50",
    match = { class = "^dev\\.warp\\.Warp$" },
    tile = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-51",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-52",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    keep_aspect_ratio = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-53",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    move = "(monitor_w*.73) (monitor_h*.72)",
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-54",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    size = "(monitor_w*.25) (monitor_h*.25)",
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-55",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-56",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    pin = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-57",
    match = { title = ".*is sharing (a window|your screen).*" },
    float = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-58",
    match = { title = ".*is sharing (a window|your screen).*" },
    pin = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-59",
    match = { title = ".*is sharing (a window|your screen).*" },
    move = "(monitor_w*.5-window_w*.5) (monitor_h-window_h-12)",
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-60",
    match = { title = ".*\\.exe" },
    immediate = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-61",
    match = { title = ".*minecraft.*" },
    immediate = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-62",
    match = { class = "^(steam_app).*" },
    immediate = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-63",
    match = { class = "^jetbrains-.*$", float = 1, title = "^$|^\\s$|^win\\d+$" },
    no_initial_focus = true,
})
hl.window_rule({
    name  = "hyprland-rules-windowrule-64",
    match = { float = 0 },
    no_shadow = true,
})
hl.workspace_rule({ workspace = "special:special", gaps_out = 30 })
hl.layer_rule({
    name  = "hyprland-rules-layerrule-65",
    match = { namespace = ".*" },
    xray = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-66",
    match = { namespace = "walker" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-67",
    match = { namespace = "selection" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-68",
    match = { namespace = "overview" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-69",
    match = { namespace = "anyrun" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-70",
    match = { namespace = "indicator.*" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-71",
    match = { namespace = "osk" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-72",
    match = { namespace = "hyprpicker" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-73",
    match = { namespace = "noanim" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-74",
    match = { namespace = "gtk-layer-shell" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-75",
    match = { namespace = "gtk-layer-shell" },
    ignore_alpha = 0,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-76",
    match = { namespace = "launcher" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-77",
    match = { namespace = "launcher" },
    ignore_alpha = 0.5,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-78",
    match = { namespace = "notifications" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-79",
    match = { namespace = "notifications" },
    ignore_alpha = 0.69,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-80",
    match = { namespace = "logout_dialog" },
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-81",
    match = { namespace = "sideleft.*" },
    animation = "slide left",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-82",
    match = { namespace = "sideright.*" },
    animation = "slide right",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-83",
    match = { namespace = "session[0-9]*" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-84",
    match = { namespace = "bar[0-9]*" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-85",
    match = { namespace = "bar[0-9]*" },
    ignore_alpha = 0.6,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-86",
    match = { namespace = "barcorner.*" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-87",
    match = { namespace = "barcorner.*" },
    ignore_alpha = 0.6,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-88",
    match = { namespace = "dock[0-9]*" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-89",
    match = { namespace = "dock[0-9]*" },
    ignore_alpha = 0.6,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-90",
    match = { namespace = "indicator.*" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-91",
    match = { namespace = "indicator.*" },
    ignore_alpha = 0.6,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-92",
    match = { namespace = "overview[0-9]*" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-93",
    match = { namespace = "overview[0-9]*" },
    ignore_alpha = 0.6,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-94",
    match = { namespace = "cheatsheet[0-9]*" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-95",
    match = { namespace = "cheatsheet[0-9]*" },
    ignore_alpha = 0.6,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-96",
    match = { namespace = "sideright[0-9]*" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-97",
    match = { namespace = "sideright[0-9]*" },
    ignore_alpha = 0.6,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-98",
    match = { namespace = "sideleft[0-9]*" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-99",
    match = { namespace = "sideleft[0-9]*" },
    ignore_alpha = 0.6,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-100",
    match = { namespace = "indicator.*" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-101",
    match = { namespace = "indicator.*" },
    ignore_alpha = 0.6,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-102",
    match = { namespace = "osk[0-9]*" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-103",
    match = { namespace = "osk[0-9]*" },
    ignore_alpha = 0.6,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-104",
    match = { namespace = "quickshell:.*" },
    blur_popups = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-105",
    match = { namespace = "quickshell:.*" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-106",
    match = { namespace = "quickshell:.*" },
    ignore_alpha = 0.79,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-107",
    match = { namespace = "quickshell:bar" },
    animation = "slide",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-108",
    match = { namespace = "quickshell:actionCenter" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-109",
    match = { namespace = "quickshell:cheatsheet" },
    animation = "slide bottom",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-110",
    match = { namespace = "quickshell:dock" },
    animation = "slide bottom",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-111",
    match = { namespace = "quickshell:screenCorners" },
    animation = "popin 120%",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-112",
    match = { namespace = "quickshell:lockWindowPusher" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-113",
    match = { namespace = "quickshell:notificationPopup" },
    animation = "fade",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-114",
    match = { namespace = "quickshell:overlay" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-115",
    match = { namespace = "quickshell:overlay" },
    ignore_alpha = 1,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-116",
    match = { namespace = "quickshell:overview" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-117",
    match = { namespace = "quickshell:osk" },
    animation = "slide bottom",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-118",
    match = { namespace = "quickshell:polkit" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-119",
    match = { namespace = "quickshell:popup" },
    xray = false,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-120",
    match = { namespace = "quickshell:popup" },
    ignore_alpha = 1,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-121",
    match = { namespace = "quickshell:mediaControls" },
    ignore_alpha = 1,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-122",
    match = { namespace = "quickshell:reloadPopup" },
    animation = "slide",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-123",
    match = { namespace = "quickshell:regionSelector" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-124",
    match = { namespace = "quickshell:screenDrawFull" },
    blur = false,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-125",
    match = { namespace = "quickshell:screenDrawFull" },
    ignore_alpha = 0,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-126",
    match = { namespace = "quickshell:screenshot" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-127",
    match = { namespace = "quickshell:session" },
    blur = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-128",
    match = { namespace = "quickshell:session" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-129",
    match = { namespace = "quickshell:session" },
    ignore_alpha = 0,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-130",
    match = { namespace = "quickshell:sidebarRight" },
    animation = "slide right",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-131",
    match = { namespace = "quickshell:sidebarLeft" },
    animation = "slide left",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-132",
    match = { namespace = "quickshell:verticalBar" },
    animation = "slide",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-133",
    match = { namespace = "quickshell:osk" },
    order = -1,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-134",
    match = { namespace = "quickshell:wallpaperSelector" },
    animation = "slide top",
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-135",
    match = { namespace = "quickshell:wNotificationCenter" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-136",
    match = { namespace = "quickshell:wOnScreenDisplay" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-137",
    match = { namespace = "quickshell:wStartMenu" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-138",
    match = { namespace = "quickshell:wTaskView" },
    ignore_alpha = 0,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-139",
    match = { namespace = "quickshell:wTaskView" },
    no_anim = true,
})
hl.layer_rule({
    name  = "hyprland-rules-layerrule-140",
    match = { namespace = "gtk4-layer-shell" },
    no_anim = true,
})

-- the mini player: any mpv started with --wayland-app-id=mpv-mini (fileportal, share "Play small")
-- floats bottom centre, a quarter of the screen, on every workspace, without taking the keyboard
hl.window_rule({
    name  = "mpv-mini",
    match = { class = "^(mpv-mini)$" },
    float = true,
    size = "(monitor_w*.25) (monitor_h*.25)",
    move = "(monitor_w*.375) (monitor_h*.72)",
    pin = true,
    no_initial_focus = true,
})
