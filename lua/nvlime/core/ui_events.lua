local nvim_create_autocmd = vim.api.nvim_create_autocmd
local nvim_buf_set_var = vim.api.nvim_buf_set_var
local luaeval = vim.fn.luaeval
local cursor = vim.fn.cursor
local call = vim.fn.call
local ui = require("nvlime.core.ui")
local connection = require("nvlime.core.connection")
ui["on-debug"] = function(self, conn, thread, level, condition, restarts, frames, conts)
  local _let_1_ = luaeval("require('nvlime.window.main.sldb').open(_A[1], _A[2])", {{}, {["conn-name"] = conn.cb_data.name, thread = thread, frames = frames, level = level}})
  local _ = _let_1_[1]
  local bufnr = _let_1_[2]
  local function _2_()
    return call(vim.fn["nvlime#ui#sldb#FillSLDBBuf"], {thread, level, condition, restarts, frames})
  end
  return ui["with-buffer"](bufnr, _2_)
end
ui["on-debug-activate"] = function(self, conn, thread, level, select)
  local _let_3_ = luaeval("require('nvlime.window.main.sldb').open(_A[1], _A[2])", {{}, {["conn-name"] = conn.cb_data.name, thread = thread}})
  local _ = _let_3_[1]
  local bufnr = _let_3_[2]
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
  local function _6_()
    return __fnl_global__return_2dmini_2dbuffer_2dcontent(thread, ttag)
  end
  return call(vim.fn["nvlime#ui#input#FromBuffer"], {conn, "Input string:", nil, _6_})
end
ui["on-read-from-minibuffer"] = function(self, conn, thread, ttag, prompt, init_val)
  local function _7_()
    return __fnl_global__return_2dstring_2dinput_2dcomplete(thread, ttag)
  end
  return call(vim.fn["nvlime#ui#input#FromBuffer"], {conn, prompt, init_val, _7_})
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
  local _9_
  if new_features then
    _9_ = new_features
  else
    _9_ = {}
  end
  conn.cb_data["features"] = _9_
  return nil
end
ui["on-invalid-rpc"] = function(self, conn, rpc_id, err_msg)
  return ui["err-msg"](err_msg)
end
ui["on-inspect"] = function(self, conn, content, thread, tag)
  local _let_11_ = luaeval("require('nvlime.window.inspector').open(_A)", content)
  local _ = _let_11_[1]
  local bufnr = _let_11_[2]
  if thread then
    self["set-current-thread"](self, thread, bufnr)
    if tag then
      local ret_callback
      local function _12_()
        return call(vim.b.nvlime_conn.Return, {thread, tag, nil})
      end
      ret_callback = _12_
      return nvim_create_autocmd("BufWinLeave", {buffer = bufnr, once = true, callback = ret_callback})
    else
      return nil
    end
  else
    return nil
  end
end
ui["on-trace-dialog"] = function(self, conn, spec_list, trace_count)
  local trace_buf = call(vim.fn["nvlime#ui#trace_dialog#InitTraceDialogBuf"], {conn})
  ui["open-buffer-with-win-settings"](trace_buf, false, "trace")
  return call(vim.fn["nvlime#ui#trace_dialog#FillTraceDialogBuf"], {spec_list, trace_count})
end
ui["on-xref"] = function(self, conn, xref_list)
  return cond(not xref_list, ui["err-msg"]("No xref found."), ((type(xref_list) == "table") and (xref_list.name == "NOT-IMPLEMENTED")), ui["err-msg"]("Not implemented."), "else", call(vim.fn["nvlime#ui#xref#OpenXRefBuf"], {conn, xref_list}))
end
ui["on-compiler-notes"] = function(self, conn, note_list, orig_win)
  if not note_list then
    __fnl_global__return()
  else
  end
  local _let_16_ = luaeval("require('nvlime.window.main.notes').open(_A)", {["conn-name"] = conn.cb_data.name})
  local _ = _let_16_[1]
  local bufnr = _let_16_[2]
  nvim_buf_set_var(bufnr, "nvlime_notes_orig_win", orig_win)
  nvim_buf_set_var(bufnr, "nvlime_conn", conn)
  return call(vim.fn["nvlime#ui#compiler_notes#FillCompilerNotesBuf"], {note_list})
end
ui["on-threads"] = function(self, conn, thread_list)
  if not thread_list then
    ui["err-msg"]("The thread list is empty.")
    __fnl_global__return()
  else
  end
  return call(vim.fn["nvlime#ui#threads#FillThreadsBuf"], {conn, thread_list})
end
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
return ui
