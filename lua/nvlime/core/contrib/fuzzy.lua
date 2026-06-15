local connection = require("nvlime.core.connection")
connection["fuzzy-completions"] = function(self, symbol, callback)
  local cur_package
  do
    local pkg_info = connection["get-current-package"](self)
    if pkg_info then
      cur_package = pkg_info[1]
    else
      cur_package = nil
    end
  end
  local function _2_(chan, msg)
    return connection["simple-send-cb"](self, callback, "nvlime#contrib#fuzzy#FuzzyCompletions", chan, msg)
  end
  return connection.send(self, connection["emacs-rex"](self, {connection.sym("SWANK", "FUZZY-COMPLETIONS"), symbol, cur_package}), _2_)
end
connection["init-fuzzy"] = function(self)
  self["FuzzyCompletions"] = connection["fuzzy-completions"]
  return self
end
return connection
