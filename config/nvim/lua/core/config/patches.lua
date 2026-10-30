-- Workarounds for upstream Neovim bugs we have to live with.

-- nvim.lsp.inlayhint races vs buffer edits: rust-analyzer (and other
-- servers) send inlay hints for the buffer version they saw, but the
-- buffer may have been edited or shortened by the time the redraw
-- callback fires. nvim/runtime/lua/vim/lsp/inlay_hint.lua line 362
-- then calls nvim_buf_set_extmark with a column past the line end and
-- raises "Invalid 'col': out of range", which bubbles up as a noisy
-- "Press ENTER" popup over Decoration provider "win" every edit.
--
-- Tracked upstream; until the LSP module pcalls or clamps the column,
-- swallow only this exact error. Real out-of-range bugs in other
-- callers still surface — anything that isn't this string propagates.
do
    local orig_set_extmark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(...)
        local ok, res = pcall(orig_set_extmark, ...)
        if ok then
            return res
        end
        if type(res) == "string" and res:find("Invalid 'col': out of range", 1, true) then
            return -1
        end
        error(res, 2)
    end
end
