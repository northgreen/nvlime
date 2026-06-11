local nvim_buf_set_name = vim.api.nvim_buf_set_name
local nvim_buf_set_var = vim.api.nvim_buf_set_var
local bufnr = vim.fn.bufnr
local bufname = vim.fn.bufname
local jobstop = vim.fn.jobstop
local inputlist = vim.fn.inputlist
local input = vim.fn.input
local matchlist = vim.fn.matchlist
local search = vim.fn.search
local getline = vim.fn.getline
local cursor = vim.fn.cursor
local getcurpos = vim.fn.getcurpos
local setpos = vim.fn.setpos
local exists = vim.fn.exists
local async = require("nvlime.core.async")
local ui = require("nvlime.core.ui")
local server = {}
local function _1_()
  return vim.g.nvlime_cl_wait_interval
end
if not pcall(_1_) then
  vim.g["nvlime_cl_wait_interval"] = 500
else
end
local function _3_()
  return vim.g.nvlime_servers
end
if not pcall(_3_) then
  vim.g["nvlime_servers"] = {}
else
end
local function _5_()
  return vim.g.nvlime_next_server_id
end
if not pcall(_5_) then
  vim.g["nvlime_next_server_id"] = 1
else
end
local nvlime_home
do
  local rtp = vim.o.runtimepath
  if (#rtp > 0) then
    local first_entry = vim.split(rtp, ",", {trimempty = true})
    nvlime_home = first_entry[1]
  else
    nvlime_home = vim.fn.getcwd()
  end
end
local path_sep = "/"
server["build-server-command-for-sbcl"] = function(loader, eval_str)
  return {"sbcl", "--load", loader, "--eval", eval_str}
end
server["build-server-command-for-ccl"] = function(loader, eval_str)
  return {"ccl", "--load", loader, "--eval", eval_str}
end
server["build-server-command"] = function(cl_impl)
  local cl_impl0 = (cl_impl or vim.g.nvlime_options.implementation)
  local nvlime_loader = (nvlime_home .. path_sep .. "lisp" .. path_sep .. "load-nvlime.lisp")
  local user_func_name = ("NvlimeBuildServerCommandFor_" .. cl_impl0)
  local default_func_name = ("nvlime#server#BuildServerCommandFor_" .. cl_impl0)
  local function _8_()
    local Builder = vim.fn[user_func_name]()
    return Builder(nvlime_loader, "(nvlime:main)")
  end
  local function _9_()
    local Builder = vim.fn[default_func_name]()
    return Builder(nvlime_loader, "(nvlime:main)")
  end
  return cond((exists(("*" .. user_func_name)) > 0)(_8_()), (exists(("*" .. default_func_name)) > 0)(_9_()), "else", error(("nvlime.core.server.build-server-command: implementation " .. vim.fn.string(cl_impl0) .. " not supported")))
end
local function normalize_server_id(id)
  if (type(id) == "table") then
    return id.id
  else
    return id
  end
end
local function match_server_created_port()
  local port_line_nr = 0
  local old_pos = getcurpos()
  local pattern = "Server created: (#([[:digit:][:blank:]]\\+)\\s\\+\\(\\d\\+\\))"
  local function _11_()
    cursor({1, 1, 0, 1})
    port_line_nr = search(pattern, "n")
    return nil
  end
  pcall(_11_)
  setpos(".", old_pos)
  if (port_line_nr > 0) then
    local port_line = getline(port_line_nr)
    local matched = matchlist(port_line, pattern)
    return tonumber(matched[1])
  else
    return nil
  end
end
local function server_output_cb(server_obj, auto_connect, data)
  if ((server_obj.port or 0) > 0) then
  else
  end
  for _, line in ipairs(data) do
    local matched = matchlist(line, "Server created: (#([[:digit:][:blank:]]\\+)\\s\\+\\(\\d\\+\\))")
    if (#matched > 0) then
      local port = tonumber(matched[1])
      server_obj["port"] = port
      vim.cmd(("echom 'Nvlime server listening on port " .. port .. "'"))
      if auto_connect then
        local auto_conn = vim.fn["nvlime#plugin#ConnectREPL"]("127.0.0.1", port)
        if auto_conn then
          auto_conn.cb_data["server"] = server_obj
          server_obj["connections"] = {[{auto_conn.cb_data.id}] = auto_conn}
        else
        end
      else
      end
    else
    end
  end
  local function server_exit_cb(server_obj0, exit_status)
    vim.g.nvlime_servers[server_obj0.id] = nil
    vim.cmd(("echom '" .. server_obj0.name .. " stopped.'"))
    local conn_dict = (server_obj0.connections or {})
    local conn_manager = require("nvlime.core.conn_manager")
    for conn_id, conn in pairs(conn_dict) do
      conn_manager.close(conn)
    end
    server_obj0["connections"] = {}
    return nil
  end
  server.new = function(auto_connect0, use_terminal, name, cl_impl)
    local auto_connect1 = (auto_connect0 or true)
    local use_terminal0 = (use_terminal or false)
    local server_name = (name or ("nvlime server " .. vim.g.nvlime_next_server_id))
    local server_id = vim.g.nvlime_next_server_id
    local _let_17_ = vim.fn.luaeval("require('nvlime.window.server').open(_A)", server_name)
    local _win = _let_17_[1]
    local bufnr0 = _let_17_[2]
    local server_obj0 = {id = server_id, name = server_name, auto_connect = auto_connect1, use_terminal = use_terminal0, cl_impl = cl_impl}
    local server_job
    local function _18_(data0)
      return server_output_cb(server_obj0, auto_connect1, data0)
    end
    local function _19_(exit_status)
      return server_exit_cb(server_obj0, exit_status)
    end
    server_job = async["job-start"](server["build-server-command"](cl_impl), {buf_name = bufname(bufnr0), callback = _18_, exit_cb = _19_, use_terminal = use_terminal0})
    if not async["job-is-active"](server_job) then
      vim.fn.luaeval("require('nvlime.buffer')['fill!'](_A[1], _A[2])", {bufnr0, "Failed to start server."})
      error("nvlime.core.server.new: failed to start server job")
    else
    end
    server_obj0["job"] = server_job
    vim.g.nvlime_servers[server_id] = server_obj0
    vim.g["nvlime_next_server_id"] = (server_id + 1)
    do
      local server_buf = async["job-getbufnr"](server_job)
      nvim_buf_set_var(server_buf, "nvlime_server", server_obj0)
    end
    return server_obj0
  end
  server.stop = function(server0)
    local server_id = normalize_server_id(server0)
    local r_server = vim.g.nvlime_servers[server_id]
    jobstop(r_server.job.job_id)
    local buf = async["job-getbufnr"](r_server.job)
    return ui["close-buffer"](buf)
  end
  server.rename = function(server0, new_name)
    local server_id = normalize_server_id(server0)
    local r_server = vim.g.nvlime_servers[server_id]
    local old_buf_name = ui["server-buf-name"](r_server.name)
    r_server["name"] = new_name
    local old_buf = bufnr(old_buf_name)
    if (old_buf > 0) then
      return nvim_buf_set_name(old_buf, ui["server-buf-name"](new_name))
    else
      return nil
    end
  end
  server.show = function(server0)
    local server_id = normalize_server_id(server0)
    local r_server = vim.g.nvlime_servers[server_id]
    return vim.fn.luaeval("require('nvlime.window.server').open(_A)", r_server.name)
  end
  server.select = function()
    if (#vim.g.nvlime_servers == 0) then
      ui["err-msg"]("No server started.")
    else
    end
    local server_names = {}
    for k, _ in pairs(vim.fn.sort(vim.fn.keys(vim.g.nvlime_servers), "n")) do
      local server0 = vim.g.nvlime_servers[k]
      local port = (server0.port or 0)
      table.insert(server_names, (k .. ". " .. server0.name .. " (" .. port .. ")"))
    end
    vim.cmd("echohl Question")
    vim.cmd("echom 'Select server:'")
    vim.cmd("echohl None")
    local server_nr = inputlist(server_names)
    if (server_nr == 0) then
      ui["err-msg"]("Canceled.")
      return nil
    else
      local server0 = vim.g.nvlime_servers[server_nr]
      if not server0 then
        ui["err-msg"](("Invalid server ID: " .. server_nr))
        return nil
      else
        return server0
      end
    end
  end
  server["connect-to-cur-server"] = function()
    local port = nil
    if async["job-is-active"](vim.b.nvlime_server.job) then
      port = (vim.b.nvlime_server.port or nil)
      if not port then
        ui["err-msg"]((vim.b.nvlime_server.name .. " is not ready."))
      else
      end
    else
      ui["err-msg"]((vim.b.nvlime_server.name .. " is not running."))
    end
    if not port then
    else
    end
    local conn = vim.fn["nvlime#plugin#ConnectREPL"]("127.0.0.1", port)
    if conn then
      conn.cb_data["server"] = vim.b.nvlime_server
      local conn_list = (vim.b.nvlime_server.connections or {})
      conn_list[conn.cb_data.id] = conn
      vim.b.nvlime_server["connections"] = conn_list
      return nil
    else
      return nil
    end
  end
  server["stop-cur-server"] = function()
    if not vim.g.nvlime_servers[vim.b.nvlime_server.id] then
      ui["err-msg"]((vim.b.nvlime_server.name .. " is not running."))
    else
    end
    local answer = input(("Stop server " .. vim.fn.string(vim.b.nvlime_server.name) .. "? (y/n) "))
    if ui["is-yes-string"](answer) then
      return server.stop(vim.b.nvlime_server)
    else
      return ui["err-msg"]("Canceled.")
    end
  end
  return server["stop-cur-server"]
end
local function _31_(self, key)
  return self[string.gsub(key, "_", "-")]
end
setmetatable(server, {__index = _31_})
return server
