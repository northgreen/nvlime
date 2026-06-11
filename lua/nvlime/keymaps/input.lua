local km = require("nvlime.keymaps")
local im = km.mappings.input
local km_window = require("nvlime.window.keymaps")
local api = vim.api
local input = {}
input.add = function()
  km.buffer.normal(im.normal.complete, "<Cmd>lua require('nvlime.core.ui.input').from_buffer_complete()<CR>", "nvlime: Complete the input")
  km.buffer.insert(im.insert.keymaps_help, function() return km_window.toggle() end, "Show keymaps help")
  km.buffer.insert(im.insert.complete, "<Cmd>lua require('nvlime.core.ui.input').from_buffer_complete()<CR>", "nvlime: Complete the input")
  km.buffer.insert(im.insert.next_history, "<Cmd>lua require('nvlime.core.ui.input').next_history_item()<CR>", "nvlime: Show the next item in input history")
  km.buffer.insert(im.insert.prev_history, "<Cmd>lua require('nvlime.core.ui.input').next_history_item(v:false)<CR>", "nvlime: Show the previous item in input history")
  return km.buffer.insert(im.insert.leave_insert, function()
    local cursor = api.nvim_win_get_cursor(0)
    local linenr, col = cursor[1], cursor[2]
    if linenr == 1 and col == 0 then
      api.nvim_win_close(0, true)
    end
    return km.feedkeys("<Esc>")
  end, "Close window or leave insert mode")
end
return input
