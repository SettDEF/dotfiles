-- Re-registers nvim-treesitter (master) query directives/predicates with the
-- newer Neovim 0.11+ treesitter API, where `match[id]` is a list of TSNodes
-- instead of a single TSNode. Without this, mdmath / treesitter-context
-- crash on markdown injections with `attempt to call method 'range'`.

local query = require("vim.treesitter.query")
local opts = { force = true, all = false }

local function first_node(match, id)
    local v = match[id]
    if type(v) == "table" and v[1] ~= nil and type(v[1]) == "userdata" then
        return v[#v]
    end
    return v
end

local html_script_type_languages = {
    importmap = "json",
    module = "javascript",
    ["application/ecmascript"] = "javascript",
    ["text/ecmascript"] = "javascript",
}

local non_filetype_match_injection_language_aliases = {
    ex = "elixir",
    pl = "perl",
    sh = "bash",
    uxn = "uxntal",
    ts = "typescript",
}

local function parser_from_info_string(alias)
    local m = vim.filetype.match({ filename = "a." .. alias })
    return m or non_filetype_match_injection_language_aliases[alias] or alias
end

query.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
    local node = first_node(match, pred[2])
    if not node then
        return
    end
    local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
    if not ok or not text then
        return
    end
    metadata["injection.language"] = parser_from_info_string(text:lower())
end, opts)

query.add_directive("set-lang-from-mimetype!", function(match, _, bufnr, pred, metadata)
    local node = first_node(match, pred[2])
    if not node then
        return
    end
    local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
    if not ok or not text then
        return
    end
    local configured = html_script_type_languages[text]
    if configured then
        metadata["injection.language"] = configured
    else
        local parts = vim.split(text, "/", {})
        metadata["injection.language"] = parts[#parts]
    end
end, opts)

query.add_directive("downcase!", function(match, _, bufnr, pred, metadata)
    local id = pred[2]
    local node = first_node(match, id)
    if not node then
        return
    end
    local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr, { metadata = metadata[id] })
    if not ok then
        return
    end
    if not metadata[id] then
        metadata[id] = {}
    end
    metadata[id].text = string.lower(text or "")
end, opts)

query.add_predicate("nth?", function(match, _, _, pred)
    local node = first_node(match, pred[2])
    local n = tonumber(pred[3])
    if node and node.parent and node:parent() and node:parent():named_child_count() > n then
        return node:parent():named_child(n) == node
    end
    return false
end, opts)

query.add_predicate("kind-eq?", function(match, _, _, pred)
    local node = first_node(match, pred[2])
    if not node then
        return true
    end
    local types = { unpack(pred, 3) }
    return vim.tbl_contains(types, node:type())
end, opts)

query.add_predicate("is?", function(match, _, bufnr, pred)
    local node = first_node(match, pred[2])
    if not node then
        return true
    end
    local ok, locals = pcall(require, "nvim-treesitter.locals")
    if not ok then
        return false
    end
    local _, _, kind = locals.find_definition(node, bufnr)
    local types = { unpack(pred, 3) }
    return vim.tbl_contains(types, kind)
end, opts)

query.add_directive("make-range!", function() end, opts)
