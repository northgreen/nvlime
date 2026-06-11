local nvim_create_autocmd = vim.api.nvim_create_autocmd
local nvim_buf_set_var = vim.api.nvim_buf_set_var
local luaeval = vim.fn.luaeval
local cursor = vim.fn.cursor
local call = vim.fn.call
local ui = require("nvlime.core.ui")
local connection = require("nvlime.core.connection")
local xref = require("nvlime.core.ui.xref")
local function return_mini_buffer_content(thread, ttag)
  local content = ui["cur-buffer-content"](false)
  return call(vim.b.nvlime_conn.Return, {thread, ttag, content})
end
local function return_string_input_complete(thread, ttag)
  local content = ui["cur-buffer-content"](false)
  local content0
  if ((#content > 0) and (content[#content] ~= "\n")) then
    content0 = (content .. "\n")
  else
    content0 = content
  end
  return call(vim.b.nvlime_conn.ReturnString, {thread, ttag, content0})
end
ui["on-debug"] = function(self, conn, thread, level, condition, restarts, frames, conts)
  local _let_2_ = luaeval("require('nvlime.window.main.sldb').open(_A[1], _A[2])", {{}, {["conn-name"] = conn.cb_data.name, thread = thread, frames = frames, level = level}})
  local _ = _let_2_[1]
  local bufnr = _let_2_[2]
  local function _3_()
    local sldb = require("nvlime.core.ui.sldb")
    return sldb["fill-sldb-buf"](thread, level, condition, restarts, frames)
  end
  return ui["with-buffer"](bufnr, _3_)
end
ui["on-debug-activate"] = function(self, conn, thread, level, select)
  local _let_4_ = luaeval("require('nvlime.window.main.sldb').open(_A[1], _A[2])", {{}, {["conn-name"] = conn.cb_data.name, thread = thread}})
  local _ = _let_4_[1]
  local bufnr = _let_4_[2]
  if (bufnr > 0) then
    return cursor({1, 1, 0, 1})
  else
    return nil
  end
end
ui["on-debug-return"] = function(self, conn, thread, level, stepping)
  return luaeval("require('nvlime.window.main.sldb')['on-debug-return'](_A)", {["conn-name"] = conn.cb_data.name, thread = thread, level = level})
end
ui["on-write-string"] = function(self, conn, str, str_type, thread)
  luaeval("require('nvlime.window.main.repl').open(_A[1], _A[2])", {str, {["conn-name"] = conn.cb_data.name}})
  if thread then
    return conn:send({connection.kw("NVLIME-RAW-MSG"), ("(:WRITE-DONE " .. thread .. ")")}, nil)
  else
    return nil
  end
end
ui["on-read-string"] = function(self, conn, thread, ttag)
  local input = require("nvlime.core.ui.input")
  local function _7_()
    return return_mini_buffer_content(thread, ttag)
  end
  return input["from-buffer"](conn, "Input string:", nil, _7_)
end
ui["on-read-from-minibuffer"] = function(self, conn, thread, ttag, prompt, init_val)
  local input = require("nvlime.core.ui.input")
  local function _8_()
    return return_string_input_complete(thread, ttag)
  end
  return input["from-buffer"](conn, prompt, init_val, _8_)
end
ui["on-indentation-update"] = function(self, conn, indent_info)
  if not conn.cb_data["indent-info"] then
    conn.cb_data["indent-info"] = {}
  else
  end
  for _, i in ipairs(indent_info) do
    conn.cb_data["indent-info"][i[1]] = {(i[2] or nil), (i[3] or nil)}
  end
  return nil
end
ui["on-new-features"] = function(self, conn, new_features)
  local _10_
  if new_features then
    _10_ = new_features
  else
    _10_ = {}
  end
  conn.cb_data["features"] = _10_
  return nil
end
ui["on-invalid-rpc"] = function(self, conn, rpc_id, err_msg)
  return ui["err-msg"](err_msg)
end
ui["on-inspect"] = function(self, conn, content, thread, tag)
  local _let_12_ = luaeval("require('nvlime.window.inspector').open(_A)", content)
  local _ = _let_12_[1]
  local bufnr = _let_12_[2]
  if thread then
    self["set-current-thread"](self, thread, bufnr)
    if tag then
      local ret_callback
      local function _13_()
        return call(vim.b.nvlime_conn.Return, {thread, tag, nil})
      end
      ret_callback = _13_
      return nvim_create_autocmd("BufWinLeave", {buffer = bufnr, once = true, callback = ret_callback})
    else
      return nil
    end
  else
    return nil
  end
end
ui["on-trace-dialog"] = function(self, conn, spec_list, trace_count)
  local trace_dialog = require("nvlime.core.ui.trace_dialog")
  local trace_buf = trace_dialog["init-trace-dialog-buf"](conn)
  ui["open-buffer-with-win-settings"](trace_buf, false, "trace")
  return trace_dialog["fill-trace-dialog-buf"](spec_list, trace_count)
end
ui["on-xref"] = function(self, conn, xref_list)
  return cond(not xref_list, ui["err-msg"]("No xref found."), ((type(xref_list) == "table") and (xref_list.name == "NOT-IMPLEMENTED")), ui["err-msg"]("Not implemented."), "else", xref["open-xref-buf"](conn, xref_list))
end
ui["on-compiler-notes"] = function(self, conn, note_list, orig_win)
  if not note_list then
  else
  end
  local _let_17_ = luaeval("require('nvlime.window.main.notes').open(_A)", {["conn-name"] = conn.cb_data.name})
  local _ = _let_17_[1]
  local bufnr = _let_17_[2]
  nvim_buf_set_var(bufnr, "nvlime_notes_orig_win", orig_win)
  nvim_buf_set_var(bufnr, "nvlime_conn", conn)
  local compiler_notes = require("nvlime.core.ui.compiler_notes")
  return compiler_notes["fill-buffer"](note_list)
end
ui["on-threads"] = function(self, conn, thread_list)
  if not thread_list then
    ui["err-msg"]("The thread list is empty.")
  else
  end
  local threads = require("nvlime.core.ui.threads")
  return threads["fill-threads-buf"](conn, thread_list)
end
local function _19_(self, key)
  return self[string.gsub(key, "_", "-")]
end
setmetatable(ui, {__index = _19_})
return ui
