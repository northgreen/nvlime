local connection = require("nvlime.core.connection")
local function check_and_report_return_status(conn, return_msg, caller)
  local status = return_msg[2][1]
  if (status.name == "OK") then
    return true
  else
    if (status.name == "ABORT") then
      conn:ui().OnWriteString(conn, (return_msg[2][2] .. "\n"), {name = "ABORT-REASON", package = "KEYWORD"})
      return nil
    else
      conn:ui().OnWriteString(conn, vim.inspect(return_msg[2]), {name = "UNKNOWN-ERROR", package = "KEYWORD"})
      return nil
    end
  end
end
connection["create-repl"] = function(self, coding_system, callback)
  local cmd = {connection.sym("SWANK-REPL", "CREATE-REPL"), nil}
  if (coding_system ~= nil) then
    table.insert(cmd, connection.kw("CODING-SYSTEM"))
    table.insert(cmd, coding_system)
  else
  end
  local function _4_(chan, msg)
    self["check-return-status"](self, msg, "nvlime#contrib#repl#CreateREPL")
    return self["try-to-call"](self, callback, {self, msg[2][2]})
  end
  return self:send(self["emacs-rex"](self, cmd), _4_)
end
connection["listener-eval"] = function(self, expr, callback)
  local function _5_(chan, msg)
    if check_and_report_return_status(self, msg, "nvlime#contrib#repl#ListenerEval") then
      return self["try-to-call"](self, callback, {self, msg[2][2]})
    else
      return nil
    end
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-REPL", "LISTENER-EVAL"), expr}), _5_)
end
connection["init-repl"] = function(self)
  self["CreateREPL"] = connection["create-repl"]
  self["ListenerEval"] = connection["listener-eval"]
  self["create-repl"](self)
  return self
end
return connection
