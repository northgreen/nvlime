local window = require("nvlime.window")
local buffer = require("nvlime.buffer")
local psl = require("parsley")
local nvim_create_namespace = vim.api.nvim_create_namespace
local nvim_create_autocmd = vim.api.nvim_create_autocmd
local nvim_buf_clear_namespace = vim.api.nvim_buf_clear_namespace
local nvim_buf_line_count = vim.api.nvim_buf_line_count
local nvim_buf_set_extmark = vim.api.nvim_buf_set_extmark
local nvim_win_get_cursor = vim.api.nvim_win_get_cursor
local nvim_win_set_cursor = vim.api.nvim_win_set_cursor
local xref = {}
local _2bfiletype_2b = buffer["gen-filetype"](buffer.names.xref)
local _2bnamespace_2b = nvim_create_namespace(_2bfiletype_2b)
local _2alast_line_2a = 1
local _2aprev_line_2a = 0
local function content__3elines(content)
  local lines = {}
  for _, xref0 in ipairs(content) do
    local filename
    do
      local t_1_ = xref0
      if (nil ~= t_1_) then
        t_1_ = t_1_[2]
      else
      end
      if (nil ~= t_1_) then
        t_1_ = t_1_[2]
      else
      end
      if (nil ~= t_1_) then
        t_1_ = t_1_[2]
      else
      end
      filename = t_1_
    end
    local filename_or_error
    local or_5_ = filename
    if not or_5_ then
      local t_6_ = xref0
      if (nil ~= t_6_) then
        t_6_ = t_6_[2]
      else
      end
      if (nil ~= t_6_) then
        t_6_ = t_6_[1]
      else
      end
      if (nil ~= t_6_) then
        t_6_ = t_6_.name
      else
      end
      or_5_ = t_6_
    end
    filename_or_error = or_5_
    local sym = string.gsub(xref0[1], "\n%s*", " ")
    table.insert(lines, sym)
    table.insert(lines, ("  ;; " .. filename_or_error))
  end
  return lines
end
local function double_cursorline(linenr)
  nvim_buf_clear_namespace(0, _2bnamespace_2b, 0, -1)
  return nvim_buf_set_extmark(0, _2bnamespace_2b, (linenr - 1), 0, {end_row = (linenr + 1), end_col = 0, hl_eol = true, hl_group = "CursorLine"})
end
local function move_odds_only(winid)
  local _let_10_ = nvim_win_get_cursor(0)
  local cur_line = _let_10_[1]
  local cur_col = _let_10_[2]
  if psl["even?"](cur_line) then
    if (cur_line == _2alast_line_2a) then
      nvim_win_set_cursor(winid, {(cur_line - 1), cur_col})
    elseif (_2aprev_line_2a < cur_line) then
      nvim_win_set_cursor(winid, {(cur_line + 1), cur_col})
    elseif (_2aprev_line_2a > cur_line) then
      nvim_win_set_cursor(winid, {(cur_line - 1), cur_col})
    else
    end
  else
  end
  do
    local cur_line0 = vim.fn.line(".")
    _2aprev_line_2a = cur_line0
    double_cursorline(cur_line0)
  end
  return nil
end
local function win_callback(winid, bufnr)
  _2aprev_line_2a = 0
  _2alast_line_2a = nvim_buf_line_count(bufnr)
  local function _13_()
    return move_odds_only(winid)
  end
  return nvim_create_autocmd("CursorMoved", {buffer = bufnr, callback = _13_})
end
xref.open = function(content, config)
  local lines = content__3elines(content)
  local bufnr = buffer["create-scratch-with-conn-var!"](buffer["gen-name"](config["conn-name"], buffer.names.xref), _2bfiletype_2b)
  local function _14_(_241, _242)
    return win_callback(_241, _242)
  end
  return {window.center.open(bufnr, lines, {width = 80, height = 10, title = buffer.names.xref}, _14_), bufnr}
end
return xref
