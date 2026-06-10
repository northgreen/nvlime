local connection = require("nvlime.core.connection")
local function translate_function_spec(spec)
  if (type(spec) == "string") then
    return {connection.sym("SWANK", "FROM-STRING"), spec}
  else
    return spec
  end
end
local function get_current_package(conn)
  local pkg = conn:GetCurrentPackage()
  if (pkg == nil) then
    return "COMMON-LISP-USER"
  else
    return pkg[1]
  end
end
connection["clear-trace-tree"] = function(self, _3fcallback)
  local function _3_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#trace_dialog#ClearTraceTree", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-TRACE-DIALOG", "CLEAR-TRACE-TREE")}), _3_)
end
connection["dialog-toggle-trace"] = function(self, name, _3fcallback)
  local function _4_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#trace_dialog#DialogToggleTrace", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-TRACE-DIALOG", "DIALOG-TOGGLE-TRACE"), translate_function_spec(name)}), _4_)
end
connection["dialog-trace"] = function(self, name, _3fcallback)
  local function _5_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#trace_dialog#DialogTrace", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-TRACE-DIALOG", "DIALOG-TRACE"), translate_function_spec(name)}), _5_)
end
connection["dialog-untrace"] = function(self, name, _3fcallback)
  local function _6_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#trace_dialog#DialogUntrace", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-TRACE-DIALOG", "DIALOG-UNTRACE"), translate_function_spec(name)}), _6_)
end
connection["dialog-untrace-all"] = function(self, _3fcallback)
  local function _7_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#trace_dialog#DialogUntraceAll", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-TRACE-DIALOG", "DIALOG-UNTRACE-ALL")}), _7_)
end
connection["find-trace"] = function(self, id, _3fcallback)
  local function _8_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#trace_dialog#FindTrace", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-TRACE-DIALOG", "FIND-TRACE"), id}), _8_)
end
connection["find-trace-part"] = function(self, id, part_id, type, _3fcallback)
  local function _9_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#trace_dialog#FindTracePart", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-TRACE-DIALOG", "FIND-TRACE-PART"), id, part_id, connection.kw(type)}), _9_)
end
connection["inspect-trace-part"] = function(self, id, part_id, type, _3fcallback)
  local function _10_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#trace_dialog#InspectTracePart", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-TRACE-DIALOG", "INSPECT-TRACE-PART"), id, part_id, connection.kw(type)}), _10_)
end
connection["report-partial-tree"] = function(self, key, _3fcallback)
  local function _11_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#trace_dialog#ReportPartialTree", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-TRACE-DIALOG", "REPORT-PARTIAL-TREE"), key}), _11_)
end
connection["report-specs"] = function(self, _3fcallback)
  local function _12_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#trace_dialog#ReportSpecs", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-TRACE-DIALOG", "REPORT-SPECS")}), _12_)
end
connection["report-total"] = function(self, callback)
  local function _13_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#trace_dialog#ReportTotal", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-TRACE-DIALOG", "REPORT-TOTAL")}), _13_)
end
connection["report-trace-detail"] = function(self, id, callback)
  local function _14_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#contrib#trace_dialog#ReportTraceDetail", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-TRACE-DIALOG", "REPORT-TRACE-DETAIL"), id}), _14_)
end
connection["init-trace-dialog"] = function(self)
  self["ClearTraceTree"] = connection["clear-trace-tree"]
  self["DialogToggleTrace"] = connection["dialog-toggle-trace"]
  self["DialogTrace"] = connection["dialog-trace"]
  self["DialogUntrace"] = connection["dialog-untrace"]
  self["DialogUntraceAll"] = connection["dialog-untrace-all"]
  self["FindTrace"] = connection["find-trace"]
  self["FindTracePart"] = connection["find-trace-part"]
  self["InspectTracePart"] = connection["inspect-trace-part"]
  self["ReportPartialTree"] = connection["report-partial-tree"]
  self["ReportSpecs"] = connection["report-specs"]
  self["ReportTotal"] = connection["report-total"]
  self["ReportTraceDetail"] = connection["report-trace-detail"]
  return self
end
return connection
