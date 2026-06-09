local connection = require("nvlime.core.connection")
local function transform_compiler_policy(policy)
  if (type(policy) == "table") then
    local plc_list = {}
    for key, val in pairs(policy) do
      plc_list[(#plc_list + 1)] = {head = {connection.cl(key)}, tail = val}
    end
    return {connection.cl("QUOTE"), plc_list}
  else
    return policy
  end
end
local function fix_xref_list_paths(conn, xref_list)
  if (type(xref_list) == "table") then
    for _, spec in pairs(xref_list) do
      if ((type(spec[1]) == "string") and (spec[2][1].name == "LOCATION")) then
        spec[2] = conn["fix-remote-path"](conn, spec[2])
      else
      end
    end
    return nil
  else
    return nil
  end
end
connection["list-threads"] = function(self, callback)
  local function _4_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#ListThreads", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "LIST-THREADS")}), _4_)
end
connection["kill-nth-thread"] = function(self, nth, callback)
  local function _5_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#KillNthThread", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "KILL-NTH-THREAD"), nth}), _5_)
end
connection["debug-nth-thread"] = function(self, nth, callback)
  local function _6_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#DebugNthThread", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "DEBUG-NTH-THREAD"), nth}), _6_)
end
connection["undefine-function"] = function(self, func_name, callback)
  local function _7_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#UndefineFunction", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "UNDEFINE-FUNCTION"), func_name}), _7_)
end
connection["unintern-symbol"] = function(self, sym_name, package, callback)
  local package0
  local or_8_ = package
  if not or_8_ then
    local pkg_info = self["get-current-package"](self)
    if (type(pkg_info) == "table") then
      or_8_ = pkg_info[1]
    else
      or_8_ = nil
    end
  end
  package0 = or_8_
  local function _11_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#UninternSymbol", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "UNINTERN-SYMBOL"), sym_name, package0}), _11_)
end
connection["set-package"] = function(self, package, callback)
  local bufnr = vim.api.nvim_get_current_buf()
  local function _12_(chan, msg)
    self["check-return-status"](self, msg, "nvlime#SetPackage")
    local function _13_()
      return self["set-current-package"](self, {msg[2][2], msg[2][2]})
    end
    vim.api.nvim_buf_call(bufnr, _13_)
    if (type(callback) == "function") then
      return callback(self, msg[2][2])
    else
      return nil
    end
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SET-PACKAGE"), package}), _12_)
end
connection["describe-symbol"] = function(self, symbol, callback)
  local function _15_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#DescribeSymbol", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "DESCRIBE-SYMBOL"), symbol}), _15_)
end
connection["operator-arg-list"] = function(self, operator, callback)
  local cur_package
  do
    local pkg_info = self["get-current-package"](self)
    if (type(pkg_info) == "table") then
      cur_package = pkg_info[1]
    else
      cur_package = nil
    end
  end
  local function _17_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#OperatorArgList", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "OPERATOR-ARGLIST"), operator, cur_package}), _17_)
end
connection["simple-completions"] = function(self, symbol, callback)
  local cur_package
  do
    local pkg_info = self["get-current-package"](self)
    if (type(pkg_info) == "table") then
      cur_package = pkg_info[1]
    else
      cur_package = nil
    end
  end
  local function _19_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#SimpleCompletions", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SIMPLE-COMPLETIONS"), symbol, cur_package}), _19_)
end
connection["return-string"] = function(self, thread, ttag, str)
  return self:send({connection.kw("EMACS-RETURN-STRING"), thread, ttag, str}, nil)
end
connection["return"] = function(self, thread, ttag, val)
  return self:send({connection.kw("EMACS-RETURN"), thread, ttag, val}, nil)
end
connection["swank-macro-expand-one"] = function(self, expr, callback)
  local function _20_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#SwankMacroExpandOne", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SWANK-MACROEXPAND-1"), expr}), _20_)
end
connection["swank-macro-expand"] = function(self, expr, callback)
  local function _21_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#SwankMacroExpand", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SWANK-MACROEXPAND"), expr}), _21_)
end
connection["swank-macro-expand-all"] = function(self, expr, callback)
  local function _22_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#SwankMacroExpandAll", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "SWANK-MACROEXPAND-ALL"), expr}), _22_)
end
connection["disassemble-form"] = function(self, expr, callback)
  local function _23_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#DisassembleForm", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "DISASSEMBLE-FORM"), expr}), _23_)
end
connection["compile-string-for-emacs"] = function(self, expr, buffer, position, filename, policy, callback)
  local policy0 = transform_compiler_policy(policy)
  local fixed_filename = self["fix-local-path"](self, filename)
  local function _24_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#CompileStringForEmacs", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "COMPILE-STRING-FOR-EMACS"), expr, buffer, {connection.cl("QUOTE"), {{connection.kw("POSITION"), position}}}, fixed_filename, policy0}), _24_)
end
connection["compile-file-for-emacs"] = function(self, filename, load, policy, callback)
  local policy0 = transform_compiler_policy(policy)
  local fixed_filename = self["fix-local-path"](self, filename)
  local cmd = {connection.sym("SWANK", "COMPILE-FILE-FOR-EMACS"), fixed_filename, load}
  if policy0 then
    table.insert(cmd, connection.kw("POLICY"))
    table.insert(cmd, policy0)
  else
  end
  local function _26_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#CompileFileForEmacs", chan, msg)
  end
  return self:send(self["emacs-rex"](self, cmd), _26_)
end
connection["load-file"] = function(self, filename, callback)
  local fixed_filename = self["fix-local-path"](self, filename)
  local function _27_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#LoadFile", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "LOAD-FILE"), fixed_filename}), _27_)
end
connection.xref = function(self, ref_type, name, callback)
  local function _28_(chan, msg)
    self["check-return-status"](self, msg, "nvlime#XRef")
    local result = msg[2][2]
    fix_xref_list_paths(self, result)
    if (type(callback) == "function") then
      return callback(self, result)
    else
      return nil
    end
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "XREF"), connection.kw(ref_type), name}), _28_)
end
connection["find-definitions-for-emacs"] = function(self, name, callback)
  local function _30_(chan, msg)
    self["check-return-status"](self, msg, "nvlime#FindDefinitionsForEmacs")
    local result = msg[2][2]
    fix_xref_list_paths(self, result)
    if (type(callback) == "function") then
      return callback(self, result)
    else
      return nil
    end
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "FIND-DEFINITIONS-FOR-EMACS"), name}), _30_)
end
connection["find-source-location-for-emacs"] = function(self, spec, callback)
  local spec_type = spec[1]
  local kw_list = {connection.kw(spec_type)}
  for _, item in pairs(vim.list_slice(spec, 2)) do
    table.insert(kw_list, item)
  end
  local spec_expr = {connection.cl("QUOTE"), kw_list}
  local function _32_(chan, msg)
    self["check-return-status"](self, msg, "nvlime#FindSourceLocationForEmacs")
    local result = msg[2][2]
    if (type(callback) == "function") then
      if (result and (result[1].name == "LOCATION")) then
        return callback(self, self["fix-remote-path"](self, result))
      else
        return callback(self, result)
      end
    else
      return nil
    end
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "FIND-SOURCE-LOCATION-FOR-EMACS"), spec_expr}), _32_)
end
connection["apropos-list-for-emacs"] = function(self, name, external_only, case_sensitive, package, callback)
  local function _35_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#AproposListForEmacs", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "APROPOS-LIST-FOR-EMACS"), name, external_only, case_sensitive, package}), _35_)
end
connection["documentation-symbol"] = function(self, sym_name, callback)
  local function _36_(chan, msg)
    return self["simple-send-cb"](self, callback, "nvlime#DocumentationSymbol", chan, msg)
  end
  return self:send(self["emacs-rex"](self, {connection.sym("SWANK", "DOCUMENTATION-SYMBOL"), sym_name}), _36_)
end
return connection
