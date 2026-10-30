local Job = require("plenary.job")
local config = require("core.timewarrior.config")
local parse = require("core.timewarrior.parse")

local M = {}

local function bin()
    return config.get().cmd or "timew"
end

local function env()
    return { LC_TIME = "C", LC_ALL = "C" }
end

local function run(args, on_done)
    local stdout, stderr = {}, {}
    Job:new({
        command = bin(),
        args = args,
        env = env(),
        on_stdout = function(_, line)
            table.insert(stdout, line)
        end,
        on_stderr = function(_, line)
            table.insert(stderr, line)
        end,
        on_exit = function(_, code)
            vim.schedule(function()
                if on_done then
                    on_done({ code = code, stdout = stdout, stderr = stderr })
                end
            end)
        end,
    }):start()
end

local function with_tags(args, tags)
    for _, t in ipairs(tags or {}) do
        table.insert(args, t)
    end
    return args
end

function M.start(opts, cb)
    opts = opts or {}
    local args = { "start" }
    if opts.from then
        table.insert(args, opts.from)
    end
    with_tags(args, opts.tags)
    run(args, function(res)
        if res.code == 0 and opts.description and opts.description ~= "" then
            run({ "annotate", "@1", opts.description }, cb)
        else
            if cb then
                cb(res)
            end
        end
    end)
end

function M.stop(cb)
    run({ "stop" }, cb)
end

function M.cancel(cb)
    run({ "cancel" }, cb)
end

function M.continue(cb)
    run({ "continue" }, cb)
end

function M.track(opts, cb)
    assert(opts.from and opts.to, "track requires from + to")
    local args = { "track", opts.from, "-", opts.to }
    with_tags(args, opts.tags)
    run(args, function(res)
        if res.code == 0 and opts.description and opts.description ~= "" then
            run({ "annotate", "@1", opts.description }, cb)
        else
            if cb then
                cb(res)
            end
        end
    end)
end

function M.annotate(id, text, cb)
    run({ "annotate", id, text }, cb)
end

function M.tag(id, tags, cb)
    run(with_tags({ "tag", id }, tags), cb)
end

function M.untag(id, tags, cb)
    run(with_tags({ "untag", id }, tags), cb)
end

function M.delete(id, cb)
    run({ "delete", id }, cb)
end

function M.summary(range, cb)
    run({ "summary", range or "day" }, cb)
end

function M.active(cb)
    local fields = { "start", "tag.count", "tag.1", "tag.2", "tag.3", "id" }
    local args = { "get" }
    for _, f in ipairs(fields) do
        table.insert(args, "dom.active." .. f)
    end
    run(args, function(res)
        local rows = {}
        for i, f in ipairs(fields) do
            rows[i] = { dom = "dom.active." .. f, value = res.stdout[i] or "" }
        end
        cb(parse.active_from_dom(rows))
    end)
end

function M.available()
    return vim.fn.executable(bin()) == 1
end

return M
