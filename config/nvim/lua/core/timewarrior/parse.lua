local M = {}

-- Parses `timew get dom.active.*` output (issued in batch) into a table.
-- Inputs: table of { dom = string, value = string } pairs.
function M.active_from_dom(rows)
    local t = {}
    for _, r in ipairs(rows) do
        local key = r.dom:match("^dom%.active%.(.+)$")
        if key then
            t[key] = r.value
        end
    end
    if not t.start or t.start == "" then
        return nil
    end
    t.tag = t.tag or t["tag.1"] or ""
    return t
end

-- Returns elapsed seconds between an ISO-8601 start and now (UTC).
function M.elapsed_seconds(iso_start)
    local Y, Mo, D, H, Mi, S = iso_start:match("^(%d%d%d%d)(%d%d)(%d%d)T(%d%d)(%d%d)(%d%d)Z?$")
    if not Y then
        Y, Mo, D, H, Mi, S = iso_start:match("^(%d+)-(%d+)-(%d+)[T ](%d+):(%d+):(%d+)")
    end
    if not Y then
        return 0
    end
    local t = os.time({
        year = tonumber(Y),
        month = tonumber(Mo),
        day = tonumber(D),
        hour = tonumber(H),
        min = tonumber(Mi),
        sec = tonumber(S),
    })
    return os.difftime(os.time(), t)
end

-- "01:23" given seconds.
function M.fmt_elapsed(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    return string.format("%02d:%02d", h, m)
end

-- "from HH:MM to HH:MM" → { from = "ISO", to = "ISO" } anchored to today.
function M.parse_backdate(line)
    local fh, fm, th, tm = line:match("from%s+(%d+):(%d+)%s+to%s+(%d+):(%d+)")
    if not fh then
        return nil, "expected: from HH:MM to HH:MM"
    end
    local now = os.date("*t")
    local function iso(h, m)
        return string.format(
            "%04d-%02d-%02dT%02d:%02d:00",
            now.year,
            now.month,
            now.day,
            tonumber(h),
            tonumber(m)
        )
    end
    return { from = iso(fh, fm), to = iso(th, tm) }
end

return M
