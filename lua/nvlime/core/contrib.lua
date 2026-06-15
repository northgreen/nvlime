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
    local init_repl = contrib_initializers["SWANK-REPL"]
    local init_ps = contrib_initializers["SWANK-PRESENTATION-STREAMS"]
    if (init_repl and init_ps) then
      local function _5_(_)
        local function _6_(_0)
          for _1, c in ipairs(contribs) do
            if (not (c == "SWANK-REPL") and not (c == "SWANK-PRESENTATION-STREAMS")) then
              local init_fn = contrib_initializers[c]
              if init_fn then
                init_fn(self)
              else
              end
            else
            end
          end
          if (type(_3fcallback) == "function") then
            return _3fcallback(self)
          else
            return nil
          end
        end
        return init_ps(self, _6_)
      end
      init_repl(self, _5_)
    else
      for _, c in ipairs(contribs) do
        local init_fn = contrib_initializers[c]
        if init_fn then
          init_fn(self)
        else
        end
      end
      if (type(_3fcallback) == "function") then
        _3fcallback(self)
      else
      end
    end
  end
  return self
end
return connection
