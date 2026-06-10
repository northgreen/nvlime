local connection = require("nvlime.core.connection")
connection["init-presentation-streams"] = function(self)
  local function _1_(chan, msg)
    return self["simple-send-cb"](self, nil, "nvlime#contrib#presentation_streams#Init", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INIT-PRESENTATION-STREAMS")}), _1_)
end
return connection
