local connection = require("nvlime.core.connection")
local ui = require("nvlime.core.ui")
local mrepl_ui = require("nvlime.core.ui.mrepl")
local function append_output(repl_buf, str)
  setbufvar(repl_buf, "modifiable", 1)
  local function _1_()
    return vim.fn["nvlime#ui#AppendString"](str)
  end
  vim.fn["nvlime#ui#WithBuffer"](repl_buf, _1_)
  return setbufvar(repl_buf, "modifiable", 0)
end
local function ensure_buffer_open(buf, win_type)
  if (#vim.fn.win_findbuf(buf) <= 0) then
    local function _2_()
      return vim.fn["nvlime#ui#OpenBufferWithWinSettings"](buf, false, win_type)
    end
    return vim.fn["nvlime#ui#KeepCurWindow"](_2_)
  else
    return nil
  end
end
local function build_prompt(chan_obj)
  return (chan_obj.mrepl.prompt[1] .. "> ")
end
local function on_write_result(conn, chan_obj, msg)
  if conn.ui then
    return conn:ui()("OnMREPLWriteResult", conn, chan_obj, msg[2])
  else
    return nil
  end
end
local function on_write_string(conn, chan_obj, msg)
  if conn.ui then
    return conn:ui()("OnMREPLWriteString", conn, chan_obj, msg[2])
  else
    return nil
  end
end
local function on_prompt(conn, chan_obj, msg)
  chan_obj.mrepl["prompt"] = {msg[2], msg[3]}
  if conn.ui then
    return conn:ui()("OnMREPLPrompt", conn, chan_obj)
  else
    return nil
  end
end
local function on_set_read_mode(conn, chan_obj, msg)
  chan_obj.mrepl["mode"] = msg[2].name
  return nil
end
local function on_evaluation_aborted(conn, chan_obj, msg)
  if conn.ui then
    return conn:ui()("OnMREPLWriteResult", conn, chan_obj, "; Evaluation aborted")
  else
    return nil
  end
end
local channel_event_handlers = {["WRITE-RESULT"] = on_write_result, ["WRITE-STRING"] = on_write_string, PROMPT = on_prompt, ["SET-READ-MODE"] = on_set_read_mode, ["EVALUATION-ABORTED"] = on_evaluation_aborted}
local function mrepl_channel_cb(conn, chan_obj, msg)
  local msg_type = msg[1]
  local handler = get(channel_event_handlers, msg_type.name)
  if handler then
    handler(conn, chan_obj, msg)
  else
  end
  if (not handler and (vim.g._nvlime_debug or false)) then
    return vim.fn.echom(("Unknown message: " .. vim.fn.string(msg)))
  else
    return nil
  end
end
local function create_mrepl_cb(conn, callback, local_chan, chan, msg)
  conn["check-return-status"](conn, msg, "nvlime.core.contrib.mrepl.create-mrepl")
  local mrepl_info = msg[2][2]
  local chan_id = mrepl_info[1]
  local thread_id = mrepl_info[2]
  local pkg_name = mrepl_info[3]
  local pkg_prompt = mrepl_info[4]
  local_chan.mrepl["peer"] = chan_id
  local_chan.mrepl["prompt"] = {pkg_name, pkg_prompt}
  do
    local remote_chan = conn["make-remote-channel"](conn, chan_id)
    remote_chan["mrepl"] = {thread = thread_id, peer = local_chan.id}
  end
  return conn["try-to-call"](conn, callback, {conn, mrepl_info})
end
connection["create-mrepl"] = function(self, chan_id, callback)
  local chan_id0 = (chan_id or vim.v.null)
  local callback0 = (callback or vim.v.null)
  local chan_obj = self["make-local-channel"](self, chan_id0, mrepl_channel_cb)
  chan_obj["mrepl"] = {mode = "EVAL"}
  local function _10_(msg)
    return create_mrepl_cb(self, callback0, chan_obj, nil, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-MREPL", "CREATE-MREPL"), chan_obj.id}), _10_)
end
ui["on-mrepl-write-result"] = function(self, conn, chan_obj, result)
  local mrepl_buf = mrepl_ui["init-mrepl-buf"](conn, chan_obj)
  ensure_buffer_open(mrepl_buf, "mrepl")
  return mrepl_ui["show-result"](mrepl_buf, result)
end
ui["on-mrepl-write-string"] = function(self, conn, chan_obj, content)
  local mrepl_buf = mrepl_ui["init-mrepl-buf"](conn, chan_obj)
  ensure_buffer_open(mrepl_buf, "mrepl")
  return append_output(mrepl_buf, content)
end
ui["on-mrepl-prompt"] = function(self, conn, chan_obj)
  local mrepl_buf = mrepl_ui["init-mrepl-buf"](conn, chan_obj)
  ensure_buffer_open(mrepl_buf, "mrepl")
  return mrepl_ui["show-prompt"](mrepl_buf, build_prompt(chan_obj))
end
connection["init-mrepl"] = function(self)
  self["CreateMREPL"] = connection["create-mrepl"]
  local ui_obj = ui["get-ui"]()
  ui_obj["OnMREPLWriteResult"] = ui["on-mrepl-write-result"]
  ui_obj["OnMREPLWriteString"] = ui["on-mrepl-write-string"]
  ui_obj["OnMREPLPrompt"] = ui["on-mrepl-prompt"]
  return nil
end
return connection
