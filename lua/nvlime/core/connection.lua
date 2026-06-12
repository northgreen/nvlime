local chanclose = vim.fn.chanclose
local async = require("nvlime.core.async")
local connection = {}
connection.sym = function(package, name)
  return {name = name, package = package}
end
connection.kw = function(name)
  return connection.sym("KEYWORD", name)
end
connection.cl = function(name)
  return connection.sym("COMMON-LISP", name)
end
connection["has-key"] = function(dict, key)
  if (type(key) == "string") then
    return (dict[key] or dict[string.upper(key)] or dict[string.lower(key)])
  else
    return dict[key]
  end
end
connection.get = function(dict, key, default)
  if (type(key) == "string") then
    return (dict[key] or dict[string.upper(key)] or dict[string.lower(key)] or default)
  else
    return (dict[key] or default)
  end
end
connection.new = function(cb_data, ui)
  local self = {cb_data = cb_data, channel = nil, remote_prefix = "", ping_tag = 1, next_local_channel_id = 1, local_channels = {}, remote_channels = {}, ui = ui, server_event_handlers = {}}
  require("nvlime.core.connection.channels")
  require("nvlime.core.connection.messages")
  require("nvlime.core.connection.sldb")
  require("nvlime.core.connection.inspector")
  require("nvlime.core.connection.swank")
  require("nvlime.core.connection.events")
  for k, v in pairs(connection) do
    if (type(v) == "function") then
      self[k] = v
    else
    end
  end
  self["setup-event-handlers"](self)
  setmetatable(self, {__index = connection})
  return self
end
connection.connect = function(self, host, port, prefix, timeout)
  do
    local callback
    local function _4_(chan, msg)
      return self["on-server-event"](self, chan, msg)
    end
    callback = _4_
    self.channel = async["ch-open"](host, port, callback, timeout)
  end
  if not self.channel.is_connected then
    self:close()
    error("nvlime#Connect: failed to open channel")
  else
  end
  self.remote_prefix = (prefix or "")
  return self
end
connection.close = function(self)
  if (self.channel and self.channel.ch_id) then
    pcall(chanclose, self.channel.ch_id)
    self.channel = nil
  else
  end
  return self
end
connection["is-connected"] = function(self)
  return (self.channel and self.channel.is_connected)
end
connection.call = function(self, msg)
  local encoded = vim.json.encode(msg)
  local ok, result = pcall(vim.fn.ch_evalexpr, self.channel.ch_id, encoded)
  if ok then
    return result
  else
    return error(("nvlime#Call: " .. tostring(result)))
  end
end
connection.send = function(self, msg, callback)
  return async["ch-sendexpr"](self.channel, msg, callback)
end
connection["fix-remote-path"] = function(self, path)
  local prefix = (self.remote_prefix or "")
  if (string.len(prefix) == 0) then
    return path
  else
    local case_8_ = type(path)
    if (case_8_ == "string") then
      return (prefix .. path)
    elseif (case_8_ == "table") then
      local loc_data = path[2]
      if loc_data then
        local loc_type = loc_data[1]
        if (loc_type == "FILE") then
          loc_data[2] = (prefix .. loc_data[2])
        else
        end
        if (loc_type == "BUFFER-AND-FILE") then
          loc_data[3] = (prefix .. loc_data[3])
        else
        end
        return path
      else
        return error(("nvlime#FixRemotePath: unknown path: " .. tostring(path)))
      end
    else
      local _ = case_8_
      return error(("nvlime#FixRemotePath: unknown path: " .. tostring(path)))
    end
  end
end
connection["fix-local-path"] = function(self, path)
  if not (type(path) == "string") then
    return path
  else
    local prefix = (self.remote_prefix or "")
    local prefix_len = string.len(prefix)
    if ((prefix_len > 0) and (string.sub(path, 1, prefix_len) == prefix)) then
      return string.sub(path, (prefix_len + 1))
    else
      return path
    end
  end
end
connection["get-current-package"] = function(self)
  if self.ui then
    return self.ui["get-current-package"](self.ui)
  else
    return {"COMMON-LISP-USER", "CL-USER"}
  end
end
connection["set-current-package"] = function(self, package)
  if self.ui then
    return self.ui["set-current-package"](self.ui, package)
  else
    return nil
  end
end
connection["get-current-thread"] = function(self)
  if self.ui then
    return self.ui["get-current-thread"](self.ui)
  else
    return true
  end
end
connection["set-current-thread"] = function(self, thread)
  if self.ui then
    return self.ui["set-current-thread"](self.ui, thread)
  else
    return nil
  end
end
connection["with-thread"] = function(self, thread, func)
  local old_thread = self["get-current-thread"](self)
  self["set-current-thread"](self, thread)
  local result = func()
  self["set-current-thread"](self, old_thread)
  return result
end
connection["with-package"] = function(self, package, func)
  local old_package = self["get-current-package"](self)
  self["set-current-package"](self, {package, package})
  local result = func()
  self["set-current-package"](self, old_package)
  return result
end
connection._call = function(conn_ref, method_name, args)
  require("nvlime.core.connection.channels")
  require("nvlime.core.connection.messages")
  require("nvlime.core.connection.sldb")
  require("nvlime.core.connection.inspector")
  require("nvlime.core.connection.swank")
  require("nvlime.core.connection.events")
  local name = string.gsub(method_name, "([a-z%d])([A-Z])", "%1-%2")
  local name0 = string.gsub(name, "([A-Z]+)([A-Z][a-z])", "%1-%2")
  local kebab_name = string.lower(name0)
  local method = connection[kebab_name]
  if method then
    return method(conn_ref, unpack(args))
  else
    return nil
  end
end
connection["on-server-event"] = function(self, chan, msg)
  local msg_type = msg[1]
  if msg_type then
    local event_name = msg_type.name
    local handler = self.server_event_handlers[event_name]
    if (type(handler) == "function") then
      return handler(self, msg)
    else
      return nil
    end
  else
    return nil
  end
end
return connection
