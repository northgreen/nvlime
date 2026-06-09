local blink_types = require("blink.cmp.types")
local buffer = require("nvlime.buffer")
local opts = require("nvlime.config")
local psl = require("parsley")
local _2bfuzzy_3f_2b
local function _1_(_241)
  return ("SWANK-FUZZY" == _241)
end
_2bfuzzy_3f_2b = not psl["empty?"](psl.filter(_1_, opts.contribs))
local flag_kind = {b = blink_types.CompletionItemKind.Variable, f = blink_types.CompletionItemKind.Function, g = blink_types.CompletionItemKind.Method, c = blink_types.CompletionItemKind.Class, t = blink_types.CompletionItemKind.Class, m = blink_types.CompletionItemKind.Operator, s = blink_types.CompletionItemKind.Operator, p = blink_types.CompletionItemKind.Module}
local kind_precedence = {blink_types.CompletionItemKind.Module, blink_types.CompletionItemKind.Class, blink_types.CompletionItemKind.Operator, blink_types.CompletionItemKind.Method, blink_types.CompletionItemKind.Function, blink_types.CompletionItemKind.Variable}
local function flags__3ekind(flags)
  local kinds = {}
  for i = 1, #flags do
    local kind = flag_kind[flags:sub(i, i)]
    if kind then
      kinds[kind] = true
    end
  end
  for _, kind in ipairs(kind_precedence) do
    if kinds[kind] then
      return kind
    end
  end
  return nil
end
local function set_documentation(item, callback)
  local get_documentation = vim.fn["nvlime#cmp#get_docs"]
  local function _4_(_241)
    item.documentation = {kind = "markdown", value = string.gsub(_241, "^Documentation for the symbol.-\n\n", "", 1)}
    return callback(item)
  end
  return get_documentation(item.label, _4_)
end
local get_lsp_kind
if _2bfuzzy_3f_2b then
  local function _5_(item)
    local flags = item[4]
    return {label = psl.first(item), labelDetails = {detail = flags}, kind = (flags__3ekind(flags) or blink_types.CompletionItemKind.Keyword)}
  end
  get_lsp_kind = _5_
else
  local function _6_(_241)
    return {label = _241}
  end
  get_lsp_kind = _6_
end
local get_completion
local _8_
if _2bfuzzy_3f_2b then
  _8_ = "nvlime#cmp#get_fuzzy"
else
  _8_ = "nvlime#cmp#get_simple"
end
get_completion = vim.fn[_8_]
--- @class blink.cmp.Source
local Source = {}
Source.__index = Source

function Source.new(opts)
  local self = setmetatable({}, Source)
  self.opts = opts or {}
  return self
end

function Source:enabled()
  local conn = buffer["get-conn-var!"](0)
  return not psl["null?"](conn)
end

function Source:get_trigger_characters()
  return {":"}
end

function Source:get_completions(ctx, callback)
  local cursor_line = ctx.cursor[1]
  local cursor_col = ctx.cursor[2]
  local keyword = ctx.keyword or ""
  local start_col = cursor_col - #keyword
  local called = false
  local function on_done(candidates)
    if called then
      return
    end
    called = true
    local items = {}
    for _, c in ipairs(candidates or {}) do
      local item = get_lsp_kind(c)
      if item then
        item.textEdit = {newText = item.label, range = {start = {line = cursor_line - 1, character = start_col}, ["end"] = {line = cursor_line - 1, character = cursor_col}}}
        table.insert(items, item)
      else
      end
    end
    return callback({items = items, is_incomplete_backward = false, is_incomplete_forward = false})
  end
  return get_completion(keyword, on_done)
end

function Source:resolve(item, callback)
  item = vim.deepcopy(item)
  set_documentation(item, callback)
end

return Source
