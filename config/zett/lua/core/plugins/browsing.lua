-- The explorer, set up as neo-tree is in nvim (lua/core/lazyload/plugins/browsing.lua).
zett.opt.explorer = {
  width = 30,
  hidden = true,             -- hide_dotfiles = false
  hide_gitignored = true,
  ignore = { ".git", "node_modules", ".DS_Store" }, -- hide_by_name
  follow = true,             -- follow_current_file
  indent = {
    last_marker = "╰",
    expander_collapsed = "\u{f460}",
    expander_expanded = "\u{f47c}",
  },
  icon = {
    folder_closed = "\u{e5ff}",
    folder_open = "\u{e5fe}",
    folder_empty = "\u{f070c}",
    folder_empty_open = "\u{f070c}",
  },
  git_align = "right",
  git_symbols = {
    added = "✚",
    modified = "\u{f104}",
    deleted = "✖",
    renamed = "\u{f0055}",
    untracked = "\u{f128}",
    conflict = "\u{e727}",
  },
  mappings = {
    ["<space>"] = "none",     -- the leader works in the tree
    l = "none",
    w = "none",
  },
}
