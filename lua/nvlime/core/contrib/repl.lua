local connection = require("nvlime.core.connection")
local logger = require("nvlime.logger")
local function check_and_report_return_status(conn, return_msg, caller)
  local status = return_msg[2][1]
  logger.debug(("check-and-report-return-status: status=" .. tostring(vim.inspect(status)) .. " caller=" .. caller))
  if (status.name == "OK") then
    logger.debug("check-and-report-return-status: OK")
    return true
  else
    if (status.name == "ABORT") then
      logger.warn(("check-and-report-return-status: ABORT - " .. return_msg[2][2]))
      conn:ui().OnWriteString(conn, (return_msg[2][2] .. "\n"), {name = "ABORT-REASON", package = "KEYWORD"})
      return nil
    else
      logger.warn(("check-and-report-return-status: UNKNOWN-ERROR - " .. vim.inspect(return_msg[2])))
      conn:ui().OnWriteString(conn, vim.inspect(return_msg[2]), {name = "UNKNOWN-ERROR", package = "KEYWORD"})
      return nil
    end
  end
end
connection["create-repl"] = function(self, coding_system, callback)
  local cmd = {connection.sym("SWANK-REPL", "CREATE-REPL"), vim.NIL}
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
  logger.debug(("listener-eval: expr=" .. expr))
  local function _5_(chan, msg)
    logger.debug(("listener-eval callback: msg=" .. vim.inspect(msg)))
    logger.debug(("listener-eval callback: msg-len=" .. tostring(#msg)))
    if check_and_report_return_status(self, msg, "nvlime#contrib#repl#ListenerEval") then
      logger.debug("listener-eval callback: calling user callback")
      return self["try-to-call"](self, callback, {self, msg[2][2]})
    else
      return nil
    end
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK-REPL", "LISTENER-EVAL"), expr, connection.kw("WINDOW-WIDTH"), 80}), _5_)
end
connection["init-repl"] = function(self, callback)
  self["CreateREPL"] = connection["create-repl"]
  self["ListenerEval"] = connection["listener-eval"]
  local function _7_(_, _0)
    if callback then
      return callback(self)
    else
      return nil
    end
  end
  return self["create-repl"](self, nil, _7_)
end
return connection
