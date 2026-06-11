local km = require("nvlime.keymaps")
local im = km.mappings.input
local km_window = require("nvlime.window.keymaps")
local nvim_win_close = vim.api.nvim_win_close
local nvim_win_get_cursor = vim.api.nvim_win_get_cursor
local input = {}
input.add = function()
  km.buffer.normal(im.normal.complete, "<Cmd>lua require('nvlime.core.ui.input').from_buffer_complete()<CR>", "nvlime: Complete the input")
  local function _1_()
    return km_window.toggle()
  end
  km.buffer.insert(im.insert.keymaps_help, _1_, "Show keymaps help")
  km.buffer.insert(im.insert.complete, "<Cmd>lua require('nvlime.core.ui.input').from_buffer_complete()<CR>", "nvlime: Complete the input")
  km.buffer.insert(im.insert.next_history, "<Cmd>lua require('nvlime.core.ui.input').next_history_item()<CR>", "nvlime: Show the next item in input history")
  km.buffer.insert(im.insert.prev_history, "<Cmd>lua require('nvlime.core.ui.input').next_history_item(v:false)<CR>", "nvlime: Show the previous item in input history")
  local function _2_()
    local _let_3_ = nvim_win_get_cursor(0)
    local linenr = _let_3_[1]
    local col = _let_3_[2]
    if ((linenr == 1) and (col == 0)) then
      nvim_win_close(0, true)
    else
    end
    return km.feedkeys("<Esc>")
  end
  return km.buffer.insert(im.insert.leave_insert, _2_, "Close window or leave insert mode")
end
return input
