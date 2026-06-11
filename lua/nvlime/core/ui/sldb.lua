local nvim_buf_set_lines = vim.api.nvim_buf_set_lines
local nvim_buf_set_option = vim.api.nvim_buf_set_option
local luaeval = vim.fn.luaeval
local bufnr = vim.fn.bufnr
local getline = vim.fn.getline
local line = vim.fn.line
local search = vim.fn.search
local setpos = vim.fn.setpos
local deletebufline = vim.fn.deletebufline
local inputlist = vim.fn.inputlist
local win_id2win = vim.fn.win_id2win
local win_gotoid = vim.fn.win_gotoid
local matchlist = vim.fn.matchlist
local ui = require("nvlime.core.ui")
local buffer = require("nvlime.buffer")
local input = require("nvlime.core.ui.input")
local messages = require("nvlime.core.connection.messages")
local events = require("nvlime.core.connection.events")
local conn = require("nvlime.core.connection")
local sldb = {}
sldb["find-max-restart-name-len"] = function(restarts)
  local max_name_len = 0
  local has_star = false
  for _, r in ipairs(restarts) do
    local name = r[1]
    if (name[1] == "*") then
      has_star = true
      local name_len = (#name - 1)
      if (name_len > max_name_len) then
        max_name_len = name_len
      else
      end
    else
      local name_len = #name
      if (name_len > max_name_len) then
        max_name_len = name_len
      else
      end
    end
  end
  return {max_name_len, has_star}
end
sldb["format-restart-line"] = function(r, max_name_len, has_star)
  local name = r[1]
  local desc = r[2]
  local has_star_prefix = (name[1] == "*")
  if has_star then
    if has_star_prefix then
      local pad = string.rep(" ", ((max_name_len - (#name - 1)) + 1))
      return (" " .. name .. pad .. "- " .. desc)
    else
      local pad = string.rep(" ", ((max_name_len - #name) + 1))
      return (" " .. name .. pad .. "- " .. desc)
    end
  else
    local pad = string.rep(" ", ((max_name_len - #name) + 1))
    return (" " .. name .. pad .. "- " .. desc)
  end
end
sldb["match-var-index"] = function()
  local loc = search("\\v^\\tLocals:$", "bnWz")
  local this = line(".")
  return (this - loc - -1)
end
sldb["match-var-name"] = function()
  local matches = matchlist(getline("."), "\\v^\\t  ([^ ]+):\\s+")
  if (#matches > 0) then
    return matches[2]
  else
    return ""
  end
end
sldb["match-file"] = function()
  local matches = matchlist(getline("."), "\\v^\\tFile:\\s+(.*) ([0-9]+)$")
  if (#matches > 0) then
    return {matches[2], matches[3]}
  else
    return {0, 0}
  end
end
sldb["match-restart"] = function()
  local matches = matchlist(getline("."), "\\v^  R\\s+([0-9]+)\\.\\s+\\*?[a-zA-Z\\-]+\\s+-\\s.+$")
  if (#matches > 0) then
    return tonumber(matches[2])
  else
    return -1
  end
end
sldb["match-frame-string"] = function(line0)
  local matches = matchlist(line0, "\\v^  F\\s+([0-9]+)\\.\\s")
  if (#matches > 0) then
    return tonumber(matches[2])
  else
    return -1
  end
end
sldb["match-frame"] = function(...)
  local srch_backwards = (select(1, ...) or false)
  local line0 = getline(".")
  local fnd = sldb["match-frame-string"](line0)
  if ((fnd > -1) or not srch_backwards) then
    return fnd
  else
    local lnr = search("\\v^[^\\t]", "bnWz")
    if (lnr == 0) then
      return -1
    else
      return sldb["match-frame-string"](getline(lnr))
    end
  end
end
sldb["frame-restartable"] = function(frame)
  if (#frame > 2) then
    local flags = messages["plist-to-dict"](nil, frame[3])
    return conn.get(flags, "RESTARTABLE", false)
  else
    return false
  end
end
sldb["show-frame-locals-cb"] = function(frame, restartable, line0, conn0, result)
  local content = "\n"
  local locals = result[1]
  if locals then
    content = (content .. "\tLocals:\n")
    local rlocals = {}
    local max_name_len = 0
    for _, lc in ipairs(locals) do
      local rlc = messages["plist-to-dict"](nil, lc)
      table.insert(rlocals, rlc)
      local rlc_l = #conn0.get(rlc, "NAME")
      if (rlc_l > max_name_len) then
        max_name_len = rlc_l
      else
      end
    end
    for _, rlc in ipairs(rlocals) do
      content = (content .. "\t  " .. vim.fn["nvlime#ui#Pad"](conn0.get(rlc, "NAME"), ":", max_name_len) .. conn0.get(rlc, "VALUE") .. "\n")
    end
  else
  end
  do
    local catch_tags = result[2]
    if catch_tags then
      content = (content .. "\tCatch tags:\n")
      for _, ct in ipairs(catch_tags) do
        content = (content .. "\t  " .. ct .. "\n")
      end
    else
    end
  end
  local thread = conn0("GetCurrentThread")
  local buf = bufnr(ui["sldb-buf-name"](conn0, thread), false)
  local function _16_()
    vim.cmd("setlocal modifiable")
    ui["append-string"](content, line0)
    return vim.cmd("setlocal nomodifiable")
  end
  return ui["with-buffer"](buf, _16_)
end
sldb["show-frame-source-location-cb"] = function(frame, line0, conn0, result)
  if not (result[1].name == "LOCATION") then
    ui["err-msg"](result[2])
  else
  end
  local snippet = ""
  local content = ""
  if (type(result[2]) == "table") then
    local r = events["keyword-list-2-dict"](nil, vim.fn.slice(result, 1))
    if conn0["has-key"](r, "SNIPPET") then
      snippet = conn0.get(r, "SNIPPET")
    else
    end
    if conn0["has-key"](r, "SOURCE-FORM") then
      snippet = conn0.get(r, "SOURCE-FORM")
    else
    end
    if (conn0["has-key"](r, "FILE") and conn0["has-key"](r, "POSITION")) then
      content = (content .. "\n\tFile: " .. conn0.get(r, "FILE") .. " " .. conn0.get(r, "POSITION") .. "\n")
    else
    end
  else
    content = (content .. "\n\tPosition: " .. result[2] .. "\n")
    snippet = nil
  end
  if snippet then
    local snippet_lines = vim.split(snippet, "\n", {trimempty = false})
    local indented_lines = {}
    for _, val in ipairs(snippet_lines) do
      table.insert(indented_lines, ("\t  " .. val))
    end
    content = (content .. "\n\tSnippet:\n" .. table.concat(indented_lines, "\n") .. "\n")
  else
  end
  local thread = conn0("GetCurrentThread")
  local buf = bufnr(ui["sldb-buf-name"](conn0, thread), false)
  local function _23_()
    vim.cmd("setlocal modifiable")
    ui["append-string"](content, line0)
    return vim.cmd("setlocal nomodifiable")
  end
  return ui["with-buffer"](buf, _23_)
end
sldb["open-frame-source-cb"] = function(edit_cmd, win_to_go, force_open, conn0, result)
  local pcall_result
  local function _24_()
    local src_loc = events["parse-source-location"](nil, result)
    return events["get-valid-source-location"](nil, src_loc)
  end
  pcall_result = pcall(_24_)
  local valid_loc
  if pcall_result[1] then
    valid_loc = pcall_result[2]
  else
    valid_loc = {}
  end
  if ((#valid_loc > 0) and valid_loc[2]) then
    if (win_to_go > 0) then
      if (win_id2win(win_to_go) <= 0) then
      else
      end
      win_gotoid(win_to_go)
    else
    end
    return vim.fn["nvlime#ui#ShowSource"](conn0, valid_loc, edit_cmd, force_open)
  else
    if (result and (result[1].name == "ERROR")) then
      return ui["err-msg"](result[2])
    else
      return ui["err-msg"]("No source available.")
    end
  end
end
sldb["find-source-cb"] = function(edit_cmd, win_to_go, force_open, frame, conn0, msg)
  local locals = msg[1]
  if not locals then
    ui["err-msg"]("No local variable.")
  else
  end
  local options = {}
  for idx, lc in ipairs(locals) do
    local lc_dict = messages["plist-to-dict"](nil, lc)
    local var_name = conn0.get(lc_dict, "NAME")
    table.insert(options, (tostring(idx) .. ". " .. var_name))
  end
  vim.cmd("echohl Question")
  vim.cmd("echom 'Which variable?'")
  vim.cmd("echohl None")
  do
    local nth_var = inputlist(options)
    if (nth_var > 0) then
      local function _31_(c, r)
        return sldb["open-frame-source-cb"](edit_cmd, win_to_go, force_open, c, r)
      end
      conn0("FindSourceLocationForEmacs", {"SLDB", frame, (nth_var - 1)}, _31_)
    else
    end
  end
  return ui["err-msg"]("Canceled.")
end
sldb["inspect-in-cur-frame-input-complete"] = function(frame, thread)
  local content = ui["cur-buffer-content"](true)
  if (#content > 0) then
    local function _33_()
      local function _34_(c, r)
        return c:ui().OnInspect(c, r, nil, nil)
      end
      return vim.b.nvlime_conn("InspectInFrame", content, frame, _34_)
    end
    return vim.b.nvlime_conn("WithThread", thread, _33_)
  else
    return ui["err-msg"]("Canceled.")
  end
end
sldb["eval-string-in-cur-frame-input-complete"] = function(frame, thread, package)
  local content = ui["cur-buffer-content"](true)
  if (#content > 0) then
    local function _36_()
      local function _37_(c, r)
        return c:ui().OnWriteString(c, (r .. "\n"), {name = "FRAME-EVAL-RESULT", package = "KEYWORD"})
      end
      return vim.b.nvlime_conn("EvalStringInFrame", content, frame, package, _37_)
    end
    return vim.b.nvlime_conn("WithThread", thread, _36_)
  else
    return ui["err-msg"]("Canceled.")
  end
end
sldb["send-value-in-cur-frame-to-repl-input-complete"] = function(frame, thread, package)
  do
    local content = ui["cur-buffer-content"](true)
    if (#content > 0) then
      local escaped_content = select(1, string.gsub(content, "\"", "\\\""))
      local eval_expr = ("(setf cl-user::* #.(read-from-string \"" .. escaped_content .. "\"))")
      local function _39_()
        local function _40_(c, _r)
          local function _41_()
            return c.ListenerEval("cl-user::*")
          end
          return c("WithThread", {name = "REPL-THREAD", package = "KEYWORD"}, _41_)
        end
        return vim.b.nvlime_conn("EvalStringInFrame", eval_expr, frame, package, _40_)
      end
      vim.b.nvlime_conn("WithThread", thread, _39_)
      ui["err-msg"]("Canceled.")
    else
    end
  end
  sldb["return-from-cur-frame-input-complete"] = function(frame0, thread0)
    local content = ui["cur-buffer-content"](true)
    if (#content > 0) then
      local function _43_()
        return vim.b.nvlime_conn("SLDBReturnFromFrame", frame0, content)
      end
      return vim.b.nvlime_conn("WithThread", thread0, _43_)
    else
      return ui["err-msg"]("Canceled.")
    end
  end
  sldb["fill-sldb-buf"] = function(thread0, level, condition, restarts, frames)
    vim.cmd("setlocal modifiable")
    nvim_buf_set_lines(0, 0, -1, false, {})
    vim.fn["nvlime#ui#AppendString"](("Thread: " .. thread0 .. "; Level: " .. tostring(level) .. "\n\n"))
    local condition_str = ""
    for _, c in ipairs(condition) do
      if (type(c) == "string") then
        condition_str = (condition_str .. c .. "\n")
      else
      end
    end
    condition_str = (condition_str .. "\n")
    vim.fn["nvlime#ui#AppendString"](condition_str)
    local restarts_str = "Restarts:\n"
    do
      local _let_46_ = sldb["find-max-restart-name-len"](restarts)
      local max_name_len = _let_46_[1]
      local has_star = _let_46_[2]
      local max_digits = string.len(tostring((#restarts - 1)))
      for ri = 0, (#restarts - 1) do
        local r = restarts[(ri + 1)]
        local idx_str = vim.fn["nvlime#ui#Pad"](tostring(ri), ".", max_digits)
        local restart_line = sldb["format-restart-line"](r, max_name_len, has_star)
        restarts_str = (restarts_str .. "  R " .. idx_str .. restart_line .. "\n")
      end
    end
    restarts_str = (restarts_str .. "\n")
    vim.fn["nvlime#ui#AppendString"](restarts_str)
    local frames_str = "Frames:\n"
    do
      local max_digits = string.len(tostring((#frames - 1)))
      for _, f in ipairs(frames) do
        local idx_str = vim.fn["nvlime#ui#Pad"](tostring(f[1]), ".", max_digits)
        frames_str = (frames_str .. "  F " .. idx_str .. f[2] .. "\n")
      end
    end
    vim.fn["nvlime#ui#AppendString"](frames_str)
    return vim.cmd("setlocal nomodifiable")
  end
  sldb["choose-cur-restart"] = function()
    do
      local nth = sldb["match-restart"]()
      if (nth >= 0) then
        vim.b.nvlime_conn("InvokeNthRestartForEmacs", vim.b.nvlime_sldb_level, nth)
      else
      end
    end
    if (sldb["show-frame-details"]() > -1) then
    else
    end
    local _let_49_ = sldb["match-file"]()
    local fn_name = _let_49_[1]
    local pos = _let_49_[2]
    if (#fn_name > 0) then
      return sldb["open-frame-source"]()
    else
      return nil
    end
  end
  sldb["show-frame-details"] = function()
    local nth = sldb["match-frame"]()
    if (nth < 0) then
    else
    end
    do
      local cur_line = line(".")
      local frame_line_pattern = "^\\s*F \\d\\+\\|^\\%$"
      if __fnl_global___21_3d(vim.fn.match(getline((cur_line + 1)), frame_line_pattern), -1) then
        local frame0 = vim.b.nvlime_sldb_frames[(nth + 1)]
        local restartable = sldb["frame-restartable"](frame0)
        local function _52_(continuation)
          local function _53_(c, r)
            return continuation(nth, restartable, cur_line, c, r)
          end
          return vim.b.nvlime_conn("FrameLocalsAndCatchTags", nth, _53_)
        end
        local function _54_(...)
          local args = {...}
          return apply(sldb["show-frame-locals-cb"], args)
        end
        messages["chain-callbacks"](nil, _52_, _54_)
      else
        local next_frame_line = search(frame_line_pattern, "nW")
        if (next_frame_line > 0) then
          vim.cmd("setlocal modifiable")
          deletebufline(bufnr("%"), (cur_line + 1), (next_frame_line - 1))
          vim.cmd("setlocal nomodifiable")
        else
        end
      end
    end
    return 1
  end
  return sldb["show-frame-details"]
end
sldb["open-frame-source"] = function(...)
  local edit_cmd = (select(1, ...) or "hide edit")
  local nth = sldb["match-frame"](true)
  if (nth < 0) then
    nth = 0
  else
  end
  local _let_58_ = vim.fn["nvlime#ui#ChooseWindowWithCount"](nil)
  local win_to_go = _let_58_[1]
  local count_specified = _let_58_[2]
  if ((win_to_go <= 0) and count_specified) then
  else
  end
  local function _60_(c, r)
    return sldb["open-frame-source-cb"](edit_cmd, win_to_go, count_specified, c, r)
  end
  return vim.b.nvlime_conn("FrameSourceLocation", nth, _60_)
end
sldb["find-source"] = function(...)
  local edit_cmd = (select(1, ...) or "hide edit")
  local nth = sldb["match-frame"]()
  if (nth < 0) then
    nth = 0
  else
  end
  local _let_62_ = vim.fn["nvlime#ui#ChooseWindowWithCount"](nil)
  local win_to_go = _let_62_[1]
  local count_specified = _let_62_[2]
  if ((win_to_go <= 0) and count_specified) then
  else
  end
  local function _64_(c, msg)
    return sldb["find-source-cb"](edit_cmd, win_to_go, count_specified, nth, c, msg)
  end
  return vim.b.nvlime_conn("FrameLocalsAndCatchTags", nth, _64_)
end
sldb["restart-cur-frame"] = function()
  local nth = sldb["match-frame"]()
  if ((nth >= 0) and (nth < #vim.b.nvlime_sldb_frames)) then
    local frame = vim.b.nvlime_sldb_frames[(nth + 1)]
    if sldb["frame-restartable"](frame) then
      return vim.b.nvlime_conn("RestartFrame", nth)
    else
      return ui["err-msg"](("Frame " .. tostring(nth) .. " is not restartable."))
    end
  else
    return nil
  end
end
sldb["step-cur-or-last-frame"] = function(opr)
  local nth = sldb["match-frame"]()
  if (nth < 0) then
    nth = 0
  else
  end
  if (opr == "step") then
    return vim.b.nvlime_conn("SLDBStep", nth)
  elseif (opr == "next") then
    return vim.b.nvlime_conn("SLDBNext", nth)
  elseif (opr == "out") then
    return vim.b.nvlime_conn("SLDBOut", nth)
  else
    return nil
  end
end
sldb["inspect-cur-condition"] = function()
  local function _69_(c, r)
    return c:ui().OnInspect(c, r, nil, nil)
  end
  return vim.b.nvlime_conn("InspectCurrentCondition", _69_)
end
sldb["inspect-var-in-cur-frame"] = function()
  local varname = sldb["match-var-name"]()
  local nth = sldb["match-frame"](true)
  if (nth < 0) then
  else
  end
  local thread = vim.b.nvlime_conn("GetCurrentThread")
  local var_num = sldb["match-var-index"]()
  if ((#varname > 0) and (var_num >= 0)) then
    local function _71_()
      local function _72_(c, r)
        return c:ui().OnInspect(c, r, nil, nil)
      end
      return vim.b.nvlime_conn("InspectFrameVar", var_num, nth, _72_)
    end
    return vim.b.nvlime_conn("WithThread", thread, _71_)
  else
    local function _73_()
      return sldb["inspect-in-cur-frame-input-complete"](nth, thread)
    end
    return input["from-buffer"](vim.b.nvlime_conn, "Inspect in frame (evaluated):", nil, _73_)
  end
end
sldb["eval-string-in-cur-frame"] = function()
  local nth = sldb["match-frame"]()
  if (nth < 0) then
    nth = 0
  else
  end
  local thread = vim.b.nvlime_conn("GetCurrentThread")
  local cur_package = vim.b.nvlime_conn.GetCurrentPackage()[1]
  local function _76_()
    return sldb["eval-string-in-cur-frame-input-complete"](nth, thread, cur_package)
  end
  return input["from-buffer"](vim.b.nvlime_conn, "Eval in frame:", nil, _76_)
end
sldb["send-value-in-cur-frame-to-repl"] = function()
  local nth = sldb["match-frame"]()
  if (nth < 0) then
    nth = 0
  else
  end
  local thread = vim.b.nvlime_conn("GetCurrentThread")
  local cur_package = vim.b.nvlime_conn.GetCurrentPackage()[1]
  local function _78_()
    return sldb["send-value-in-cur-frame-to-repl-input-complete"](nth, thread, cur_package)
  end
  return input["from-buffer"](vim.b.nvlime_conn, "Eval in frame and send result to REPL:", nil, _78_)
end
sldb["disassemble-cur-frame"] = function()
  local nth = sldb["match-frame"]()
  if (nth < 0) then
    nth = 0
  else
  end
  local thread = vim.b.nvlime_conn("GetCurrentThread")
  local function _80_()
    local function _81_(_c, r)
      return luaeval("require(\"nvlime.window.disassembly\").open(_A)", r)
    end
    return vim.b.nvlime_conn("SLDBDisassemble", nth, _81_)
  end
  return vim.b.nvlime_conn("WithThread", thread, _80_)
end
sldb["return-from-cur-frame"] = function()
  local nth = sldb["match-frame"]()
  if (nth < 0) then
    nth = 0
  else
  end
  local thread = vim.b.nvlime_conn("GetCurrentThread")
  local function _83_()
    return sldb["return-from-cur-frame-input-complete"](nth, thread)
  end
  return input["from-buffer"](vim.b.nvlime_conn, "Return from frame (evaluated):", nil, _83_)
end
local function _84_(self, key)
  return self[string.gsub(key, "_", "-")]
end
setmetatable(sldb, {__index = _84_})
return sldb
