local nvim_err_writeln = vim.api.nvim_err_writeln
local nvim_get_chan_info = vim.api.nvim_get_chan_info
local nvim_buf_set_lines = vim.api.nvim_buf_set_lines
local nvim_get_option_value = vim.api.nvim_get_option_value
local nvim_set_option_value = vim.api.nvim_set_option_value
local sockconnect = vim.fn.sockconnect
local chansend = vim.fn.chansend
local jobstart = vim.fn.jobstart
local termopen = vim.fn.termopen
local bufnr = vim.fn.bufnr
local buffer = require("nvlime.buffer")
local logger = require("nvlime.logger")
local async = {}
local chan_registry = {}
local max_id = 65536
local function inc_msg_id(chan)
  if (chan.next_msg_id >= max_id) then
    chan.next_msg_id = 1
    return nil
  else
    chan.next_msg_id = (chan.next_msg_id + 1)
    return nil
  end
end
local function dispatch_msg(chan, json_obj)
  local msg_id = json_obj[1]
  local payload = json_obj[2]
  if msg_id then
    local CB
    if (msg_id == 0) then
      CB = chan.chan_callback
    else
      local cb = chan.msg_callbacks[msg_id]
      chan.msg_callbacks[msg_id] = nil
      CB = cb
    end
    if CB then
      local ok, err = pcall(CB, chan, payload)
      if not ok then
        logger:get():warn()(("callback failed: " .. tostring(err)))
        return nvim_err_writeln(("nvlime: callback failed: " .. tostring(err)))
      else
        return nil
      end
    else
      return logger:get():warn()(("dispatch: NO CALLBACK for msg-id=" .. tostring(msg_id)))
    end
  else
    return nil
  end
end
local function chan_input_cb(chan_id, data, event)
  local chan = chan_registry[chan_id]
  if chan then
    local obj_list = {}
    local buffered = (chan.recv_buffer or "")
    for _, frag in ipairs(data) do
      local ok, result = pcall(vim.json.decode, (buffered .. frag))
      if ok then
        table.insert(obj_list, result)
        buffered = ""
      else
        buffered = (buffered .. frag)
      end
    end
    chan.recv_buffer = buffered
    for _, json_obj in ipairs(obj_list) do
      dispatch_msg(chan, json_obj)
    end
    return nil
  else
    return nil
  end
end
async["ch-open"] = function(host, port, callback, timeout)
  local chan_obj = {hostname = host, port = port, on_data = chan_input_cb, next_msg_id = 1, msg_callbacks = {}}
  if callback then
    chan_obj["chan_callback"] = callback
  else
  end
  do
    local ok, ch_id = pcall(sockconnect, "tcp", (host .. ":" .. tostring(port)), chan_obj)
    if ok then
      chan_obj.ch_id = ch_id
      chan_obj.is_connected = true
      chan_registry[ch_id] = chan_obj
    else
      chan_obj.ch_id = nil
      chan_obj.is_connected = false
    end
  end
  do
    local waittime
    if timeout then
      waittime = (timeout + 500)
    else
      waittime = 500
    end
    vim.cmd(("sleep " .. waittime .. "m"))
  end
  return chan_obj
end
async["ch-sendexpr"] = function(chan, expr, callback)
  local real_chan = chan_registry[chan.ch_id]
  if not real_chan then
    error(("async.ch-sendexpr: channel " .. chan.ch_id .. " not in registry, connection may be closed"))
  else
  end
  local msg = {real_chan.next_msg_id, expr}
  if callback then
    real_chan.msg_callbacks[real_chan.next_msg_id] = callback
  else
  end
  inc_msg_id(real_chan)
  local ret = chansend(real_chan.ch_id, (vim.json.encode(msg) .. "\n"))
  if (ret == 0) then
    real_chan.is_connected = false
    error("async.ch-sendexpr: chansend() failed")
  else
  end
  return ret
end
async["job-start"] = function(cmd, opts)
  local buf_name = opts.buf_name
  local callback = opts.callback
  local exit_cb = opts.exit_cb
  if opts.use_terminal then
    local job_obj = {use_terminal = true}
    local function _14_(job_id, data, event_name)
      if callback then
        return callback(data)
      else
        return nil
      end
    end
    job_obj["on_stdout"] = _14_
    local function _16_(job_id, exit_code, event_name)
      if exit_cb then
        return exit_cb(exit_code)
      else
        return nil
      end
    end
    job_obj["on_exit"] = _16_
    job_obj.job_id = termopen(cmd, job_obj)
    job_obj.out_buf = bufnr("$")
    return job_obj
  else
    local buf = bufnr(buf_name, true)
    nvim_set_option_value("buftype", "nofile", {buf = buf})
    nvim_set_option_value("bufhidden", "hide", {buf = buf})
    nvim_set_option_value("swapfile", false, {buf = buf})
    nvim_set_option_value("buflisted", true, {buf = buf})
    nvim_set_option_value("modifiable", false, {buf = buf})
    local job_obj = {out_name = buf_name, err_name = buf_name, out_buf = buf, err_buf = buf, use_terminal = false}
    local function _18_(job_id, data, event_name)
      if callback then
        callback(data)
      else
      end
      return buffer["with-modifiable"](buf, nvim_buf_set_lines(buf, -1, -1, false, data))
    end
    job_obj["on_stdout"] = _18_
    local function _20_(job_id, data, event_name)
      if callback then
        callback(data)
      else
      end
      return buffer["with-modifiable"](buf, nvim_buf_set_lines(buf, -1, -1, false, data))
    end
    job_obj["on_stderr"] = _20_
    local function _22_(job_id, exit_code, event_name)
      if exit_cb then
        return exit_cb(exit_code)
      else
        return nil
      end
    end
    job_obj["on_exit"] = _22_
    job_obj.job_id = jobstart(cmd, job_obj)
    return job_obj
  end
end
async["job-is-active"] = function(job)
  local job_info = nvim_get_chan_info(job.job_id)
  return not vim.tbl_isempty(job_info)
end
async["job-getbufnr"] = function(job)
  return (job.out_buf or 0)
end
local function _25_(self, key)
  local new_key = string.gsub(key, "_", "-")
  if (new_key == key) then
    return nil
  else
    return self[new_key]
  end
end
setmetatable(async, {__index = _25_})
return async
