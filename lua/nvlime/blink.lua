local blink_types = require("blink.cmp.types")
local buffer = require("nvlime.buffer")
local opts = require("nvlime.config")
local has_fuzzy_3f = false
for _, v in ipairs(opts.contribs) do
  if ("SWANK-FUZZY" == v) then
    has_fuzzy_3f = true
  else
  end
end
local _2bfuzzy_3f_2b = has_fuzzy_3f
local _2_
if _2bfuzzy_3f_2b then
  _2_ = "yes"
else
  _2_ = "no"
end
vim.notify(("nvlime blink: MODULE LOADED, fuzzy=" .. _2_), vim.log.levels.WARN)
local flag_kind = {b = blink_types.CompletionItemKind.Variable, f = blink_types.CompletionItemKind.Function, g = blink_types.CompletionItemKind.Method, c = blink_types.CompletionItemKind.Class, t = blink_types.CompletionItemKind.Class, m = blink_types.CompletionItemKind.Operator, s = blink_types.CompletionItemKind.Operator, p = blink_types.CompletionItemKind.Module}
local kind_precedence = {blink_types.CompletionItemKind.Module, blink_types.CompletionItemKind.Class, blink_types.CompletionItemKind.Operator, blink_types.CompletionItemKind.Method, blink_types.CompletionItemKind.Function, blink_types.CompletionItemKind.Variable}
local function flags__3ekind(flags)
  if (flags and (#flags > 0)) then
    local kinds = {}
    for i = 1, #flags do
      local kind = flag_kind[flags:sub(i, i)]
      if kind then
        kinds[kind] = true
      else
      end
    end
    local result = nil
    for _, kind in ipairs(kind_precedence) do
      if result then break end
      if kinds[kind] then
        result = kind
      else
        result = result
      end
    end
    return result
  else
    return nil
  end
end
local function set_documentation(conn, item, callback)
  local function _7_(_self, doc_string)
    item["documentation"] = {kind = "markdown", value = string.gsub(doc_string, "^Documentation for the symbol.-\n\n", "", 1)}
    return callback(item)
  end
  return conn["documentation-symbol"](conn, item.label, _7_)
end
local get_lsp_kind
if _2bfuzzy_3f_2b then
  local function _8_(item)
    local flags = item[4]
    return {label = item[1], labelDetails = {detail = flags}, kind = (flags__3ekind(flags) or blink_types.CompletionItemKind.Keyword)}
  end
  get_lsp_kind = _8_
else
  local function _9_(item)
    return {label = item}
  end
  get_lsp_kind = _9_
end
local Source = {}
Source["__index"] = Source
Source.new = function(_, opts0)
  vim.notify("nvlime blink: Source.new() called", vim.log.levels.WARN)
  local self = setmetatable({}, Source)
  self["opts"] = (opts0 or {})
  return self
end
Source.enabled = function(self)
  local conn = buffer["get-conn-var!"](0)
  local _11_
  if not (conn == nil) then
    _11_ = "yes"
  else
    _11_ = "no"
  end
  vim.notify(("nvlime blink: enabled() - conn_type=" .. type(conn) .. " has_conn=" .. _11_), vim.log.levels.WARN)
  return not (conn == nil)
end
Source.get_trigger_characters = function(self)
  return {}
end
Source.get_completions = function(self, ctx, callback)
  vim.notify("nvlime blink: get_completions() ENTERED", vim.log.levels.WARN)
  local called = false
  do
    local cursor_line = ctx.cursor[1]
    local cursor_col = ctx.cursor[2]
    local keyword = (ctx:get_keyword() or "")
    local start_col = (cursor_col - #keyword)
    local conn = buffer["get-conn-var!"](0)
    vim.notify(("nvlime blink: conn_type=" .. type(conn) .. " keyword=\"" .. keyword .. "\" start_col=" .. start_col), vim.log.levels.WARN)
    if conn then
      local completion_fn = ((_2bfuzzy_3f_2b and conn["fuzzy-completions"]) or conn["simple-completions"])
      local _13_
      if _2bfuzzy_3f_2b then
        _13_ = "yes"
      else
        _13_ = "no"
      end
      vim.notify(("nvlime blink: completion_fn_type=" .. type(completion_fn) .. " fuzzy=" .. _13_), vim.log.levels.WARN)
      local on_done
      local function _15_(_self, candidates)
        local _16_
        if called then
          _16_ = "yes"
        else
          _16_ = "no"
        end
        vim.notify(("nvlime blink: on-done CALLED! type=" .. type(candidates) .. " len=" .. (#candidates or "nil") .. " called=" .. _16_), vim.log.levels.WARN)
        if not called then
          called = true
          local raw_items
          local _18_
          if _2bfuzzy_3f_2b then
            _18_ = vim.list_slice(candidates, 2)
          else
            _18_ = candidates
          end
          raw_items = (_18_ or {})
          vim.notify(("nvlime blink: raw_items_len=" .. #raw_items), vim.log.levels.WARN)
          local items
          do
            local tbl_26_ = {}
            local i_27_ = 0
            for _, c in ipairs(raw_items) do
              local val_28_
              do
                local item = get_lsp_kind(c)
                if item then
                  item["textEdit"] = {newText = item.label, range = {start = {line = (cursor_line - 1), character = start_col}, ["end"] = {line = (cursor_line - 1), character = cursor_col}}}
                  val_28_ = item
                else
                  val_28_ = nil
                end
              end
              if (nil ~= val_28_) then
                i_27_ = (i_27_ + 1)
                tbl_26_[i_27_] = val_28_
              else
              end
            end
            items = tbl_26_
          end
          vim.notify(("nvlime blink: CALLBACK with " .. #items .. " items"), vim.log.levels.WARN)
          return callback({items = items, is_incomplete_backward = false, is_incomplete_forward = false})
        else
          return nil
        end
      end
      on_done = _15_
      completion_fn(conn, keyword, on_done)
    else
    end
  end
  return nil
end
Source.resolve = function(self, item, callback)
  local conn = buffer["get-conn-var!"](0)
  return set_documentation(conn, vim.deepcopy(item), callback)
end
Source["flags->kind"] = flags__3ekind
return Source
