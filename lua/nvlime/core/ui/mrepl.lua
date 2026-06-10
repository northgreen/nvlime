local bufnr = vim.fn.bufnr
local getline = vim.fn.getline
local setbufvar = vim.fn.setbufvar
local getcurpos = vim.fn.getcurpos
local setpos = vim.fn.setpos
local searchpos = vim.fn.searchpos
local feedkeys = vim.fn.feedkeys
local ui = require("nvlime.core.ui")
local connection = require("nvlime.core.connection")
mrepl({})
mrepl["show-prompt-or-result"] = function(content)
  local last_line = getline("$")
  if (#last_line > 0) then
    return ui["append-string"](("\n" .. content))
  else
    return ui["append-string"](content)
  end
end
mrepl["show-banner"] = function(conn, chan_obj)
  local banner = "MREPL - SWANK"
  if conn.cb_data.version then
    banner = (banner .. " version " .. conn.cb_data.version)
  else
  end
  if conn.cb_data.pid then
    banner = (banner .. ", pid " .. conn.cb_data.pid)
  else
  end
  do
    local remote_chan_id = chan_obj.mrepl.peer
    local remote_chan_obj = conn.remote_channels[remote_chan_id]
    banner = (banner .. ", thread " .. remote_chan_obj.mrepl.thread)
  end
  do
    local banner_len = #banner
    banner = (banner .. "\n" .. string.rep("=", banner_len) .. "\n")
  end
  return ui["append-string"](banner)
end
mrepl["init-mrepl-buf-internal"] = function(conn, chan_obj)
  vim.bo.autoindent = false
  vim.bo.cindent = false
  vim.bo.smartindent = false
  vim.bo.iskeyword = "@,48-57,_,192-255,+,-,*,/,%,<,=,>,:,$,?,!,@-@,94"
  vim.bo.omnifunc = "nvlime#plugin#CompleteFunc"
  vim.bo.indentexpr = "nvlime#plugin#CalcCurIndent()"
  return mrepl["show-banner"](conn, chan_obj)
end
mrepl["kill-thread-complete"] = function(mrepl_buf, conn, _result)
  local local_chan = vim.fn.getbufvar(mrepl_buf, "nvlime_mrepl_channel", nil)
  if local_chan then
    vim.cmd(("bunload! " .. mrepl_buf))
    conn["remove-remote-channel"](conn, local_chan.mrepl.peer)
    return conn["remove-local-channel"](conn, local_chan.id)
  else
    return nil
  end
end
mrepl["init-mrepl-buf"] = function(conn, chan_obj)
  local mrepl_buf = bufnr(ui["mrepl-buf-name"](conn, chan_obj), 1)
  if not ui["nvlime-buffer-initialized"](mrepl_buf) then
    ui["set-nvlime-buffer-opts"](mrepl_buf, conn)
    setbufvar(mrepl_buf, "nvlime_mrepl_channel", chan_obj)
    setbufvar(mrepl_buf, "&filetype", "nvlime_mrepl")
    local function _5_()
      return mrepl["init-mrepl-buf-internal"](conn, chan_obj)
    end
    ui["with-buffer"](mrepl_buf, _5_)
  else
  end
  return mrepl_buf
end
mrepl["show-prompt"] = function(buf, prompt)
  local function _7_()
    return mrepl["show-prompt-or-result"](prompt)
  end
  ui["with-buffer"](buf, _7_)
  if (bufnr("%") == buf) then
    vim.cmd("normal! G")
    return feedkeys("<End>", "n")
  else
    return nil
  end
end
mrepl["show-result"] = function(buf, result)
  local function _9_()
    return mrepl["show-prompt-or-result"](result)
  end
  return ui["with-buffer"](buf, _9_)
end
mrepl.submit = function()
  local read_mode = vim.b.nvlime_mrepl_channel.mrepl.mode
  if (read_mode == "EVAL") then
    local prompt = vim.fn.eval("nvlime#contrib#mrepl#BuildPrompt(b:nvlime_mrepl_channel)")
    local old_pos = getcurpos()
    vim.cmd("normal! G$")
    local eof_pos = getcurpos()
    local insert_newline_3f = ((old_pos[1] < eof_pos[1]) or ((old_pos[1] == eof_pos[1]) and (old_pos[2] <= eof_pos[2])))
    local last_prompt_pos = searchpos(("\\V" .. prompt), "bcenW")
    setpos(".", old_pos)
    local from_pos = {(last_prompt_pos[1] + 1), (last_prompt_pos[2] + 1)}
    local to_pos = {(eof_pos[1] + 0), (eof_pos[2] + 1)}
    local to_send = ui["get-text"](from_pos, to_pos)
    local peer = vim.b.nvlime_mrepl_channel.mrepl.peer
    local msg = vim.b.nvlime_conn:EmacsChannelSend(peer, {connection.kw("PROCESS"), to_send})
    vim.b.nvlime_conn:Send(msg)
    if insert_newline_3f then
      return "<CR>"
    else
      return "<Esc>GA<CR>"
    end
  else
    local to_send = (getline("$") .. "\n")
    local peer = vim.b.nvlime_mrepl_channel.mrepl.peer
    local msg = vim.b.nvlime_conn:EmacsChannelSend(peer, {connection.kw("PROCESS"), to_send})
    vim.b.nvlime_conn:Send(msg)
    return "<CR>"
  end
end
mrepl.clear = function()
  vim.fn["nvlime#ClearCurrentBuffer"]()
  mrepl["show-banner"](vim.b.nvlime_conn, vim.b.nvlime_mrepl_channel)
  local prompt = vim.fn.eval("nvlime#contrib#mrepl#BuildPrompt(b:nvlime_mrepl_channel)")
  return mrepl["show-prompt"](bufnr("%"), prompt)
end
mrepl.disconnect = function()
  local remote_chan_id = vim.b.nvlime_mrepl_channel.mrepl.peer
  local remote_chan = vim.b.nvlime_conn.remote_channels[remote_chan_id]
  local remote_thread = remote_chan.mrepl.thread
  local cmd = {connection.kw("EMACS-REX"), {connection.sym("SWANK/BACKEND", "KILL-THREAD"), {connection.sym("SWANK/BACKEND", "FIND-THREAD"), remote_thread}}, nil, true}
  local function _12_(chan, msg)
    local function _13_(_241, _242)
      return mrepl["kill-thread-complete"](bufnr("%"), vim.b.nvlime_conn, _242)
    end
    return vim.b.nvlime_conn["simple-send-cb"](vim.b.nvlime_conn, _13_, "nvlime#ui#mrepl#Disconnect", chan, msg)
  end
  return vim.b.nvlime_conn:Send(cmd, _12_)
end
mrepl.interrupt = function()
  do
    local remote_chan_id = vim.b.nvlime_mrepl_channel.mrepl.peer
    local remote_chan = vim.b.nvlime_conn.remote_channels[remote_chan_id]
    vim.b.nvlime_conn:Interrupt(remote_chan.mrepl.thread)
  end
  return ""
end
return mrepl
