-- Git: gitsigns in the gutter, as nvim's lazyload/plugins/git.lua (same signs, same keys).

zett.plug("lewis6991/gitsigns.nvim", {
  opts = {
    preview_config = { border = "rounded" },
    signcolumn = true,
    numhl = false,
    -- sparkle glyphs: AI / external edits stand apart from other editors' git markers
    signs = {
      add = { text = "✦" },
      change = { text = "✧" },
      delete = { text = "⋆" },
      topdelete = { text = "⋆" },
      changedelete = { text = "✧" },
      untracked = { text = "·" },
    },
  },
})

local function gs(f) return function() require("gitsigns")[f]() end end
vim.keymap.set("n", "<leader>gs", gs("stage_hunk"), { desc = "Stage hunk" })
vim.keymap.set("n", "<leader>gu", gs("undo_stage_hunk"), { desc = 'Undo "stage hunk"' })
vim.keymap.set("n", "<leader>gn", gs("next_hunk"), { desc = "Next hunk" })
vim.keymap.set("n", "<leader>gN", gs("prev_hunk"), { desc = "Previous hunk" })
vim.keymap.set("n", "<leader>gp", gs("preview_hunk_inline"), { desc = "Preview hunk" })
