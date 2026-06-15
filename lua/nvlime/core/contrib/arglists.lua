local connection = require("nvlime.core.connection")
connection.autodoc = function(self, raw_form, margin, callback)
  local cmd
  if (margin ~= nil) then
    cmd = {connection.sym("SWANK", "AUTODOC"), raw_form, connection.kw("PRINT-RIGHT-MARGIN"), margin}
  else
    cmd = {connection.sym("SWANK", "AUTODOC"), raw_form}
  end
  local function _2_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#arglists#Autodoc", chan, msg)
  end
  return self:send(self["emacs-rex"](self, cmd), _2_)
end
connection["init-arglists"] = function(self)
  self["Autodoc"] = connection.autodoc
  return self
end
return connection
