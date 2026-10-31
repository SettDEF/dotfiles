-- Personal overrides, loaded last so they win over the converted config.
-- conf2lua never regenerates this file.

-- No colour on the focused window's border. The border is kept at its
-- configured width but drawn fully transparent, so window geometry and gaps
-- stay exactly as they were — only the highlight disappears.
hl.config({
    general = {
        col = { active_border = "rgba(00000000)" },
    },
    input = {
        touchpad = {
            natural_scroll = true,
        },
        -- the Z13's pen and touch belong to its own screen, not spread over
        -- the external monitor too
        tablet = { output = "eDP-1" },
        touchdevice = { output = "eDP-1" },
    },
})

hl.device({
    name = "asustek-computer-inc.-gz302ea-keyboard-touchpad",
    -- the Z13's touchpad scrolls faster; only this device: as input:scroll_factor (and touchpad's)
    -- it went to every machine these dotfiles install on, and doubled a small touchpad's scrolling
    scroll_factor = 1.5,
    accel_profile = "adaptive",
    sensitivity = 0.000,
    natural_scroll = true,
    tap_to_click = true,
    tap_and_drag = true,
    clickfinger_behavior = true,
    disable_while_typing = true,
})

-- ── Fullscreen games yanking the workspace back ──────────────────────
-- Symptom: on a workspace with a fullscreen game, switching to another
-- workspace bounces straight back to the game.
--
-- Cause is `misc:focus_on_activate = true` (see lua/hyprland/general.lua).
-- A fullscreen game that loses focus usually asks to be activated again
-- — Wine/Proton titles do this aggressively — and with that option on,
-- Hyprland honours the request and follows it back to the game's
-- workspace. The switch does happen; it is undone a frame later.
--
-- Suppressing the request per-window rather than turning the global
-- option off, because focus_on_activate is what makes "click a link,
-- browser comes forward" work. Both tokens are needed: `activate` drops
-- the raise-and-switch, `activatefocus` drops the focus-steal that can
-- still follow one. Verified against the token list in Hyprland's
-- Window.cpp — fullscreen/maximize/activate/activatefocus/
-- fullscreenoutput/x11configurerequest.
--
-- Switching TO the game by hand is unaffected; it only loses the
-- ability to summon itself.
--
-- If your game is not a Steam title, add its class here — find it with
--   hyprctl clients | grep -A2 class
-- while the game is running.
for _, cls in ipairs({ "^(steam_app).*", "^(gamescope)$" }) do
    hl.window_rule({
        name           = "no-focus-steal " .. cls,
        match          = { class = cls },
        suppress_event = "activate activatefocus",
    })
end

-- ── Super-tap interrupts ─────────────────────────────────────────────
-- lua/hyprland/super_interrupts.lua holds 178 `SUPER + <key>` binds that
-- cancel the pending overview-on-Super-release. It was written, and then
-- nothing ever required it: `hyprctl binds` showed 0 of them loaded, so
-- every Super combo still toggled the overview when Super came up.
-- Super+grave opened the corner popup AND the overview.
--
-- Required here rather than from hyprland.lua because conf2lua regenerates
-- that file and would drop the line. This file it never touches.
require("lua.hyprland.super_interrupts")

-- ── Glass ─────────────────────────────────────────────────────────────
-- Written by the shell's Palette > Glass panel: blur settings and the
-- per-app window rules, so they survive `hyprctl reload`. Never generated
-- by conf2lua, so it is safe here.
pcall(require, "lua.glass")

-- Best modes MonitorAutoMode picked (shell-written). After the user rules
-- in lua/monitors.lua, so a config re-apply keeps them instead of switching back.
pcall(require, "lua.monitor_auto")

-- AwesomeWM-style layouts, per workspace like Awesome's tags (Super+Y cycles,
-- Super+Alt+H/L master width, see hyprland/layouts.conf). Registered here, after
-- the generated config, then made the default for every workspace.
do
    -- dofile, not require: a reload must pick up edits to the file. Workspaces
    -- without a saved suit keep general.layout (master = Awesome's tile).
    local ok, M = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/lua/awesome_layouts.lua")
    if ok and M then
        pcall(M.restore)
        M.bind_keys()
    end
end

-- Window title bars (ii-decor). The script skips if already loaded and refuses
-- a build that does not match the running Hyprland.
hl.exec_cmd("~/.config/hypr/hyprland/scripts/ii-decor-autoload.sh")

-- ── Super-tap guard ─────────────────────────────────────────────────────
-- A Super RELEASE opens the launcher (search releaseToggle) only after a bare
-- tap. These report "something else happened while Super was held" to the
-- shell. Without them Ctrl/Shift/Alt+Super or Super+click opened the launcher
-- unseen, and its focus grab swallowed the next click and the typing.
-- Here, not in keybinds.lua: conf2lua regenerates that file.
-- No binds ON modifier keys (SUPER + Control_L, SHIFT + Super, ...): they never
-- matched, and a bind on a modifier makes Hyprland treat that key specially;
-- suspected of eating the first key typed after a lone Ctrl/Shift/Alt
-- (2026-10-14). The key-stream handler below reports those combos instead.
for _, b in ipairs({ "mouse:272", "mouse:273", "mouse:274" }) do
    hl.bind("SUPER + " .. b, hl.dsp.global("quickshell:superComboInterrupt"), { transparent = true })
end

-- ── Window drag: the shell's drop preview ─────────────────────────────────
-- Press and release of Super+left drag reach the shell (GlobalStates.windowDragging), which
-- shows where a tiled window will land (modules/ii/windowDrag). Transparent, like the guard
-- above: the drag bind in keybinds.lua handles the click as before.
hl.bind("SUPER + mouse:272", hl.dsp.global("quickshell:windowDrag"), { transparent = true })
-- Super+right-drag reaches the shell too: on a Lua layout (fair, corner) it moves the split, which
-- Hyprland cannot resize there (modules/ii/windowDrag/LayoutResizeDrag.qml)
hl.bind("SUPER + mouse:273", hl.dsp.global("quickshell:windowResize"), { transparent = true })

-- ── Super tap guard: report combos from the key stream ───────────────────
-- The release BIND opens the launcher (search releaseToggle, which skips after
-- an interrupt). Interrupt binds on modifier keys never match, so Super+Shift
-- and the like opened it and its focus grab ate the next click. Hyprland sees
-- every key here: any key going down while Super is held reports the combo.
-- Opening stays with the release bind; toggling from inside this handler
-- (an earlier version) made the launcher close again at once.
do
    local SUPER = { [133] = true, [134] = true }
    -- key code -> os.time() it went down. A release can be missed (a config
    -- reload while a key is held); an entry that outlives STALE seconds is
    -- dropped, or one forgotten key would read as "held" forever and block
    -- every Super tap from opening the launcher.
    local STALE = 3
    local down = {}
    hl.on("input.keyboard.key", function(code, _, state)
        pcall(function()
            if state == 1 then
                local now = os.time()
                for k, t in pairs(down) do
                    if now - t > STALE then down[k] = nil end
                end
                local superHeld = false
                for k in pairs(down) do if SUPER[k] then superHeld = true end end
                local otherHeld = false
                for k in pairs(down) do if not SUPER[k] then otherHeld = true end end
                -- another key while Super is held, or Super pressed onto a held key
                if (superHeld and not SUPER[code]) or (SUPER[code] and otherHeld) then
                    hl.dispatch(hl.dsp.global("quickshell:superComboInterrupt"))
                end
                down[code] = now
            else
                down[code] = nil
            end
        end)
    end)
end

-- Keyboard cover reset (= detach + reattach in software), set up by
-- ~/.scripts/install/input.sh: clears the cover's "first click after a
-- modifier is lost" state.
hl.bind("SUPER + CTRL + Escape", hl.dsp.exec_cmd(
    "sudo -n /usr/local/bin/z13-cover-reset && notify-send -a Keyboard 'Keyboard cover reconnected'"),
    { description = "Reconnect keyboard cover" })

-- HDB 630 wear sensor: the headset HOLDS a key while it is on (KEY_PLAY) and
-- another while it is off (KEY_PAUSE). A permanently held key confuses
-- Hyprland (repeat, and the first key after a lone modifier was swallowed), so
-- Hyprland ignores this device; ~/.config/hdb630/wear.sh reads it directly and
-- pauses/resumes playback and forwards its buttons (hdb630-wear.service).
hl.device({
    name = "sonova-consumer-hearing-hdb-630-consumer-control",
    enabled = false,
})

-- Firewall panel (OpenSnitch via snitch-bridge).
hl.bind("SUPER + CTRL + F", hl.dsp.exec_cmd("qs -c ii ipc call firewall toggle"), { description = "Firewall panel" })
