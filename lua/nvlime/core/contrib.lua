local connection = require("nvlime.core.connection")
local repl = require("nvlime.core.contrib.repl")
local presentations = require("nvlime.core.contrib.presentations")
local presentation_streams = require("nvlime.core.contrib.presentation_streams")
local fuzzy = require("nvlime.core.contrib.fuzzy")
local arglists = require("nvlime.core.contrib.arglists")
local mrepl
do
  local ok, mod = pcall(require, "nvlime.core.contrib.mrepl")
  if ok then
    mrepl = mod
  else
    mrepl = nil
  end
end
local trace_dialog
do
  local ok, mod = pcall(require, "nvlime.core.contrib.trace_dialog")
  if ok then
    trace_dialog = mod
  else
    trace_dialog = nil
  end
end
local contrib_initializers = {["SWANK-REPL"] = repl["init-repl"], ["SWANK-PRESENTATIONS"] = presentations["init-presentations"], ["SWANK-PRESENTATION-STREAMS"] = presentation_streams["init-presentation-streams"], ["SWANK-FUZZY"] = fuzzy["init-fuzzy"], ["SWANK-ARGLISTS"] = arglists["init-arglists"]}
if mrepl then
  contrib_initializers["SWANK-MREPL"] = mrepl["init-mrepl"]
else
end
if trace_dialog then
  contrib_initializers["SWANK-TRACE-DIALOG"] = trace_dialog["init-trace-dialog"]
else
end
connection["call-initializers"] = function(self, _3fcontribs, _3fcallback)
  do
    local contribs = (_3fcontribs or self.cb_data.contribs or {})
    for _, contrib in ipairs(contribs) do
      local init_fn = contrib_initializers[contrib]
      if init_fn then
        init_fn(self)
      else
      end
    end
  end
  if (type(_3fcallback) == "function") then
    _3fcallback(self)
  else
  end
  return self
end
return connection
