local connection = require("nvlime.core.connection")
connection["sldb-abort"] = function(self, callback)
  local function _1_(chan, msg)
    return self["sldb-send-cb"](self, callback, "nvlime#SLDBAbort", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SLDB-ABORT")}), _1_)
end
connection["sldb-break"] = function(self, func_name, callback)
  local function _2_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#SLDBBreak", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SLDB-BREAK"), func_name}), _2_)
end
connection["sldb-continue"] = function(self, callback)
  local function _3_(chan, msg)
    return self["sldb-send-cb"](self, callback, "nvlime#SLDBContinue", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SLDB-CONTINUE")}), _3_)
end
connection["sldb-step"] = function(self, frame, callback)
  local function _4_(chan, msg)
    return self["sldb-send-cb"](self, callback, "nvlime#SLDBStep", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SLDB-STEP"), frame}), _4_)
end
connection["sldb-next"] = function(self, frame, callback)
  local function _5_(chan, msg)
    return self["sldb-send-cb"](self, callback, "nvlime#SLDBNext", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SLDB-NEXT"), frame}), _5_)
end
connection["sldb-out"] = function(self, frame, callback)
  local function _6_(chan, msg)
    return self["sldb-send-cb"](self, callback, "nvlime#SLDBOut", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SLDB-OUT"), frame}), _6_)
end
connection["sldb-return-from-frame"] = function(self, frame, str, callback)
  local function _7_(chan, msg)
    return self["sldb-send-cb"](self, callback, "nvlime#SLDBReturnFromFrame", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SLDB-RETURN-FROM-FRAME"), frame, str}), _7_)
end
connection["sldb-disassemble"] = function(self, frame, callback)
  local function _8_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#SLDBDisassemble", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SLDB-DISASSEMBLE"), frame}), _8_)
end
connection["invoke-nth-restart-for-emacs"] = function(self, level, restart, callback)
  local function _9_(chan, msg)
    return self["sldb-send-cb"](self, callback, "nvlime#InvokeNthRestartForEmacs", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "INVOKE-NTH-RESTART-FOR-EMACS"), level, restart}), _9_)
end
connection["restart-frame"] = function(self, frame, callback)
  local function _10_(chan, msg)
    return self["sldb-send-cb"](self, callback, "nvlime#RestartFrame", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "RESTART-FRAME"), frame}), _10_)
end
connection["frame-locals-and-catch-tags"] = function(self, frame, callback)
  local function _11_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#FrameLocalsAndCatchTags", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "FRAME-LOCALS-AND-CATCH-TAGS"), frame}), _11_)
end
connection["frame-source-location"] = function(self, frame, callback)
  local function _12_(chan, msg)
    do
      local status = msg[2][1]
      if (status.name ~= "OK") then
        error(("nvlime#FrameSourceLocation returned: " .. vim.inspect(msg[2])))
      else
      end
    end
    local loc_data = msg[2][2]
    if (type(callback) == "function") then
      if (loc_data and (loc_data[1].name == "LOCATION")) then
        return callback(self, self["fix-remote-path"](self, loc_data))
      else
        return callback(self, loc_data)
      end
    else
      return nil
    end
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "FRAME-SOURCE-LOCATION"), frame}), _12_)
end
connection["eval-string-in-frame"] = function(self, str, frame, package, callback)
  local function _16_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#EvalStringInFrame", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "EVAL-STRING-IN-FRAME"), str, frame, package}), _16_)
end
return connection
