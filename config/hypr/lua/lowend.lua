-- lowend.lua: lighter rendering on weak machines (old Intel graphics, little memory), where blur,
-- shadows and animations draw wrongly or slowly. Off on a strong machine.
--   force:  ~/.config/hypr/lowend  containing "on" or "off"
if not io then return end   -- loom: no io, and no weak-machine guess needed
local function read(p) local f = io.open(p); if not f then return nil end; local s = f:read("*a"); f:close(); return s end

local forced = (read(os.getenv("HOME") .. "/.config/hypr/lowend") or ""):match("%a+")
local low
if forced == "on" then low = true elseif forced == "off" then low = false
else
    local intel = false
    for i = 0, 3 do
        if (read("/sys/class/drm/card" .. i .. "/device/vendor") or ""):match("0x8086") then intel = true end
    end
    local kb = tonumber((read("/proc/meminfo") or ""):match("MemTotal:%s+(%d+)")) or 0
    low = intel and kb < 8 * 1024 * 1024
end
if not low then return end

hl.config({
    decoration = {
        blur = { enabled = false },
        shadow = { enabled = false },
        dim_inactive = false,
    },
    animations = { enabled = false },
})
-- every screen at its own resolution and scale 1, whatever the rules for the other laptop say
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1" })
