local connection = require("nvlime.core.connection")
connection["init-inspector"] = function(self, thing, callback)
  local function _1_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#InitInspector", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INIT-INSPECTOR"), thing}), _1_)
end
connection["inspector-reinspect"] = function(self, callback)
  local function _2_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#InspectorReinspect", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INSPECTOR-REINSPECT")}), _2_)
end
connection["inspector-range"] = function(self, r_start, r_end, callback)
  local function _3_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#InspectorRange", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INSPECTOR-RANGE"), r_start, r_end}), _3_)
end
connection["inspect-nth-part"] = function(self, nth, callback)
  local function _4_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#InspectNthPart", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INSPECT-NTH-PART"), nth}), _4_)
end
connection["inspector-call-nth-action"] = function(self, nth, callback)
  local function _5_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#InspectorCallNthAction", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INSPECTOR-CALL-NTH-ACTION"), nth}), _5_)
end
connection["inspector-pop"] = function(self, callback)
  local function _6_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#InspectorPop", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INSPECTOR-POP")}), _6_)
end
connection["inspector-next"] = function(self, callback)
  local function _7_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#InspectorNext", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INSPECTOR-NEXT")}), _7_)
end
connection["inspect-current-condition"] = function(self, callback)
  local function _8_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#InspectCurrentCondition", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INSPECT-CURRENT-CONDITION")}), _8_)
end
connection["inspect-in-frame"] = function(self, thing, frame, callback)
  local function _9_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#InspectInFrame", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INSPECT-IN-FRAME"), thing, frame}), _9_)
end
connection["inspect-frame-var"] = function(self, var_num, frame, callback)
  local function _10_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#InspectFrameVar", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INSPECT-FRAME-VAR"), frame, var_num}), _10_)
end
return connection
