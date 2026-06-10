local connection = require("nvlime.core.connection")
local function check_return_status(return_msg, caller)
  local status = return_msg[2][1]
  if not (status.name == "OK") then
    local payload = return_msg[2]
    return error((caller .. " returned: " .. vim.inspect(payload)))
  else
    return nil
  end
end
local function try_to_call(callback, args)
  if (type(callback) == "function") then
    return callback(unpack(args))
  else
    return nil
  end
end
connection["emacs-rex"] = function(self, cmd)
  local pkg_info = self["get-current-package"](self)
  local pkg
  if (type(pkg_info) ~= "table") then
    pkg = nil
  else
    pkg = pkg_info[1]
  end
  local thread = self["get-current-thread"](self)
  return {connection.kw("EMACS-REX"), cmd, pkg, thread}
end
connection.ping = function(self)
  local cur_tag = self.ping_tag
  if (self.ping_tag >= 65536) then
    self.ping_tag = 1
  else
    self.ping_tag = (self.ping_tag + 1)
  end
  local result = self:call(self["emacs-rex"](self, {connection.sym("SWANK", "PING"), cur_tag}))
  if ((type(result) == "string") and (string.len(result) == 0)) then
    error("nvlime#Ping: failed")
  else
  end
  check_return_status(result, "nvlime#Ping")
  if (result[2][2] ~= cur_tag) then
    return error("nvlime#Ping: bad tag")
  else
    return nil
  end
end
connection.pong = function(self, thread, ttag)
  return self:send({connection.kw("EMACS-PONG"), thread, ttag}, nil)
end
connection["connection-info"] = function(self, return_dict, callback)
  local return_dict0 = (return_dict or true)
  local callback0 = (callback or nil)
  local cb_wrapper
  local function _7_(chan, msg)
    check_return_status(msg, "nvlime#ConnectionInfo")
    if return_dict0 then
      return try_to_call(callback0, {self, self["plist-to-dict"](self, msg[2][2])})
    else
      return try_to_call(callback0, {self, msg[2][2]})
    end
  end
  cb_wrapper = _7_
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "CONNECTION-INFO")}), cb_wrapper)
end
connection["swank-require"] = function(self, contrib, callback)
  local required
  if (type(contrib) == "table") then
    local function _9_(name)
      return connection.kw(name)
    end
    required = {connection.cl("QUOTE"), vim.tbl_map(_9_, contrib)}
  else
    required = connection.kw(contrib)
  end
  local function _11_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#SwankRequire", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SWANK-REQUIRE"), required}), _11_)
end
connection.interrupt = function(self, thread)
  return self:send({connection.kw("EMACS-INTERRUPT"), thread}, nil)
end
connection["simple-send-cb"] = function(self, callback, caller, chan, msg)
  check_return_status(msg, caller)
  return try_to_call(callback, {self, msg[2][2]})
end
connection["sldb-send-cb"] = function(self, callback, caller, chan, msg)
  do
    local status = msg[2][1]
    if ((status.name ~= "ABORT") and (status.name ~= "OK")) then
      local payload = msg[2]
      error((caller .. " returned: " .. vim.inspect(payload)))
    else
    end
  end
  return try_to_call(callback, {self, msg[2][2]})
end
connection["plist-to-dict"] = function(self, plist)
  if not plist then
    return {}
  else
    local d = {}
    for i = 1, #plist, 2 do
      d[plist[i].name] = plist[(i + 1)]
    end
    return d
  end
end
connection["chain-callbacks"] = function(self, ...)
  local cbs = {...}
  if (#cbs < 1) then
  else
  end
  local function chain_cb(remaining, ...)
    if (#remaining < 1) then
    else
    end
    do
      local cb = remaining[1]
      if cb then
        cb(unpack({...}))
      else
      end
    end
    if (#remaining >= 2) then
      local next_fn = remaining[2]
      local function _17_(...)
        return chain_cb(vim.list_slice(remaining, 3), ...)
      end
      return next_fn(_17_)
    else
      return nil
    end
  end
  local first_fn = cbs[1]
  local function _19_(...)
    return chain_cb(vim.list_slice(cbs, 2), ...)
  end
  return first_fn(_19_)
end
connection["check-return-status"] = check_return_status
connection["try-to-call"] = try_to_call
return connection
