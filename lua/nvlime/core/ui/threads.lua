local luaeval = vim.fn.luaeval
local getline = vim.fn.getline
local cursor = vim.fn.cursor
local setbufvar = vim.fn.setbufvar
local setpos = vim.fn.setpos
local getcurpos = vim.fn.getcurpos
local trim = vim.fn.trim
local split = vim.fn.split
local input = vim.fn.input
local strdisplaywidth = vim.fn.strdisplaywidth
local ui = require("nvlime.core.ui")
local threads = {}
threads["normalize-field-value"] = function(val)
  if (type(val) == "string") then
    return val
  else
    if (type(val) == "table") then
      return val.name
    else
      return tostring(val)
    end
  end
end
threads["calc-field-width"] = function(field, thread_list)
  local max_width = 0
  for _, thread in ipairs(thread_list) do
    local str_width = strdisplaywidth(threads["normalize-field-value"](thread[(field + 1)]))
    if (str_width > max_width) then
      max_width = str_width
    else
    end
  end
  return max_width
end
threads["calc-all-field-widths"] = function(thread_list)
  local header = thread_list[1]
  local widths = {}
  for idx, _ in pairs(header) do
    widths[idx] = threads["calc-field-width"](idx, thread_list)
  end
  return widths
end
threads["create-thread-field"] = function(field_widths, thread)
  local field = ""
  local idx = 0
  for _, column in ipairs(thread) do
    do
      local width = field_widths[(idx + 1)]
      local n_str = threads["normalize-field-value"](column)
      if (idx > 0) then
        field = (field .. ui.pad((vim.g.nvlime_vert_sep .. " " .. n_str), "", (width + 2)))
      else
        field = (field .. ui.pad((" " .. n_str), "", (width + 1)))
      end
    end
    idx = (idx + 1)
  end
  return field
end
threads["fill-threads-buf"] = function(conn, thread_list)
  local field_widths = threads["calc-all-field-widths"](thread_list)
  local horiz_sep = vim.g.nvlime_horiz_sep
  local win_width = 0
  for _, w in ipairs(field_widths) do
    win_width = (win_width + w)
  end
  win_width = (win_width + 8)
  local header_line = threads["create-thread-field"](field_widths, thread_list[1])
  local sep_line = (string.rep(horiz_sep, (field_widths[1] + 1)) .. "\226\148\128\226\148\188\226\148\128" .. string.rep(horiz_sep, field_widths[2]) .. "\226\148\128\226\148\188\226\148\128" .. string.rep(horiz_sep, (field_widths[3] + 1)))
  local lines = {header_line, sep_line}
  local coords = {}
  local idx = 0
  for i = 2, #thread_list do
    local thread = thread_list[i]
    table.insert(lines, threads["create-thread-field"](field_widths, thread))
    coords[thread[1]] = idx
    idx = (idx + 1)
  end
  local _let_5_ = luaeval("require(\"nvlime.window.threads\").open(_A[1], _A[2])", {lines, {["conn-name"] = conn.cb_data.name}})
  local _win_id = _let_5_[1]
  local buf_nr = _let_5_[2]
  setbufvar(buf_nr, "nvlime_thread_coords", coords)
  return cursor(3, 1)
end
threads["interrupt-cur-thread"] = function()
  local id = tonumber(getline("."))
  if (id > 0) then
    return vim.b.nvlime_conn("Interrupt", id)
  else
    return nil
  end
end
threads["kill-cur-thread"] = function()
  local field = getline(".")
  local id = tonumber(field)
  if (id > 0) then
    local parts = split(field, vim.g.nvlime_vert_sep)
    local thread_name = trim(parts[2], " ", 0)
    local coords = vim.b.nvlime_thread_coords
    local answer = input(("Kill thread \"" .. thread_name .. "\"? (y/n) "))
    if ui["is-yes-string"](answer) then
      local function _7_(c, _r)
        return threads.refresh(c)
      end
      return vim.b.nvlime_conn("KillNthThread", coords[id], _7_)
    else
      return ui["err-msg"]("Canceled.")
    end
  else
    return nil
  end
end
threads["debug-cur-thread"] = function()
  local id = tonumber(getline("."))
  if (id > 0) then
    return vim.b.nvlime_conn("DebugNthThread", vim.b.nvlime_thread_coords[id])
  else
    return nil
  end
end
threads.refresh = function(conn, keep_cur_pos)
  local keep_cur_pos0 = (keep_cur_pos or true)
  local cur_pos
  if keep_cur_pos0 then
    cur_pos = getcurpos()
  else
    cur_pos = nil
  end
  local conn0 = (conn or vim.b.nvlime_conn)
  local function _12_(c, result)
    c.ui.OnThreads(c, result)
    if cur_pos then
      return setpos(".", cur_pos)
    else
      return nil
    end
  end
  return conn0("ListThreads", _12_)
end
return threads
