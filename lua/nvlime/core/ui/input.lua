local nvim_buf_delete = vim.api.nvim_buf_delete
local luaeval = vim.fn.luaeval
local bufnr = vim.fn.bufnr
local getline = vim.fn.getline
local cursor = vim.fn.cursor
local mode = vim.fn.mode
local ui = require("nvlime.core.ui")
local input = {}
vim.g["nvlime_input_history"] = {}
input["check-input-validity"] = function(str_val, cb, cancellable)
  if (#str_val > 0) then
    cb(str_val)
    __fnl_global__return()
  else
  end
  local history_len = #vim.g.nvlime_input_history
  if (history_len > 0) then
    cb(vim.g.nvlime_input_history[history_len])
  else
  end
  if ((history_len == 0) and cancellable) then
    return ui["err-msg"]("Canceled.")
  else
    return nil
  end
end
input["from-buffer"] = function(conn, prompt, init_val, complete_cb)
  local _let_4_ = luaeval("require(\"nvlime.window.input\").open(_A[1], _A[2])", {init_val, {["conn-name"] = conn.cb_data.name, prompt = prompt}})
  local _win_id = _let_4_[1]
  local buf_nr = _let_4_[2]
  vim.fn.setbufvar(buf_nr, "nvlime_input_complete_cb", complete_cb)
  return cursor("$", (#getline("$") + 1))
end
input["maybe-input"] = function(str, str_cb, prompt, default, conn, comp_type)
  local default0 = (default or "")
  local comp_type0 = (comp_type or nil)
  if not str then
    if not conn then
      local content
      if comp_type0 then
        content = vim.fn.input(prompt, default0, comp_type0)
      else
        content = vim.fn.input(prompt, default0)
      end
      return input["check-input-validity"](content, str_cb, true)
    else
      local cur_package = conn["get-current-package"](conn)
      local cur_buf = bufnr("%")
      local callback
      local function _6_()
        local function _7_(s)
          local function _8_()
            return str_cb(s)
          end
          return ui["with-buffer"](cur_buf, _8_)
        end
        return input["check-input-validity"](ui["cur-buffer-content"](true), _7_, true)
      end
      callback = _6_
      input["from-buffer"](conn, prompt, default0, callback)
      if (bufnr("%") ~= cur_buf) then
        return conn["set-current-package"](conn, cur_package)
      else
        return nil
      end
    end
  else
    return input["check-input-validity"](str, str_cb, false)
  end
end
input["from-buffer-complete"] = function()
  local buf = bufnr("%")
  local callback = vim.fn.getbufvar(buf, "nvlime_input_complete_cb", nil)
  if not callback then
    __fnl_global__return()
  else
  end
  do
    local content = ui["cur-buffer-content"](true)
    if (#content > 0) then
      input["save-history"](content)
    else
    end
  end
  if string.match(mode(), "^i") then
    vim.cmd("stopinsert")
  else
  end
  callback()
  if vim.fn.bufloaded(buf) then
    return nvim_buf_delete(buf, {force = true})
  else
    return nil
  end
end
input["save-history"] = function(text)
  local max_items = (vim.g.nvlime_options.input_history_limit or 100)
  local history = vim.g.nvlime_input_history
  if ((#history > 0) and (history[#history] == text)) then
    __fnl_global__return()
  else
  end
  local prev_idx = vim.fn.index(history, text)
  while (prev_idx >= 0) do
    vim.fn.remove(history, prev_idx)
    prev_idx = vim.fn.index(history, text)
  end
  table.insert(history, text)
  if (#history > max_items) then
    local delta = (#history - max_items)
    history = vim.fn.slice(history, delta)
  else
  end
  vim.g["nvlime_input_history"] = history
  return nil
end
input["get-history"] = function(backward, idx)
  local history_len = #vim.g.nvlime_input_history
  if (history_len == 0) then
    return {0, ""}
  else
    local idx0 = (idx or history_len)
    if backward then
      if (idx0 <= 0) then
        return {0, ""}
      else
        local idx1
        if (idx0 > history_len) then
          idx1 = history_len
        else
          idx1 = idx0
        end
        return {(idx1 - 1), vim.g.nvlime_input_history[idx1]}
      end
    else
      if (idx0 >= (history_len - 1)) then
        return {history_len, ""}
      else
        local idx1
        if (idx0 < -1) then
          idx1 = -1
        else
          idx1 = idx0
        end
        return {(idx1 + 1), vim.g.nvlime_input_history[(idx1 + 2)]}
      end
    end
  end
end
input["next-history-item"] = function(backward)
  local backward0 = (backward or true)
  local next_idx, text
  if vim.fn.exists("b:nvlime_input_history_idx") then
    next_idx, text = input["get-history"](backward0, vim.b.nvlime_input_history_idx)
  else
    vim.b.nvlime_input_orig_text = ui["cur-buffer-content"](true)
    next_idx, text = input["get-history"](backward0)
  end
  vim.b.nvlime_input_history_idx = next_idx
  if (#text > 0) then
    vim.fn["nvlime#ClearCurrentBuffer"]()
    ui["append-string"](text, nil)
  else
    if ((next_idx > 0) and vim.fn.exists("b:nvlime_input_orig_text")) then
      vim.fn.unlet("b:nvlime_input_history_idx")
      vim.fn["nvlime#ClearCurrentBuffer"]()
      ui["append-string"](vim.b.nvlime_input_orig_text, nil)
      vim.fn.unlet("b:nvlime_input_orig_text")
    else
    end
  end
  return cursor("$", (#getline("$") + 1))
end
return input
