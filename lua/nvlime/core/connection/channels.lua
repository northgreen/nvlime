local connection = require("nvlime.core.connection")
connection["make-local-channel"] = function(self, chan_id, callback)
  local c_id = (chan_id or self["next-local-channel-id"])
  if (chan_id == nil) then
    self["next-local-channel-id"] = (self["next-local-channel-id"] + 1)
  else
  end
  if self.local_channels[c_id] then
    error(("nvlime#MakeLocalChannel: channel " .. tostring(c_id) .. " already exists"))
  else
  end
  local chan_obj = {id = c_id, callback = callback}
  self.local_channels[c_id] = chan_obj
  return chan_obj
end
connection["remove-local-channel"] = function(self, chan_id)
  self.local_channels[chan_id] = nil
  return self
end
connection["make-remote-channel"] = function(self, chan_id)
  if self.remote_channels[chan_id] then
    error(("nvlime#MakeRemoteChannel: channel " .. tostring(chan_id) .. " already exists"))
  else
  end
  local chan_obj = {id = chan_id}
  self.remote_channels[chan_id] = chan_obj
  return chan_obj
end
connection["remove-remote-channel"] = function(self, chan_id)
  self.remote_channels[chan_id] = nil
  return self
end
connection["emacs-channel-send"] = function(self, chan_id, msg)
  if self:get(self.remote_channels, chan_id, nil) then
    return {connection.kw("EMACS-CHANNEL-SEND"), chan_id, msg}
  else
    return nil
  end
end
return connection
