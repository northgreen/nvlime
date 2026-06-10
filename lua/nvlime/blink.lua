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
local function set_documentation(item, callback)
  local get_documentation = vim.fn["nvlime#cmp#get_docs"]
  local function _5_(_241)
    item["documentation"] = {kind = "markdown", value = string.gsub(_241, "^Documentation for the symbol.-\n\n", "", 1)}
    return callback(item)
  end
  return get_documentation(item.label, _5_)
end
local get_lsp_kind
if _2bfuzzy_3f_2b then
  local function _6_(item)
    local flags = item[4]
    return {label = item[1], labelDetails = {detail = flags}, kind = (flags__3ekind(flags) or blink_types.CompletionItemKind.Keyword)}
  end
  get_lsp_kind = _6_
else
  local function _7_(item)
    return {label = item}
  end
  get_lsp_kind = _7_
end
local get_completion
local _9_
if _2bfuzzy_3f_2b then
  _9_ = "nvlime#cmp#get_fuzzy"
else
  _9_ = "nvlime#cmp#get_simple"
end
get_completion = vim.fn[_9_]
local Source = {__index = Source}
Source.new = function(_, opts0)
  local self = setmetatable({}, Source)
  self["opts"] = (opts0 or {})
  return self
end
Source.enabled = function(self)
  local conn = buffer["get-conn-var!"](0)
  return not (conn == nil)
end
Source.get_trigger_characters = function(self)
  return {":"}
end
Source.get_completions = function(self, ctx, callback)
  local called = false
  local cursor_line = ctx.cursor[1]
  local cursor_col = ctx.cursor[2]
  local keyword = (ctx.keyword or "")
  local start_col = (cursor_col - #keyword)
  local on_done
  local function _11_(candidates)
    if not called then
      called = true
      local items = {}
      for _, c in ipairs((candidates or {})) do
        local item = get_lsp_kind(c)
        if item then
          item["textEdit"] = {newText = item.label, range = {start = {line = (cursor_line - 1), character = start_col}, ["end"] = {line = (cursor_line - 1), character = cursor_col}}}
          table.insert(items, item)
        else
        end
      end
    else
    end
    return callback({items = items, is_incomplete_backward = false, is_incomplete_forward = false})
  end
  on_done = _11_
  get_completion(keyword, on_done)
  return nil
end
Source.resolve = function(self, item, callback)
  return set_documentation(vim.deepcopy(item), callback)
end
Source["flags->kind"] = flags__3ekind
return Source
