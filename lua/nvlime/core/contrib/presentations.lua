local connection = require("nvlime.core.connection")
connection["inspect-presentation"] = function(self, pres_id, reset, callback)
  local function _1_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#presentations#InspectPresentation", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INSPECT-PRESENTATION"), pres_id, reset}), _1_)
end
connection["init-presentations"] = function(self)
  self["InspectPresentation"] = connection["inspect-presentation"]
  local function _2_(conn, msg)
    return vim.fn.luaeval("require(\"nvlime.contrib.presentations\").on_start(_A[1], _A[2])", {conn, msg})
  end
  self.server_event_handlers["PRESENTATION-START"] = _2_
  local function _3_(conn, msg)
    return vim.fn.luaeval("require(\"nvlime.contrib.presentations\").on_end(_A[1], _A[2])", {conn, msg})
  end
  self.server_event_handlers["PRESENTATION-END"] = _3_
  local function _4_(chan, msg)
    return self["simple-send-cb"](self, nil, "nvlime#contrib#presentations#Init", chan, msg)
  end
  self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INIT-PRESENTATIONS")}), _4_)
  return self
end
return connection
