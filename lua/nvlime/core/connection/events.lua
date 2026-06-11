local connection = require("nvlime.core.connection")
local nvim_buf_set_lines = vim.api.nvim_buf_set_lines
local nvim_err_writeln = vim.api.nvim_err_writeln
connection["parse-source-location"] = function(self, loc)
  if ((type(loc[1]) ~= "table") or (loc[1].name ~= "LOCATION")) then
    error(("nvlime#ParseSourceLocation: invalid location: " .. vim.inspect(loc)))
  else
  end
  local loc_obj = {}
  do
    for i = 2, #loc do
      local p = loc[i]
      if (type(p) == "table") then
        local key_dict = p[1]
        if key_dict then
          local key = key_dict.name
          local case_2_ = #p
          if (case_2_ == 1) then
            loc_obj[key] = nil
          elseif (case_2_ == 2) then
            loc_obj[key] = p[2]
          else
            local _ = case_2_
            local _3_
            do
              local result = {}
              for j = 3, #p do
                table.insert(result, p[j])
              end
              _3_ = result
            end
            loc_obj[key] = _3_
          end
        else
        end
      else
      end
    end
  end
  return loc_obj
end
connection["get-valid-source-location"] = function(self, loc)
  local loc_file = connection.get(loc, "FILE", nil)
  local loc_buffer = connection.get(loc, "BUFFER", nil)
  local loc_buf_and_file = connection.get(loc, "BUFFER-AND-FILE", nil)
  local loc_src_form = connection.get(loc, "SOURCE-FORM", nil)
  local _7_
  do
    local loc_pos = connection.get(loc, "POSITION", nil)
    local loc_snippet = connection.get(loc, "SNIPPET", nil)
    _7_ = {loc_file, loc_pos, loc_snippet}
  end
  local _8_
  do
    local loc_offset = connection.get(loc, "OFFSET", nil)
    local loc_snippet = connection.get(loc, "SNIPPET", nil)
    local loc_offset0
    if loc_offset then
      local a = loc_offset[1]
      local b = loc_offset[2]
      if ((a < 0) or (b < 0)) then
        loc_offset0 = nil
      else
        loc_offset0 = (a + b)
      end
    else
      loc_offset0 = nil
    end
    _8_ = {loc_buffer, loc_offset0, loc_snippet}
  end
  local _11_
  do
    local loc_offset = connection.get(loc, "OFFSET", nil)
    local loc_snippet = connection.get(loc, "SNIPPET", nil)
    local loc_offset0
    if loc_offset then
      local a = loc_offset[1]
      local b = loc_offset[2]
      if ((a < 0) or (b < 0)) then
        loc_offset0 = nil
      else
        loc_offset0 = (a + b)
      end
    else
      loc_offset0 = nil
    end
    _11_ = {(loc_buf_and_file[1] or nil), loc_offset0, loc_snippet}
  end
  return cond(loc_file, _7_, loc_buffer, _8_, loc_buf_and_file, _11_, loc_src_form, {nil, 1, loc_src_form}, "else", {})
end
connection["read-raw-form-string"] = function(self, expr, mark)
  if (expr[1] == mark) then
    local function _17_()
      if (idx < #expr) then
        local ch = expr[idx]
        if (ch == "\\") then
          local next_idx = (idx + 1)
          if (next_idx < #expr) then
            return recur(next_idx, (__fnl_global__str_2dchars .. expr[next_idx]))
          else
            return error("ReadRawFormString: early eof")
          end
        else
          if (ch == mark) then
            return {__fnl_global__str_2dchars, (idx + 1)}
          else
            return recur((idx + 1), (__fnl_global__str_2dchars .. ch))
          end
        end
      else
        return error("ReadRawFormString: unterminated string")
      end
    end
    return loop({idx, 2, __fnl_global__str_2dchars, {}}, _17_())
  else
    return {"", 0}
  end
end
connection["read-raw-form-sharp"] = function(self, expr)
  if (expr[1] == "#") then
    if (#expr <= 1) then
      return {expr, #expr}
    else
      local ch2 = expr[2]
      local _19_
      if (#expr < 3) then
        _19_ = error("ReadRawFormSharp: early eof")
      else
        _19_ = {("#" .. "\\" .. expr[3]), 3}
      end
      return cond((ch2 == "("), {"", 1}, (ch2 == "\\"), _19_, (ch2 == "."), {"", 2}, vim.fn.match(ch2, "\\_s"), {expr[1], 1}, "else", {("#" .. ch2), 2})
    end
  else
    return {"", 0}
  end
end
connection["read-raw-form-semicolon"] = function(self, expr)
  if (expr[1] == ";") then
    local function _23_()
      if ((idx <= #expr) and (expr[idx] ~= "\n")) then
        return recur((idx + 1))
      else
        return (idx + 1)
      end
    end
    return loop({idx, 2}, _23_())
  else
    return 0
  end
end
connection["to-raw-form"] = function(self, expr)
  local form = {}
  local paren_level = 0
  local idx = 1
  local cur_token = ""
  while (idx <= #expr) do
    local delta = 1
    local ch = expr[idx]
    paren_level = (paren_level + 1)
    paren_level = (paren_level - 1)
    local _25_
    do
      local result
      local function _26_()
        return {self["read-raw-form-string"](self, string.sub(expr, idx), ch)}
      end
      result = pcall(_26_)
      if result[1] then
        local _let_28_ = result[2]
        local str = _let_28_[1]
        local read_delta = _let_28_[2]
        local escaped = string.gsub(string.gsub(str, "\\", "\\\\"), ch, ("\\" .. ch))
        cur_token = (cur_token .. ch .. escaped .. ch)
        delta = read_delta
        _25_ = nil
      else
        delta = (#expr - idx)
        _25_ = nil
      end
    end
    local _31_
    do
      local result
      local function _32_()
        return {self["read-raw-form-sharp"](self, string.sub(expr, idx))}
      end
      result = pcall(_32_)
      if result[1] then
        local _let_34_ = result[2]
        local str = _let_34_[1]
        local read_delta = _let_34_[2]
        cur_token = (cur_token .. str)
        delta = read_delta
        _31_ = nil
      else
        delta = (#expr - idx)
        _31_ = nil
      end
    end
    local _36_
    if (((idx + 1) < #expr) and (expr[(idx + 1)] ~= "(")) then
      cur_token = (cur_token .. ch)
      _36_ = nil
    else
      _36_ = nil
    end
    local _38_
    if ((idx + 1) < #expr) then
      cur_token = (cur_token .. expr[idx] .. expr[(idx + 1)])
      delta = 2
      _38_ = nil
    else
      delta = (#expr - (idx + 1))
      _38_ = nil
    end
    delta = self["read-raw-form-semicolon"](self, string.sub(expr, idx))
    cur_token = (cur_token .. ch)
    cond((ch == "("), nil, (ch == ")"), nil, vim.fn.match(ch, "\\_s"), nil, ((ch == "\"") or (ch == "|")), _25_, (ch == "#"), _31_, ((ch == "'") or (ch == "`") or (ch == ",")), _36_, (ch == "\\"), _38_, (ch == ";"), nil, "else", nil)
    if (((ch == "(") or (ch == ")") or vim.fn.match(ch, "\\_s") or (ch == ";")) and (#cur_token > 0)) then
      table.insert(form, cur_token)
      cur_token = ""
    else
    end
    if (paren_level > 1) then
      local sub_form, sub_delta, sub_complete = self["to-raw-form"](self, string.sub(expr, idx))
      table.insert(form, sub_form)
      paren_level = (paren_level - 1)
      delta = sub_delta
    else
      if (paren_level <= 0) then
        do local _ = {form, (idx + 1), true} end
      else
      end
    end
    idx = (idx + delta)
  end
  if (paren_level == 0) then
    table.insert(form, "")
    table.insert(form, connection.sym(self, "SWANK", "%CURSOR-MARKER%"))
  else
  end
  return {form, #expr, (paren_level == 0)}
end
connection.memoize = function(self, func, key, cache, scope, cache_limit)
  local cache_table = scope[cache]
  local cache_table0
  if cache_table then
    cache_table0 = cache_table
  else
    cache_table0 = {}
  end
  local case_45_, case_46_
  local function _47_()
    return cache_table0[key]
  end
  case_45_, case_46_ = pcall(_47_)
  if ((case_45_ == true) and (nil ~= case_46_)) then
    local result = case_46_
    return result
  else
    local _ = case_45_
    local new_result = func()
    local cache_limit0 = (cache_limit or nil)
    if (cache_limit0 and (cache_limit0 > 0) and (#cache_table0 >= cache_limit0)) then
      local keys = keys(cache_table0)
      while (#keys >= cache_limit0) do
        local raw_idx = (self:rand() % #keys)
        local idx
        if (raw_idx == 0) then
          idx = 1
        else
          idx = raw_idx
        end
        local rm_key = keys[idx]
        cache_table0[rm_key] = nil
        table.remove(keys, idx)
      end
    else
    end
    cache_table0[key] = new_result
    scope[cache] = cache_table0
    return new_result
  end
end
connection.rand = function(self)
  return (math.random(99998) + 1)
end
connection["keyword-list-2-dict"] = function(self, input)
  if (type(input) == "table") then
    local dct = {}
    for _, el in ipairs(input) do
      if ((type(el) == "table") and (type(el[1]) == "table")) then
        local package = el[1].package
        if ((package == "KEYWORD") or (package == "keyword")) then
          dct[el[1].name] = el[2]
        else
        end
      else
      end
    end
    return dct
  else
    return nil
  end
end
connection["clear-current-buffer"] = function(self)
  return nvim_buf_set_lines(0, 0, -1, false, {})
end
connection["dummy-cb"] = function(self, result)
  print("---------------------------")
  return print(vim.inspect(result))
end
connection["on-ping"] = function(self, msg)
  local thread = msg[2]
  local ttag = msg[3]
  return self:pong(thread, ttag)
end
connection["on-new-package"] = function(self, msg)
  return self["set-current-package"](self, {(msg[1] or nil), (msg[2] or nil)})
end
connection["on-debug"] = function(self, msg)
  if self.ui then
    local thread = msg[2]
    local level = msg[3]
    local condition = msg[4]
    local restarts = msg[5]
    local frames = msg[6]
    local conts = msg[7]
    return self.ui["on-debug"](self.ui, self, thread, level, condition, restarts, frames, conts)
  else
    return nil
  end
end
connection["on-debug-activate"] = function(self, msg)
  if self.ui then
    local thread = msg[2]
    local level = msg[3]
    local select
    if (#msg == 4) then
      select = msg[4]
    else
      select = nil
    end
    return self.ui["on-debug-activate"](self.ui, self, thread, level, select)
  else
    return nil
  end
end
connection["on-debug-return"] = function(self, msg)
  if self.ui then
    local thread = msg[2]
    local level = msg[3]
    local stepping = msg[4]
    return self.ui["on-debug-return"](self.ui, self, thread, level, stepping)
  else
    return nil
  end
end
connection["on-write-string"] = function(self, msg)
  if self.ui then
    local str = msg[2]
    local str_type
    if (#msg >= 3) then
      str_type = msg[3]
    else
      str_type = nil
    end
    local thread
    if (#msg >= 4) then
      thread = msg[4]
    else
      thread = nil
    end
    return self.ui["on-write-string"](self.ui, self, str, str_type, thread)
  else
    return nil
  end
end
connection["on-read-string"] = function(self, msg)
  if self.ui then
    local thread = msg[2]
    local ttag = msg[3]
    return self.ui["on-read-string"](self.ui, self, thread, ttag)
  else
    return nil
  end
end
connection["on-read-from-minibuffer"] = function(self, msg)
  if self.ui then
    local thread = msg[2]
    local ttag = msg[3]
    local prompt = msg[4]
    local init_val = msg[5]
    return self.ui["on-read-from-minibuffer"](self.ui, self, thread, ttag, prompt, init_val)
  else
    return nil
  end
end
connection["on-indentation-update"] = function(self, msg)
  if self.ui then
    local indent_info = msg[2]
    return self.ui["on-indentation-update"](self.ui, self, indent_info)
  else
    return nil
  end
end
connection["on-new-features"] = function(self, msg)
  if self.ui then
    local new_features = msg[2]
    return self.ui["on-new-features"](self.ui, self, new_features)
  else
    return nil
  end
end
connection["on-invalid-rpc"] = function(self, msg)
  if self.ui then
    local id = msg[2]
    local err_msg = msg[3]
    return self.ui["on-invalid-rpc"](self.ui, self, id, err_msg)
  else
    return nil
  end
end
connection["on-inspect"] = function(self, msg)
  if self.ui then
    local i_content = msg[2]
    local i_thread = msg[3]
    local i_tag = msg[4]
    return self.ui["on-inspect"](self.ui, self, i_content, i_thread, i_tag)
  else
    return nil
  end
end
connection["on-channel-send"] = function(self, msg)
  local chan_id = msg[2]
  local msg_body = msg[3]
  local chan_obj = self.local_channels[chan_id]
  if chan_obj then
    if chan_obj.callback then
      return chan_obj.callback(self, chan_obj, msg_body)
    else
      if (vim.g._nvlime_debug or false) then
        return print(("Unhandled message: " .. vim.inspect(msg)))
      else
        return nil
      end
    end
  else
    if (vim.g._nvlime_debug or false) then
      return print(("Unknown channel: " .. vim.inspect(msg)))
    else
      return nil
    end
  end
end
connection.setup_event_handlers = function(self)
  local function _71_(self0, msg)
    return self0["on-ping"](self0, msg)
  end
  local function _72_(self0, msg)
    return self0["on-new-package"](self0, msg)
  end
  local function _73_(self0, msg)
    return self0["on-debug"](self0, msg)
  end
  local function _74_(self0, msg)
    return self0["on-debug-activate"](self0, msg)
  end
  local function _75_(self0, msg)
    return self0["on-debug-return"](self0, msg)
  end
  local function _76_(self0, msg)
    return self0["on-write-string"](self0, msg)
  end
  local function _77_(self0, msg)
    return self0["on-read-string"](self0, msg)
  end
  local function _78_(self0, msg)
    return self0["on-read-from-minibuffer"](self0, msg)
  end
  local function _79_(self0, msg)
    return self0["on-indentation-update"](self0, msg)
  end
  local function _80_(self0, msg)
    return self0["on-new-features"](self0, msg)
  end
  local function _81_(self0, msg)
    return self0["on-invalid-rpc"](self0, msg)
  end
  local function _82_(self0, msg)
    return self0["on-inspect"](self0, msg)
  end
  local function _83_(self0, msg)
    return self0["on-channel-send"](self0, msg)
  end
  self.server_event_handlers = {PING = _71_, ["NEW-PACKAGE"] = _72_, DEBUG = _73_, ["DEBUG-ACTIVATE"] = _74_, ["DEBUG-RETURN"] = _75_, ["WRITE-STRING"] = _76_, ["READ-STRING"] = _77_, ["READ-FROM-MINIBUFFER"] = _78_, ["INDENTATION-UPDATE"] = _79_, ["NEW-FEATURES"] = _80_, ["INVALID-RPC"] = _81_, INSPECT = _82_, ["CHANNEL-SEND"] = _83_}
  return nil
end
return connection
