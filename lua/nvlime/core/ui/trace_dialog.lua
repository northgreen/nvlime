local bufnr = vim.fn.bufnr
local getline = vim.fn.getline
local line = vim.fn.line
local getcurpos = vim.fn.getcurpos
local setpos = vim.fn.setpos
local matchlist = vim.fn.matchlist
local getpid = vim.fn.getpid
local getbufvar = vim.fn.getbufvar
local setbufvar = vim.fn.setbufvar
local index = vim.fn.index
local copy = vim.fn.copy
local ui = require("nvlime.core.ui")
local trace_dialog = {}
local indent_level_width = 2
local trace_entry_fold_pattern = "^\\(\\s*\\d*[[:space:]|]\\+\\)\\(`-\\)\\|\\( >\\)\\|\\( <\\)"
local next_fetch_key = 0
trace_dialog["init-trace-dialog-buffer"] = function()
  vim.cmd(("setlocal shiftwidth=" .. indent_level_width))
  vim.cmd("setlocal foldtext=nvlime#ui#trace_dialog#BuildFoldText(v:foldstart)")
  vim.cmd("setlocal foldexpr=nvlime#ui#trace_dialog#CalcFoldLevel(v:lnum)")
  return vim.cmd("setlocal foldmethod=expr")
end
trace_dialog["add-button"] = function(buttons_str, name, co_type, co_id, cur_line, coords)
  local button_begin = {cur_line, (#buttons_str + 1)}
  local buttons_str0 = (buttons_str .. name)
  local button_end = {cur_line, #buttons_str0}
  table.insert(coords, {begin = button_begin, ["end"] = button_end, type = co_type, id = co_id})
  return buttons_str0
end
trace_dialog["calc-line-range-shift"] = function(new, old)
  if not old then
    return 0
  else
    return (new[2] - old[2])
  end
end
trace_dialog["shift-line-range"] = function(line_range, delta)
  if not line_range then
    return nil
  else
    return {(line_range[1] + delta), (line_range[2] + delta)}
  end
end
trace_dialog["get-cur-coord"] = function()
  local cur_pos = getcurpos()
  local cur_line = cur_pos[1]
  local cur_col = cur_pos[2]
  local _3_
  do
    local line_delta = (vim.b.nvlime_trace_specs_line_range[1] - 1)
    local shifted_line = (cur_line - line_delta)
    for _, c in ipairs(vim.b.nvlime_trace_specs_coords) do
      if vim.fn["nvlime#ui#MatchCoord"](c, shifted_line, cur_col) then
        __fnl_global__return(c)
      else
      end
    end
    _3_ = nil
  end
  local _5_
  do
    local line_delta = (vim.b.nvlime_trace_entries_header_line_range[1] - 1)
    local shifted_line = (cur_line - line_delta)
    for _, c in ipairs(vim.b.nvlime_trace_entries_header_coords) do
      if vim.fn["nvlime#ui#MatchCoord"](c, shifted_line, cur_col) then
        __fnl_global__return(c)
      else
      end
    end
    _5_ = nil
  end
  local _7_
  do
    local line_delta = (vim.b.nvlime_trace_entries_line_range[1] - 1)
    local shifted_line = (cur_line - line_delta)
    for _, c in ipairs(vim.b.nvlime_trace_entries_coords) do
      if vim.fn["nvlime#ui#MatchCoord"](c, shifted_line, cur_col) then
        __fnl_global__return(c)
      else
      end
    end
    _7_ = nil
  end
  return cond((vim.b.nvlime_trace_specs_line_range and (cur_line >= vim.b.nvlime_trace_specs_line_range[1]) and (cur_line <= vim.b.nvlime_trace_specs_line_range[2])), _3_, (vim.b.nvlime_trace_entries_header_line_range and (cur_line >= vim.b.nvlime_trace_entries_header_line_range[1]) and (cur_line <= vim.b.nvlime_trace_entries_header_line_range[2])), _5_, (vim.b.nvlime_trace_entries_line_range and (cur_line >= vim.b.nvlime_trace_entries_line_range[1]) and (cur_line <= vim.b.nvlime_trace_entries_line_range[2])), _7_, "else", nil)
end
trace_dialog["name-obj-to-str"] = function(name)
  if name.package then
    return (name.package .. "::" .. name.name)
  else
    local name_type_obj = name[1]
    local name_type_obj0 = cond((name_type_obj.package == "KEYWORD"), (":" .. name_type_obj.name), (name_type_obj.package == "COMMON-LISP"), name_type_obj.name, "else", (name_type_obj.package .. "::" .. name_type_obj.name))
    local name_list = {name_type_obj0}
    for i = 2, #name do
      table.insert(name_list, trace_dialog["name-obj-to-str"](name[i]))
    end
    return ("(" .. table.concat(name_list, " ") .. ")")
  end
end
trace_dialog["arg-list-to-dict"] = function(arg_list)
  local arg_list0 = (arg_list or {})
  local args = {}
  for _, r in ipairs(arg_list0) do
    args[r[1]] = r[2]
  end
  return args
end
trace_dialog["align-trace-id"] = function(id, width)
  local str_id = tostring(id)
  return (string.rep(" ", (width - string.len(str_id))) .. str_id)
end
trace_dialog.indent = function(str, count)
  return (string.rep(" ", count) .. str)
end
trace_dialog["construct-trace-entry-args"] = function(entry_id, arg_dict, prefix, button_type, cur_line, coords)
  local content = ""
  local cur_line0 = cur_line
  do
    local keys = {}
    for k = _, pairs(arg_dict) do
      table.insert(keys, tonumber(k))
    end
    table.sort(keys)
    for _, i in ipairs(keys) do
      local line0 = (prefix .. trace_dialog["add-button"]("", arg_dict[tostring(i)], button_type, {entry_id, i}, cur_line0, coords) .. "\n")
      content = (content .. line0)
      cur_line0 = (cur_line0 + 1)
    end
  end
  return {content, cur_line0}
end
trace_dialog["draw-trace-entries"] = function(toplevel, cached_entries, coords, ...)
  local varargs = {...}
  local cur_level = (varargs[1] or 0)
  local acc_content = (varargs[2] or "")
  local cur_line = (varargs[3] or 1)
  local line_prefix = (varargs[4] or "")
  local id_width = (varargs[5] or nil)
  if not id_width then
    local keys = {}
    for k = _, pairs(cached_entries) do
      table.insert(keys, tonumber(k))
    end
    table.sort(keys)
    if (#keys > 0) then
      id_width = string.len(tostring(keys[#keys]))
    else
      id_width = 0
    end
  else
  end
  local line_prefix0 = line_prefix
  local next_line_prefix = (line_prefix0 .. string.rep(" ", (indent_level_width - 1)) .. "|")
  local content = ""
  local cur_line0 = cur_line
  local line_range = vim.b.nvlime_trace_entries_line_range
  local first_line
  if line_range then
    first_line = line_range[1]
  else
    first_line = line("$")
  end
  local last_line
  if line_range then
    last_line = line_range[2]
  else
    last_line = line("$")
  end
  for i = 1, #toplevel do
    local tid = toplevel[i]
    local entry = cached_entries[tid]
    if ((tid == toplevel[#toplevel]) and (#line_prefix0 > 0)) then
      line_prefix0 = (string.sub(line_prefix0, 1, (string.len(line_prefix0) - 2)) .. " ")
      next_line_prefix = (line_prefix0 .. string.rep(" ", (indent_level_width - 1)) .. "|")
    else
    end
    local connector_char
    if (content == "") then
      connector_char = " "
    else
      connector_char = "`"
    end
    local name_line = (trace_dialog["align-trace-id"](entry.id, id_width) .. line_prefix0 .. connector_char .. string.rep(" ", (indent_level_width - 1)) .. " " .. trace_dialog["name-obj-to-str"](entry.name) .. "\n")
    content = (content .. name_line)
    cur_line0 = (cur_line0 + 1)
    local arg_ret_prefix
    if (#entry.children > 0) then
      arg_ret_prefix = (string.rep(" ", id_width) .. next_line_prefix)
    else
      arg_ret_prefix = (string.rep(" ", id_width) .. string.sub(next_line_prefix, 1, (string.len(next_line_prefix) - 2)) .. " ")
    end
    do
      local _let_17_ = trace_dialog["construct-trace-entry-args"](entry.id, entry.args, (arg_ret_prefix .. " > "), "TRACE-ENTRY-ARG", cur_line0, coords)
      local arg_content = _let_17_[1]
      local new_line = _let_17_[2]
      content = (content .. arg_content)
      cur_line0 = new_line
    end
    do
      local _let_18_ = trace_dialog["construct-trace-entry-args"](entry.id, entry.retvals, (arg_ret_prefix .. " < "), "TRACE-ENTRY-RETVAL", cur_line0, coords)
      local ret_content = _let_18_[1]
      local new_line = _let_18_[2]
      content = (content .. ret_content)
      cur_line0 = new_line
    end
    if (#entry.children > 0) then
      local _let_19_ = trace_dialog["draw-trace-entries"](entry.children, cached_entries, coords, (cur_level + 1), content, cur_line0, next_line_prefix, id_width)
      local child_content = _let_19_[1]
      local new_line = _let_19_[2]
      content = child_content
      cur_line0 = new_line
    else
    end
  end
  if (acc_content == "") then
    do
      local old_cur_pos = getcurpos()
      local pcall_result
      local function _21_()
        return ui["replace-content"](content, first_line, last_line)
      end
      pcall_result = pcall(_21_)
      setpos(".", old_cur_pos)
      if not pcall_result[1] then
        error(pcall_result[2])
      else
      end
    end
    vim.b.nvlime_trace_entries_line_range = {first_line, (first_line + #vim.split(content, "\n", {trimempty = false}) + -1)}
    return nil
  else
    return {(acc_content .. content), cur_line0}
  end
end
trace_dialog["draw-spec-list"] = function(spec_list, coords)
  local line_range = vim.b.nvlime_trace_specs_line_range
  local first_line
  if line_range then
    first_line = line_range[1]
  else
    first_line = 1
  end
  local last_line
  if line_range then
    last_line = line_range[2]
  else
    last_line = line("$")
  end
  local spec_list0 = (spec_list or {})
  local title = ("Traced (" .. tostring(#spec_list0) .. ")")
  local content = (title .. "\n" .. string.rep("=", string.len(title)) .. "\n\n")
  local cur_line = 4
  do
    local header_buttons = trace_dialog["add-button"](trace_dialog["add-button"]("", "[refresh]", "REFRESH-SPECS", nil, cur_line, coords), " ", nil, nil, cur_line, coords)
    content = (content .. trace_dialog["add-button"](header_buttons, "[untrace all]", "UNTRACE-ALL-SPECS", nil, cur_line, coords) .. "\n\n")
    cur_line = (cur_line + 2)
  end
  for _, spec in ipairs(spec_list0) do
    local untrace_btn = trace_dialog["add-button"]("", "[untrace]", "UNTRACE-SPEC", spec, cur_line, coords)
    content = (content .. untrace_btn .. " " .. trace_dialog["name-obj-to-str"](spec) .. "\n")
    cur_line = (cur_line + 1)
  end
  content = (content .. "\n")
  do
    local old_cur_pos = getcurpos()
    local pcall_result
    local function _26_()
      return ui["replace-content"](content, first_line, last_line)
    end
    pcall_result = pcall(_26_)
    setpos(".", old_cur_pos)
    if not pcall_result[1] then
      error(pcall_result[2])
    else
    end
  end
  vim.b.nvlime_trace_specs_line_range = {first_line, (first_line + #vim.split(content, "\n", {trimempty = false}) + -1)}
  local delta = trace_dialog["calc-line-range-shift"](vim.b.nvlime_trace_specs_line_range, line_range)
  vim.b.nvlime_trace_entries_header_line_range = trace_dialog["shift-line-range"](vim.b.nvlime_trace_entries_header_line_range, delta)
  vim.b.nvlime_trace_entries_line_range = trace_dialog["shift-line-range"](vim.b.nvlime_trace_entries_line_range, delta)
  return nil
end
trace_dialog["draw-trace-entry-header"] = function(entry_count, cached_entry_count, coords)
  local line_range = vim.b.nvlime_trace_entries_header_line_range
  local first_line
  if line_range then
    first_line = line_range[1]
  else
    first_line = line("$")
  end
  local last_line
  if line_range then
    last_line = line_range[2]
  else
    last_line = line("$")
  end
  local title = ("Trace Entries (" .. tostring(cached_entry_count) .. "/" .. tostring(entry_count) .. ")")
  local content = (title .. "\n" .. string.rep("=", string.len(title)) .. "\n\n")
  local cur_line = 4
  local header_buttons = trace_dialog["add-button"]("", "[refresh]", "REFRESH-TRACE-ENTRY-HEADER", nil, cur_line, coords)
  header_buttons = (header_buttons .. " ")
  if __fnl_global___21_3d(cached_entry_count, entry_count) then
    header_buttons = trace_dialog["add-button"](header_buttons, "[fetch next batch]", "FETCH-NEXT-TRACE-ENTRIES-BATCH", nil, cur_line, coords)
    header_buttons = (header_buttons .. " ")
    header_buttons = trace_dialog["add-button"](header_buttons, "[fetch all]", "FETCH-ALL-TRACE-ENTRIES", nil, cur_line, coords)
    header_buttons = (header_buttons .. " ")
  else
  end
  header_buttons = trace_dialog["add-button"](header_buttons, "[clear]", "CLEAR-TRACE-ENTRIES", nil, cur_line, coords)
  content = (content .. header_buttons .. "\n\n")
  do
    local old_cur_pos = getcurpos()
    local pcall_result
    local function _31_()
      return ui["replace-content"](content, first_line, last_line)
    end
    pcall_result = pcall(_31_)
    setpos(".", old_cur_pos)
    if not pcall_result[1] then
      error(pcall_result[2])
    else
    end
  end
  if not line_range then
    vim.b.nvlime_trace_entries_header_line_range = {first_line, (first_line + #vim.split(content, "\n", {trimempty = false}) + -2)}
    return nil
  else
    vim.b.nvlime_trace_entries_header_line_range = {first_line, (first_line + #vim.split(content, "\n", {trimempty = false}) + -1)}
    return nil
  end
end
trace_dialog["get-fetch-key"] = function()
  if not vim.b.nvlime_trace_fetch_key then
    local fetch_key = next_fetch_key
    next_fetch_key = (fetch_key + 1)
    if (next_fetch_key > 65535) then
      next_fetch_key = 0
    else
    end
    vim.b.nvlime_trace_fetch_key = (tostring(getpid()) .. "_" .. tostring(fetch_key))
  else
  end
  return vim.b.nvlime_trace_fetch_key
end
trace_dialog["reset-trace-entries"] = function()
  vim.b.nvlime_trace_fetch_key = nil
  vim.b.nvlime_trace_cached_entries = nil
  vim.b.nvlime_trace_toplevel_entries = nil
  vim.b.nvlime_trace_max_id = nil
  vim.b.nvlime_trace_entries_coords = nil
  local line_range = vim.b.nvlime_trace_entries_line_range
  vim.b.nvlime_trace_entries_line_range = nil
  if line_range then
    vim.cmd("setlocal modifiable")
    vim.cmd((line_range[1] .. "," .. line_range[2] .. "delete _"))
    vim.fn.append((line_range[1] - 1), "")
    return vim.cmd("setlocal nomodifiable")
  else
    return nil
  end
end
trace_dialog["report-specs-complete"] = function(trace_buf, conn, result)
  local coords = {}
  setbufvar(trace_buf, "modifiable", 1)
  local function _37_()
    return trace_dialog["draw-spec-list"](result, coords)
  end
  ui["with-buffer"](trace_buf, _37_)
  setbufvar(trace_buf, "modifiable", 0)
  return setbufvar(trace_buf, "nvlime_trace_specs_coords", coords)
end
trace_dialog["report-total-complete"] = function(trace_buf, conn, result)
  local cached_entries = getbufvar(trace_buf, "nvlime_trace_cached_entries", {})
  local coords = {}
  setbufvar(trace_buf, "modifiable", 1)
  local function _38_()
    return trace_dialog["draw-trace-entry-header"](result, #cached_entries, coords)
  end
  ui["with-buffer"](trace_buf, _38_)
  setbufvar(trace_buf, "modifiable", 0)
  return setbufvar(trace_buf, "nvlime_trace_entries_header_coords", coords)
end
trace_dialog["dialog-untrace-all-complete"] = function(trace_buf, conn, result)
  if result then
    for _, r in ipairs(result) do
      print(r)
    end
  else
  end
  local function _40_(_241)
    return trace_dialog["report-specs-complete"](trace_buf, conn, _241)
  end
  return conn:ReportSpecs(_40_)
end
trace_dialog["dialog-untrace-complete"] = function(trace_buf, conn, result)
  print(result)
  local function _41_(_241)
    return trace_dialog["report-specs-complete"](trace_buf, conn, _241)
  end
  return conn:ReportSpecs(_41_)
end
trace_dialog["report-partial-tree-complete"] = function(trace_buf, fetch_all, conn, result)
  local entry_list = result[1]
  local remaining = result[2]
  local fetch_key = result[3]
  local entry_list0 = (entry_list or {})
  local cached_entries = getbufvar(trace_buf, "nvlime_trace_cached_entries", {})
  local toplevel_entries = getbufvar(trace_buf, "nvlime_trace_toplevel_entries", {})
  local max_id = getbufvar(trace_buf, "nvlime_trace_max_id", 0)
  for _, t_entry in ipairs(entry_list0) do
    local id = t_entry[1]
    local parent = t_entry[2]
    local name = t_entry[3]
    local arg_list = t_entry[4]
    local retval_list = t_entry[5]
    local entry_obj = (cached_entries[id] or {id = id, children = {}})
    entry_obj.id = id
    entry_obj.parent = parent
    entry_obj.name = name
    entry_obj.args = trace_dialog["arg-list-to-dict"](arg_list)
    entry_obj.retvals = trace_dialog["arg-list-to-dict"](retval_list)
    do
      local parent_obj
      if parent then
        parent_obj = cached_entries[parent]
      else
        parent_obj = nil
      end
      if not parent_obj then
        if (index(toplevel_entries, id) < 0) then
          table.insert(toplevel_entries, id)
        else
        end
      else
        if (index(parent_obj.children, id) < 0) then
          table.insert(parent_obj.children, id)
        else
        end
      end
    end
    cached_entries[id] = entry_obj
    if (id > max_id) then
      max_id = id
    else
    end
  end
  setbufvar(trace_buf, "nvlime_trace_cached_entries", cached_entries)
  setbufvar(trace_buf, "nvlime_trace_toplevel_entries", toplevel_entries)
  setbufvar(trace_buf, "nvlime_trace_max_id", max_id)
  if (fetch_all and (remaining > 0)) then
    local function _47_(_241)
      return trace_dialog["report-partial-tree-complete"](trace_buf, fetch_all, conn, _241)
    end
    return conn:ReportPartialTree(fetch_key, _47_)
  else
    vim.cmd("setlocal modifiable")
    do
      local header_coords = {}
      local function _48_()
        return trace_dialog["draw-trace-entry-header"]((#cached_entries + remaining), #cached_entries, header_coords)
      end
      ui["with-buffer"](trace_buf, _48_)
      setbufvar(trace_buf, "nvlime_trace_entries_header_coords", header_coords)
    end
    local entry_coords = {}
    local function _49_()
      return trace_dialog["draw-trace-entries"](toplevel_entries, cached_entries, entry_coords)
    end
    ui["with-buffer"](trace_buf, _49_)
    vim.cmd("setlocal nomodifiable")
    return setbufvar(trace_buf, "nvlime_trace_entries_coords", entry_coords)
  end
end
trace_dialog["clear-trace-tree-complete"] = function(trace_buf, conn, result)
  ui["with-buffer"](trace_buf, trace_dialog["reset-trace-entries"])
  local function _51_(_241)
    return trace_dialog["report-total-complete"](trace_buf, conn, _241)
  end
  return conn:ReportTotal(_51_)
end
trace_dialog["init-trace-dialog-buf"] = function(conn)
  local _let_52_ = vim.fn.luaeval("require\"nvlime.window.trace\".open(_A[1], _A[2])", {{}, {["conn-name"] = conn.cb_data.name}})
  local _win = _let_52_[1]
  local bufnr0 = _let_52_[2]
  local bufnr1 = tonumber(bufnr0)
  if not ui["nvlime-buffer-initialized"](bufnr1) then
    setbufvar(bufnr1, "nvlime_conn", conn)
    ui["with-buffer"](bufnr1, trace_dialog["init-trace-dialog-buffer"])
  else
  end
  return bufnr1
end
trace_dialog["fill-trace-dialog-buf"] = function(spec_list, trace_count)
  vim.cmd("setlocal modifiable")
  vim.b.nvlime_trace_specs_coords = {}
  trace_dialog["draw-spec-list"](spec_list, vim.b.nvlime_trace_specs_coords)
  vim.b.nvlime_trace_entries_header_coords = {}
  do
    local cached_entries = (vim.b.nvlime_trace_cached_entries or {})
    trace_dialog["draw-trace-entry-header"](trace_count, #cached_entries, vim.b.nvlime_trace_entries_header_coords)
  end
  return vim.cmd("setlocal nomodifiable")
end
trace_dialog["refresh-specs"] = function()
  local function _54_(_241)
    return trace_dialog["report-specs-complete"](bufnr("%"), vim.b.nvlime_conn, _241)
  end
  return vim.b.nvlime_conn:ReportSpecs(_54_)
end
trace_dialog.select = function(...)
  local varargs = {...}
  local action = (varargs[1] or "button")
  local coord = trace_dialog["get-cur-coord"]()
  if not coord then
    __fnl_global__return()
  else
  end
  if (action == "button") then
    local function _56_(_241)
      return trace_dialog["dialog-untrace-all-complete"](bufnr("%"), vim.b.nvlime_conn, _241)
    end
    local function _57_(_241)
      return trace_dialog["dialog-untrace-complete"](bufnr("%"), vim.b.nvlime_conn, _241)
    end
    local function _58_(_241)
      return trace_dialog["report-total-complete"](bufnr("%"), vim.b.nvlime_conn, _241)
    end
    local function _59_(_241)
      return trace_dialog["report-partial-tree-complete"](bufnr("%"), false, vim.b.nvlime_conn, _241)
    end
    local function _60_(_241)
      return trace_dialog["report-partial-tree-complete"](bufnr("%"), true, vim.b.nvlime_conn, _241)
    end
    local function _61_(_241)
      return trace_dialog["clear-trace-tree-complete"](bufnr("%"), vim.b.nvlime_conn, _241)
    end
    return cond((coord.type == "REFRESH-SPECS"), trace_dialog["refresh-specs"](), (coord.type == "UNTRACE-ALL-SPECS"), vim.b.nvlime_conn:DialogUntraceAll(_56_), (coord.type == "UNTRACE-SPEC"), vim.b.nvlime_conn:DialogUntrace({vim.fn["nvlime#CL"]("QUOTE"), coord.id}, _57_), (coord.type == "REFRESH-TRACE-ENTRY-HEADER"), vim.b.nvlime_conn:ReportTotal(_58_), (coord.type == "FETCH-NEXT-TRACE-ENTRIES-BATCH"), vim.b.nvlime_conn:ReportPartialTree(trace_dialog["get-fetch-key"](), _59_), (coord.type == "FETCH-ALL-TRACE-ENTRIES"), vim.b.nvlime_conn:ReportPartialTree(trace_dialog["get-fetch-key"](), _60_), (coord.type == "CLEAR-TRACE-ENTRIES"), vim.b.nvlime_conn:ClearTraceTree(_61_))
  elseif ((coord.type == "TRACE-ENTRY-ARG") or (coord.type == "TRACE-ENTRY-RETVAL")) then
    local _62_
    do
      local part_type
      if (coord.type == "TRACE-ENTRY-ARG") then
        part_type = "ARG"
      else
        part_type = "RETVAL"
      end
      local function _64_(c, r)
        return c.ui.OnInspect[c][r][nil][nil]
      end
      _62_ = vim.b.nvlime_conn:InspectTracePart(coord.id[1], coord.id[2], part_type, _64_)
    end
    local function _66_(...)
      local part_type
      if (coord.type == "TRACE-ENTRY-ARG") then
        part_type = ":arg"
      else
        part_type = ":retval"
      end
      local args_str = table.concat({tostring(coord.id[1]), tostring(coord.id[2]), part_type}, " ")
      vim.b.nvlime_conn.ui:OnWriteString(vim.b.nvlime_conn, "--\n", {name = "REPL-SEP", package = "KEYWORD"})
      local function _67_()
        return vim.b.nvlime_conn:ListenerEval(("(nth-value 0 (swank-trace-dialog:find-trace-part " .. args_str .. "))"))
      end
      return vim.b.nvlime_conn:WithThread({name = "REPL-THREAD", package = "KEYWORD"}, _67_)
    end
    return cond((action == "inspect"), _62_, (action == "to_repl"), _66_(...))
  else
    return nil
  end
end
trace_dialog["next-field"] = function(forward)
  local cur_pos = getcurpos()
  local dir_int
  if forward then
    dir_int = 1
  else
    dir_int = 0
  end
  local coord_specs
  local function _70_()
    vim.b._nvlime_tmp_coords = copy(vim.b.nvlime_trace_specs_coords)
    return vim.fn.eval(("sort(b:_nvlime_tmp_coords, " .. "function('nvlime#ui#CoordSorter', [" .. dir_int .. "]))"))
  end
  coord_specs = {vim.b.nvlime_trace_specs_line_range, _70_()}
  local coord_header
  local function _71_()
    vim.b._nvlime_tmp_coords = copy(vim.b.nvlime_trace_entries_header_coords)
    return vim.fn.eval(("sort(b:_nvlime_tmp_coords, " .. "function('nvlime#ui#CoordSorter', [" .. dir_int .. "]))"))
  end
  coord_header = {vim.b.nvlime_trace_entries_header_line_range, _71_()}
  local coord_entries
  local function _72_()
    vim.b._nvlime_tmp_coords = copy(vim.b.nvlime_trace_entries_coords)
    return vim.fn.eval(("sort(b:_nvlime_tmp_coords, " .. "function('nvlime#ui#CoordSorter', [" .. dir_int .. "]))"))
  end
  coord_entries = {vim.b.nvlime_trace_entries_line_range, _72_()}
  local coord_groups = {coord_specs, coord_header, coord_entries}
  local coord_groups0 = coord_groups
  if not forward then
    local reversed = {}
    for i = #coord_groups0, 1, -1 do
      table.insert(reversed, coord_groups0[i])
    end
    coord_groups0 = reversed
  else
  end
  local next_coord = nil
  local next_line_range = nil
  for _, group in ipairs(coord_groups0) do
    local line_range = group[1]
    local sorted_coords = group[2]
    if line_range then
      local shifted_line = (cur_pos[1] - line_range[1] - -1)
      local found = vim.fn["nvlime#ui#FindNextCoord"]({shifted_line, cur_pos[2]}, sorted_coords, forward)
      if found then
        next_coord = found
        next_line_range = line_range
        __fnl_global__return()
      else
      end
    else
    end
  end
  if not next_coord then
    for _, group in ipairs(coord_groups0) do
      local sorted_coords = group[2]
      if (#sorted_coords > 0) then
        next_coord = sorted_coords[1]
        next_line_range = group[1]
        __fnl_global__return()
      else
      end
    end
  else
  end
  if (next_coord and next_line_range) then
    local next_line = (next_coord.begin[1] + next_line_range[1] + -1)
    local next_col = next_coord.begin[2]
    return setpos(".", {0, next_line, next_col, 0, next_col})
  else
    return nil
  end
end
trace_dialog["calc-fold-level"] = function(...)
  local varargs = {...}
  local line_nr = (varargs[1] or vim.v.lnum)
  local line_text = getline(line_nr)
  local matched = matchlist(line_text, trace_entry_fold_pattern)
  if (#matched > 0) then
    local id_width
    if vim.b.nvlime_trace_max_id then
      id_width = string.len(tostring(vim.b.nvlime_trace_max_id))
    else
      id_width = 0
    end
    return ((string.len(matched[2]) - id_width) // 2)
  else
    return 0
  end
end
trace_dialog["build-fold-text"] = function(...)
  local varargs = {...}
  local fold_start = (varargs[1] or vim.v.foldstart)
  local s_line = getline(fold_start)
  local matched = matchlist(s_line, trace_entry_fold_pattern)
  if (#matched > 0) then
    return (matched[2] .. " ")
  else
    return "..."
  end
end
return trace_dialog
