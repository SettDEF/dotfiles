-- Keys (as nvim's lua/core/mapping/init.lua).
local map = zett.map

-- the file tree
zett.group("<leader>n", "file tree")
map("n", "<leader>nn", "explorer-reveal", { desc = "Toggle file browser" })
map("n", "<leader>ng", "explorer-git", { desc = "Show git status" })
map("n", "<leader>nb", "explorer-buffers", { desc = "Show open buffers" })
map("n", "<leader>e", "explorer", { desc = "Toggle Neotree" })
map("n", "<leader>u", "undotree", { desc = "Undo tree" })

-- windows: Ctrl+h/j/k/l between them (at the edge into the explorer / undo tree and back)
map("n", "<C-h>", "window-left", { desc = "Move to left window" })
map("n", "<C-j>", "window-down", { desc = "Move to down window" })
map("n", "<C-k>", "window-up", { desc = "Move to up window" })
map("n", "<C-l>", "window-right", { desc = "Move to right window" })
map("n", "<leader>sv", "split-right", { desc = "Split window vertically" })
map("n", "<leader>sh", "split-below", { desc = "Split window horizontally" })

-- buffers: H / L step, Alt+, / Alt+. move one in the tab line, Alt+1…9 jump, Space Tab back
map("n", "H", "previous-buffer", { desc = "Previous buffer" })
map("n", "L", "next-buffer", { desc = "Next buffer" })
map("n", "<A-,>", "move-buffer-left", { desc = "Move buffer left" })
map("n", "<A-.>", "move-buffer-right", { desc = "Move buffer right" })
for i = 1, 9 do
  map("n", "<A-" .. i .. ">", "goto-buffer-" .. i, { desc = "Buffer " .. i })
end
map("n", "<leader><Tab>", "last-buffer", { desc = "The buffer before" })
map("n", "<leader>bd", "kill-buffer", { desc = "Delete buffer" })
map("n", "<leader>bo", "close-other-buffers", { desc = "Close the other buffers" })
map("n", "<leader>fb", "switch-buffer", { desc = "List buffers" })
-- a buffer to another window: Space w H/J/K/L or Ctrl+w H/J/K/L (built in)
