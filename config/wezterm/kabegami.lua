local M = {}

---@type table
local data = {
	butasan = {
		nesoberi = "butasan_nesoberi.png",
	},
	azusa = {
		kuroinu = "Azusa_by_96ENU.png",
		sentariba = "azusa_by_sentariba.png",
	},
	OOths = {
		ths = "~/.wallpapers/nord/014.jpg"
	}
}

---Get a specific kabegami set.
---@param category "butasan"|"azusa"
function M.get(category)
	return data[category]
end

return M
