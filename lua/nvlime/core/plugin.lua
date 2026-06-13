local config = require("nvlime.config")
local conn_manager = require("nvlime.core.conn_manager")
local ui = require("nvlime.core.ui")
local input = require("nvlime.core.ui.input")
local async = require("nvlime.core.async")
local connection = require("nvlime.core.connection")
require("nvlime.core.connection.channels")
require("nvlime.core.connection.messages")
require("nvlime.core.connection.sldb")
require("nvlime.core.connection.inspector")
require("nvlime.core.connection.swank")
require("nvlime.core.connection.events")
local contrib = require("nvlime.core.contrib")
local server = require("nvlime.core.server")
local uc = require("nvlime.ui_cursors")
local logger = require("nvlime.logger")
local plugin = {}
local function input_check_edit_flag(edit, text)
  if edit then
    return {nil, text}
  else
    return {text, nil}
  end
end
local function conn_has_contrib(conn, contrib_name)
  local contribs = conn.cb_data.contribs
  return (contribs and (vim.fn.index(contribs, contrib_name) >= 0))
end
local function normalize_identifier_for_indent(ident)
  local ident_len = string.len(ident)
  if ((ident_len >= 2) and (ident[1] == "|") and (ident[ident_len] == "|")) then
    return string.sub(ident, 2, (ident_len - 1))
  else
    return ident
  end
end
local function complete_find_start()
  local col = (vim.fn.col(".") - 1)
  local line = vim.fn.getline(".")
  while ((col > 0) and (vim.fn.match(line[col], "\\_s\\|[()#;'\"]") < 0)) do
    col = (col - 1)
  end
  return col
end
local function reset_arglist_state()
  __fnl_global__autodoc_2dcache = {}
  __fnl_global__last_2darglist_2dop = ""
  return nil
end
local function show_async_result(conn, result)
  return vim.fn.luaeval("require(\"nvlime.window.macroexpand\").open(_A)", result)
end
local function show_symbol_description(conn, content)
  return vim.fn.luaeval("require(\"nvlime.window.description\").open(_A)", content)
end
local function show_symbol_documentation(conn, content)
  return vim.fn.luaeval("require(\"nvlime.window.documentation\").open(_A)", content)
end
local function on_xref_complete(conn, result)
  if conn.ui then
    return conn.ui["on-xref"](conn.ui, conn, result)
  else
    return nil
  end
end
local function on_apropos_list_complete(conn, result)
  if not result then
    return ui["err-msg"]("No result found.")
  else
    return vim.fn.luaeval("require(\"nvlime.window.apropos\").open(_A)", result)
  end
end
local function on_sldb_break_complete(conn, result)
  return vim.cmd("echom 'Breakpoint set.'")
end
local function on_undefine_function_complete(conn, result)
  return vim.cmd(("echom 'Undefined function " .. result .. "'"))
end
local function on_unintern_symbol_complete(conn, result)
  return vim.cmd(("echom '" .. result .. "'"))
end
local function on_load_file_complete(fname, conn, result)
  vim.cmd(("echom 'Loaded: " .. fname .. "'"))
  return reset_arglist_state()
end
local function on_listener_eval_complete(conn, result)
  logger.debug(("on-listener-eval-complete: result-type=" .. tostring(type(result)) .. " result-len=" .. tostring(#result)))
  if ((type(result) == "table") and (#result > 0) and (type(result[1]) == "table") and (result[1].name == "VALUES") and conn.ui) then
    logger.debug("on-listener-eval-complete: result format VALID (VALUES)")
    local result_values = vim.list_slice(result, 2)
    if (#result_values > 0) then
      logger.debug(("on-listener-eval-complete: writing " .. tostring(#result_values) .. " values"))
      for _, val in ipairs(result_values) do
        conn.ui["on-write-string"](conn.ui, conn, (val .. "\n"), {name = "REPL-RESULT", package = "KEYWORD"})
      end
    else
      conn.ui["on-write-string"](conn.ui, conn, "; No value\n", {name = "REPL-RESULT", package = "KEYWORD"})
    end
  else
    logger.warn(("on-listener-eval-complete: result format INVALID, expected VALUES, got " .. tostring(result[1].name)))
  end
  return reset_arglist_state()
end
local function on_compilation_complete(orig_win, conn, result)
  local msg_type = result[1]
  local notes = result[2]
  local successp = result[3]
  local duration = result[4]
  local loadp = result[5]
  local faslfile = result[6]
  if successp then
    vim.cmd(("echom 'Compilation finished in " .. tostring(duration) .. " second(s)'"))
    if (loadp and faslfile) then
      local function _7_(c, r)
        return on_load_file_complete(faslfile, c, r)
      end
      conn["load-file"](conn, faslfile, _7_)
    else
    end
  else
    ui["err-msg"]("Compilation failed.")
  end
  if conn.ui then
    return conn.ui["on-compiler-notes"](conn.ui, conn, notes, orig_win)
  else
    return nil
  end
end
local autodoc_cache = {}
local last_arglist_op = ""
local key_timer = 0
local function on_connection_info_complete(conn, result)
  conn.cb_data.version = connection.get(conn, result, "VERSION", "<unknown version>")
  conn.cb_data.pid = connection.get(conn, result, "PID", "<unknown pid>")
  local features = connection.get(conn, result, "FEATURES", {})
  conn.cb_data.features = (features or {})
  return nil
end
local function on_swank_require_complete(do_init, conn, result)
  local new_contribs = (result or {})
  local old_contribs = (conn.cb_data.contribs or {})
  conn.cb_data.contribs = new_contribs
  if do_init then
    local added = {}
    for _, co in ipairs(new_contribs) do
      if (vim.fn.index(old_contribs, co) < 0) then
        table.insert(added, co)
      else
      end
    end
    local function _12_(c)
      return vim.cmd(("echom 'Loaded contrib modules: " .. vim.inspect(added)))
    end
    return connection["call-initializers"](conn, added, _12_)
  else
    return nil
  end
end
local function on_call_initializers_complete(conn)
  return vim.cmd(("echom '" .. conn.cb_data.name .. " connection established.'"))
end
local function maybe_send_secret(conn)
  local secret_file = (vim.g.nvlime_secret_file or vim.fn.expand("~/.slime-secret"))
  if (vim.fn.filereadable(secret_file) == 1) then
    local content = vim.fn.readfile(secret_file, "", 1)
    if (#content > 0) then
      return conn:send({connection.kw("NVLIME-RAW-MSG"), content[1]}, nil)
    else
      return nil
    end
  else
    return nil
  end
end
local function clean_up_null_buf_connections()
  local old_buf = vim.fn.bufnr("%")
  local function _16_()
    return vim.cmd("bufdo! if exists('b:nvlime_conn') && b:nvlime_conn is# v:null | unlet b:nvlime_conn | endif")
  end
  pcall(_16_)
  return pcall(vim.cmd, ("hide buffer " .. old_buf))
end
plugin["connect-repl"] = function(host, port, remote_prefix, timeout, name)
  local def_timeout
  if (config.connect_timeout ~= -1) then
    def_timeout = config.connect_timeout
  else
    def_timeout = nil
  end
  local host0
  local or_18_ = host
  if not or_18_ then
    local h = vim.fn.input("Host: ", config.address.host)
    if (string.len(h) <= 0) then
      ui["err-msg"]("Canceled.")
      or_18_ = nil
    else
      or_18_ = h
    end
  end
  host0 = or_18_
  local port0
  local or_21_ = port
  if not or_21_ then
    local p = vim.fn.input("Port: ", tostring(config.address.port))
    if (string.len(p) <= 0) then
      ui["err-msg"]("Canceled.")
      or_21_ = nil
    else
      or_21_ = tonumber(p)
    end
  end
  port0 = or_21_
  local conn
  if name then
    conn = conn_manager.new(name)
  else
    conn = conn_manager.new()
  end
  local remote_prefix0 = (remote_prefix or "")
  local timeout0 = (timeout or def_timeout)
  local function _25_()
    return conn:connect(host0, port0, remote_prefix0, timeout0)
  end
  pcall(_25_)
  if not conn["is-connected"](conn) then
    conn_manager.close(conn)
    ui["err-msg"]("nvlime#Connect: failed to connect")
  else
  end
  clean_up_null_buf_connections()
  conn.cb_data.remote_host = host0
  conn.cb_data.remote_port = port0
  maybe_send_secret(conn)
  local function _27_(cont)
    local function _28_(c, r)
      on_connection_info_complete(c, r)
      return cont()
    end
    return conn["connection-info"](conn, true, _28_)
  end
  local function _29_(cont)
    on_connection_info_complete(conn, nil)
    return cont()
  end
  local function _30_(cont)
    local function _31_(c, r)
      on_swank_require_complete(false, c, r)
      return cont()
    end
    return conn["swank-require"](conn, config.contribs, _31_)
  end
  local function _32_(cont)
    local function _33_(c)
      on_call_initializers_complete(c)
      return cont()
    end
    return connection["call-initializers"](conn, nil, _33_)
  end
  local function _34_()
    return nil
  end
  conn["chain-callbacks"](conn, _27_, _29_, _30_, _32_, _34_)
  return conn
end
plugin["close-cur-connection"] = function()
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local server0 = conn.cb_data.server
  if not server0 then
    conn_manager.close(conn)
    return vim.cmd(("echom '" .. conn.cb_data.name .. " disconnected.'"))
  else
    local answer = vim.fn.input(("Also stop server " .. vim.inspect(server0.name) .. "? (y/n) "))
    if ui["is-yes-string"](answer) then
      server0.stop(server0)
    else
    end
    if (not ui["is-yes-string"](answer) and string.find(answer, "^[nN]")) then
      conn_manager.close(conn)
      return vim.cmd(("echom '" .. conn.cb_data.name .. " disconnected.'"))
    else
      return nil
    end
  end
end
plugin["rename-cur-connection"] = function()
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local new_name = vim.fn.input("New name: ", conn.cb_data.name)
  if (string.len(new_name) > 0) then
    return conn_manager.rename(conn, new_name)
  else
    return ui["err-msg"]("Canceled.")
  end
end
plugin["select-cur-connection"] = function()
  local conn = conn_manager.select(false)
  if conn then
    vim.b.nvlime_conn = conn
    return nil
  else
    return nil
  end
end
plugin["send-to-repl"] = function(content, edit)
  logger.debug(("send-to-repl: content=" .. tostring(content) .. " edit=" .. tostring(edit)))
  local conn = conn_manager.get(true)
  local function _42_()
    if conn then
      return conn.cb_data.name
    else
      return "nil"
    end
  end
  logger.debug(("send-to-repl: conn=" .. tostring(_42_())))
  if not conn then
    logger.warn("send-to-repl: no connection available")
    ui["err-msg"]("Not connected. Use :NvlimeConnect first.")
  else
  end
  if conn then
    local _let_44_ = input_check_edit_flag((edit or false), content)
    local text = _let_44_[1]
    local default = _let_44_[2]
    logger.debug(("send-to-repl: text=" .. tostring(text) .. " default=" .. tostring(default)))
    local function _45_(str)
      logger.debug(("send-to-repl callback: str=" .. str))
      local function _46_()
        if conn then
          return conn.cb_data.name
        else
          return "nil"
        end
      end
      local function _47_()
        if conn then
          return conn.ui
        else
          return "nil"
        end
      end
      logger.debug(("send-to-repl callback: conn=" .. tostring(_46_()) .. " conn.ui=" .. tostring(_47_())))
      if not conn then
        logger.warn("send-to-repl callback: conn IS NIL!")
      else
      end
      if (conn and not conn.ui) then
        logger.warn("send-to-repl callback: conn.ui IS NIL!")
      else
      end
      if (conn and conn.ui) then
        logger.debug("send-to-repl callback: entering when block")
        conn.ui["on-write-string"](conn.ui, conn, "--\n", {name = "REPL-SEP", package = "KEYWORD"})
        logger.debug("send-to-repl callback: on-write-string returned")
        local function _50_()
          logger.debug("send-to-repl callback: inside with-thread")
          return conn["listener-eval"](conn, str, on_listener_eval_complete)
        end
        return conn["with-thread"](conn, true, _50_)
      else
        return nil
      end
    end
    return input["maybe-input"](text, _45_, " Send to REPL ", default, conn)
  else
    return nil
  end
end
plugin.compile = function(content, policy, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_54_ = input_check_edit_flag((edit or false), content)
  local text = _let_54_[1]
  local default = _let_54_[2]
  local function _55_(str)
    if conn.ui then
      conn.ui["on-write-string"](conn.ui, conn, "--\n", {name = "REPL-SEP", package = "KEYWORD"})
      local win = vim.fn.win_getid()
      local policy0 = (policy or config.compiler_policy)
      local function _56_(c, r)
        return on_compilation_complete(win, c, r)
      end
      return conn["compile-string-for-emacs"](conn, str, nil, 1, nil, policy0, _56_)
    else
      return nil
    end
  end
  return input["maybe-input"](text, _55_, " Compile ", default, conn)
end
plugin["compile-defun"] = function()
  return ui["err-msg"]("compile-defun: blocked on ui_cursor.fnl (cursor-based form extraction not yet implemented)")
end
plugin["load-file"] = function(file_name, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_59_ = input_check_edit_flag((edit or false), file_name)
  local text = _let_59_[1]
  local default = _let_59_[2]
  local function _60_(fname)
    local function _61_(c, r)
      return on_load_file_complete(fname, c, r)
    end
    return conn["load-file"](conn, fname, _61_)
  end
  return input["maybe-input"](text, _60_, " Load file ", (default or ""), nil, "file")
end
plugin["set-package"] = function(pkg)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local cur_pkg = conn["get-current-package"](conn)
  local default
  if (type(cur_pkg) == "table") then
    default = cur_pkg[1]
  else
    default = "COMMON-LISP-USER"
  end
  local function _64_(p)
    return conn["set-package"](conn, p)
  end
  return input["maybe-input"](pkg, _64_, " Set package ", default, conn)
end
plugin.inspect = function(content, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_66_ = input_check_edit_flag((edit or false), content)
  local text = _let_66_[1]
  local default = _let_66_[2]
  local function _67_(str)
    local function _68_(c, r)
      return c.ui["on-inspect"](c.ui, c, r, nil, nil)
    end
    return conn["init-inspector"](conn, str, _68_)
  end
  return input["maybe-input"](text, _67_, " Inspect ", default, conn)
end
plugin["compile-file"] = function(file_name, policy, load, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_70_ = input_check_edit_flag((edit or false), file_name)
  local text = _let_70_[1]
  local default = _let_70_[2]
  local function _71_(fname)
    if conn.ui then
      conn.ui["on-write-string"](conn.ui, conn, "--\n", {name = "REPL-SEP", package = "KEYWORD"})
      local win = vim.fn.win_getid()
      local policy0 = (policy or config.compiler_policy)
      local load0 = (load or true)
      local function _72_(c, r)
        return on_compilation_complete(win, c, r)
      end
      return conn["compile-file-for-emacs"](conn, fname, load0, policy0, _72_)
    else
      return nil
    end
  end
  return input["maybe-input"](text, _71_, " Compile file ", (default or ""), nil, "file")
end
plugin["expand-macro"] = function(expr, type, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_75_ = input_check_edit_flag((edit or false), expr)
  local text = _let_75_[1]
  local default = _let_75_[2]
  local cb_fn
  do
    local case_76_ = (type or "expand")
    if (case_76_ == "all") then
      local function _77_(e)
        return conn["swank-macro-expand-all"](conn, e, show_async_result)
      end
      cb_fn = _77_
    elseif (case_76_ == "one") then
      local function _78_(e)
        return conn["swank-macro-expand-one"](conn, e, show_async_result)
      end
      cb_fn = _78_
    else
      local _ = case_76_
      local function _79_(e)
        return conn["swank-macro-expand"](conn, e, show_async_result)
      end
      cb_fn = _79_
    end
  end
  return input["maybe-input"](text, cb_fn, "Expand macro: ", default, conn)
end
plugin["disassemble-form"] = function(content, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_82_ = input_check_edit_flag((edit or false), content)
  local text = _let_82_[1]
  local default = _let_82_[2]
  local function _83_(expr)
    return conn["disassemble-form"](conn, expr, ui["show-disassemble-form"])
  end
  return input["maybe-input"](text, _83_, " Disassemble ", default, conn)
end
plugin["describe-symbol"] = function(symbol, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_85_ = input_check_edit_flag((edit or false), symbol)
  local text = _let_85_[1]
  local default = _let_85_[2]
  local function _86_(sym)
    return conn["describe-symbol"](conn, sym, show_symbol_description)
  end
  return input["maybe-input"](text, _86_, " Describe symbol ", default, conn)
end
plugin["documentation-symbol"] = function(symbol, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_88_ = input_check_edit_flag((edit or false), symbol)
  local text = _let_88_[1]
  local default = _let_88_[2]
  local function _89_(sym)
    return conn["documentation-symbol"](conn, sym, show_symbol_documentation)
  end
  return input["maybe-input"](text, _89_, " Documentation for symbol ", default, conn)
end
plugin["apropos-list"] = function(pattern, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_91_ = input_check_edit_flag((edit or false), pattern)
  local text = _let_91_[1]
  local default = _let_91_[2]
  local function _92_(pat)
    return conn["apropos-list-for-emacs"](conn, pat, false, false, nil, on_apropos_list_complete)
  end
  return input["maybe-input"](text, _92_, " Apropos search ", default, conn)
end
plugin["find-definition"] = function(sym, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_94_ = input_check_edit_flag((edit or false), sym)
  local text = _let_94_[1]
  local default = _let_94_[2]
  local function _95_(s)
    return conn["find-definitions-for-emacs"](conn, s, on_xref_complete)
  end
  return input["maybe-input"](text, _95_, " Definition of symbol ", default, conn)
end
plugin["xref-symbol"] = function(ref_type, sym, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_97_ = input_check_edit_flag((edit or false), sym)
  local text = _let_97_[1]
  local default = _let_97_[2]
  local function _98_(s)
    return conn:xref(ref_type, s, on_xref_complete)
  end
  return input["maybe-input"](text, _98_, " XRef symbol ", default, conn)
end
plugin["xref-symbol-wrapper"] = function()
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local ref_types = {"calls", "calls-who", "references", "binds", "sets", "macroexpands", "specializes", "definition"}
  if (vim.v.count > 0) then
    local answer = vim.v.count
    return __fnl_global__dispatch_2dxref_2dby_2dindex(ref_types, answer)
  else
    local options = {}
    for i = 1, #ref_types do
      table.insert(options, (i .. ". " .. ref_types[i]))
    end
    vim.cmd("echohl Question")
    vim.cmd("echom 'What kind of xref?'")
    vim.cmd("echohl None")
    local answer = vim.fn.inputlist(options)
    return __fnl_global__dispatch_2dxref_2dby_2dindex(ref_types, answer)
  end
end
local function dispatch_xref_by_index(ref_types, answer)
  if (answer <= 0) then
    ui["err-msg"]("Canceled.")
  else
  end
  if (answer > #ref_types) then
    ui["err-msg"](("Invalid xref type: " .. tostring(answer)))
  else
  end
  local rtype = ref_types[answer]
  if (rtype == "definition") then
    return plugin["find-definition"]()
  else
    return plugin["xref-symbol"](string.upper(rtype))
  end
end
plugin["show-operator-arglist"] = function(op, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_105_ = input_check_edit_flag((edit or false), op)
  local text = _let_105_[1]
  local default = _let_105_[2]
  local function _106_(operator)
    local function _107_(c, result)
      if result then
        ui["show-arglist"](c, result)
        last_arglist_op = operator
        return nil
      else
        return nil
      end
    end
    return conn["operator-arg-list"](conn, operator, _107_)
  end
  return input["maybe-input"](text, _106_, " Arglist for operator ", default, conn)
end
plugin["cur-autodoc"] = function()
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  if conn_has_contrib(conn, "SWANK-ARGLISTS") then
    return ui["err-msg"]("cur-autodoc: blocked on ui_cursor.fnl (ui.CurRawForm unavailable)")
  else
    return ui["err-msg"]("cur-autodoc: blocked on ui_cursor.fnl (ui.SurroundingOperator unavailable)")
  end
end
plugin["set-breakpoint"] = function(sym, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_112_ = input_check_edit_flag((edit or false), sym)
  local text = _let_112_[1]
  local default = _let_112_[2]
  local function _113_(symbol)
    return conn["sldb-break"](conn, symbol, on_sldb_break_complete)
  end
  return input["maybe-input"](text, _113_, " Set breakpoint at function ", default, conn)
end
plugin["list-threads"] = function()
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local function _115_(c, result)
    if c.ui then
      return c.ui["on-threads"](c.ui, c, result)
    else
      return nil
    end
  end
  return conn["list-threads"](conn, _115_)
end
plugin["undefine-function"] = function(sym, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_118_ = input_check_edit_flag((edit or false), sym)
  local text = _let_118_[1]
  local default = _let_118_[2]
  local function _119_(symbol)
    return conn["undefine-function"](conn, symbol, on_undefine_function_complete)
  end
  return input["maybe-input"](text, _119_, " Undefine function ", default, conn)
end
plugin["unintern-symbol"] = function(sym, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local _let_121_ = input_check_edit_flag((edit or false), sym)
  local text = _let_121_[1]
  local default = _let_121_[2]
  local function _122_(raw_sym)
    local matched = vim.fn.matchlist(raw_sym, "\\(\\([^:]\\+\\)\\?::\\?\\)\\?\\(\\k\\+\\)")
    if (#matched > 0) then
      local sym_name = matched[3]
      local prefix = matched[1]
      local sym_pkg
      if (prefix == ":") then
        sym_pkg = "KEYWORD"
      else
        if (prefix == "") then
          sym_pkg = nil
        else
          sym_pkg = matched[2]
        end
      end
      return conn["unintern-symbol"](conn, sym_name, sym_pkg, on_unintern_symbol_complete)
    else
      return nil
    end
  end
  return input["maybe-input"](text, _122_, " Unintern symbol ", default, conn)
end
plugin["undefine-unintern-wrapper"] = function()
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local options = {"1. Undefine a function", "2. Unintern a symbol"}
  vim.cmd("echohl Question")
  vim.cmd("echom 'What to do?'")
  vim.cmd("echohl None")
  local answer = vim.fn.inputlist(options)
  return cond((answer <= 0), ui["err-msg"]("Canceled."), (answer == 1), plugin["undefine-function"](), (answer == 2), plugin["unintern-symbol"](), "else", ui["err-msg"](("Invalid action: " .. tostring(answer))))
end
plugin["swank-require"] = function(contribs, do_init)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local function _128_(c, r)
    return on_swank_require_complete((do_init or true), c, r)
  end
  return conn["swank-require"](conn, contribs, _128_)
end
plugin["dialog-toggle-trace"] = function(func, edit)
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  if not conn_has_contrib(conn, "SWANK-TRACE-DIALOG") then
    ui["err-msg"]("SWANK-TRACE-DIALOG is not available.")
  else
  end
  local _let_131_ = input_check_edit_flag((edit or false), func)
  local text = _let_131_[1]
  local default = _let_131_[2]
  local function _132_(func_spec)
    local function _133_(c, r)
      return vim.cmd("echom 'Traced state toggled.'")
    end
    return conn:DialogToggleTrace(func_spec, _133_)
  end
  return input["maybe-input"](text, _132_, " Toggle tracing ", default, conn)
end
plugin["open-trace-dialog"] = function()
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  if not conn_has_contrib(conn, "SWANK-TRACE-DIALOG") then
    ui["err-msg"]("SWANK-TRACE-DIALOG is not available.")
  else
  end
  local function _136_(c, r)
    if r then
      return vim.fn.luaeval("require(\"nvlime.window.trace\").open(_A)", r)
    else
      return nil
    end
  end
  return conn:ReportSpecs(_136_)
end
plugin["create-mrepl"] = function()
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  if conn_has_contrib(conn, "SWANK-MREPL") then
    local function _139_(c, r)
      return vim.cmd("echom 'MREPL created.'")
    end
    return conn:CreateMREPL(vim.v.null, _139_)
  else
    return nil
  end
end
plugin["show-current-server"] = function()
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local server_obj = conn.cb_data.server
  if server_obj then
    return server.show(server_obj)
  else
    return ui["err-msg"]("No server bound to current connection.")
  end
end
plugin["show-selected-server"] = function()
  local srv = server.select()
  if srv then
    return server.show(srv)
  else
    return nil
  end
end
plugin["stop-current-server"] = function()
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local server_obj = conn.cb_data.server
  if server_obj then
    return server.stop(server_obj)
  else
    return ui["err-msg"]("No server bound to current connection.")
  end
end
plugin["restart-current-server"] = function()
  local conn = conn_manager.get(true)
  if not conn then
  else
  end
  local server_obj = conn.cb_data.server
  if server_obj then
    server.stop(server_obj)
    return server.new(true, false, nil, nil)
  else
    return ui["err-msg"]("No server bound to current connection.")
  end
end
plugin["stop-selected-server"] = function()
  local srv = server.select()
  if srv then
    return server.stop(srv)
  else
    return nil
  end
end
plugin["rename-selected-server"] = function()
  local srv = server.select()
  if srv then
    local new_name = vim.fn.input("New name: ", srv.name)
    if (string.len(new_name) > 0) then
      return server.rename(srv, new_name)
    else
      return nil
    end
  else
    return nil
  end
end
local function on_fuzzy_completions_complete(start_col, cur_pos, conn, result)
  local cur_pos0 = vim.list_slice(vim.fn.getcurpos(), 2, 3)
  local comps = (result[1] or {})
  local r_comps = {}
  if (cur_pos0 ~= vim.list_slice(vim.fn.getcurpos(), 2, 3)) then
  else
  end
  for _, c in ipairs(comps) do
    table.insert(r_comps, {word = c[1], menu = c[4]})
  end
  return pcall(vim.fn.complete, start_col, r_comps)
end
local function on_simple_completions_complete(start_col, cur_pos, conn, result)
  local cur_pos0 = vim.list_slice(vim.fn.getcurpos(), 2, 3)
  local comps = (vim.list_slice(result, 2) or {})
  if (cur_pos0 ~= vim.list_slice(vim.fn.getcurpos(), 2, 3)) then
  else
  end
  return pcall(vim.fn.complete, start_col, comps)
end
plugin.completefunc = function(find_start, base)
  local start_col = complete_find_start()
  if find_start then
    return start_col
  else
    local conn = conn_manager.get(true)
    if not conn then
      return -1
    else
      local raw_pos = vim.list_slice(vim.fn.getcurpos(), 2, 3)
      local cur_pos = {vim.fn.bufnr("%"), raw_pos[1], (raw_pos[2] + string.len(base))}
      if conn_has_contrib(conn, "SWANK-FUZZY") then
        local function _153_(c, r)
          return on_fuzzy_completions_complete((start_col + 1), cur_pos, c, r)
        end
        conn["fuzzy-completions"](conn, base, _153_)
      else
        local function _154_(c, r)
          return on_simple_completions_complete((start_col + 1), cur_pos, c, r)
        end
        conn["simple-completions"](conn, base, _154_)
      end
      return {words = {}, refresh = "always"}
    end
  end
end
plugin["calc-cur-indent"] = function(shift_width)
  local shift_width0 = (shift_width or 2)
  local line_no = vim.fn.line(".")
  return vim.fn.lispindent(line_no)
end
local function space_enter_cb()
  if config.autodoc.enabled then
    return plugin["cur-autodoc"]()
  else
    return plugin["show-operator-arglist"]()
  end
end
plugin["space-enter-key"] = function()
  if (key_timer > 0) then
    vim.fn.timer_stop(key_timer)
  else
  end
  key_timer = vim.fn.timer_start(150, space_enter_cb)
  return nil
end
plugin["tab-key"] = function(key)
  return key
end
plugin.setup = function(force)
  if (not vim.b.nvlime_setup or force) then
    vim.cmd("setlocal omnifunc=v:lua.require'nvlime.core.plugin'.completefunc")
    vim.cmd("setlocal indentexpr=v:lua.require'nvlime.core.plugin'.calc-cur-indent()")
    vim.b.nvlime_setup = true
    return nil
  else
    return nil
  end
end
plugin["interaction-mode"] = function(enable)
  local enable0 = (enable or not (vim.b.nvlime_interaction_mode or false))
  vim.b.nvlime_interaction_mode = enable0
  if enable0 then
    vim.cmd("nnoremap <buffer> <silent> <CR> :lua require('nvlime.core.plugin').send_to_repl(require('nvlime.ui_cursors').cur_expr_or_atom())<CR>")
    vim.cmd("vnoremap <buffer> <silent> <CR> :<C-u>lua require('nvlime.core.plugin').send_to_repl(require('nvlime.ui_cursors').cur_selection())<CR>")
  else
    vim.cmd("nnoremap <buffer> <CR> <CR>")
    vim.cmd("vnoremap <buffer> <CR> <CR>")
  end
  local _162_
  if enable0 then
    _162_ = "enabled"
  else
    _162_ = "disabled"
  end
  return vim.cmd(("echom 'Interaction mode " .. _162_ .. ".'"))
end
local function _164_(self, key)
  return self[string.gsub(key, "_", "-")]
end
setmetatable(plugin, {__index = _164_})
return plugin
