-- Backward-compat shim. Redirects historic requires to shimmer.nvim
-- (repo: /mnt/storage/dev/projects/shimmer.nvim).
local ok, pulse = pcall(require, "shimmer")
if not ok then
    return { is_pulsing = function() return false end,
             is_path_pulsing = function() return false end,
             spinner_frame = function() return "" end,
             path_status = function() return nil end,
             is_pulsing_any = function() return false end,
             on_change = function() end,
             pulse = function() end,
             setup = function() end }
end
return pulse
