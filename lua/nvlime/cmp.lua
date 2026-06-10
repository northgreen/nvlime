local lsp_types = require("cmp.types.lsp")
local buffer = require("nvlime.buffer")
local opts = require("nvlime.config")
require("cmp.types.cmp")
local has_fuzzy_3f = false
for _, v in ipairs(opts.contribs) do
  if ("SWANK-FUZZY" == v) then
    has_fuzzy_3f = true
  else
  end
end
local _2bfuzzy_3f_2b = has_fuzzy_3f
local flag_kind = {b = lsp_types.CompletionItemKind.Variable, f = lsp_types.CompletionItemKind.Function, g = lsp_types.CompletionItemKind.Method, c = lsp_types.CompletionItemKind.Class, t = lsp_types.CompletionItemKind.Class, m = lsp_types.CompletionItemKind.Operator, s = lsp_types.CompletionItemKind.Operator, p = lsp_types.CompletionItemKind.Module}
local kind_precedence = {lsp_types.CompletionItemKind.Module, lsp_types.CompletionItemKind.Class, lsp_types.CompletionItemKind.Operator, lsp_types.CompletionItemKind.Method, lsp_types.CompletionItemKind.Function, lsp_types.CompletionItemKind.Variable}
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
local function set_documentation(item)
  local get_documentation = vim.fn["nvlime#cmp#get_docs"]
  local function _5_(_241)
    item["documentation"] = string.gsub(_241, "^Documentation for the symbol.-\n\n", "", 1)
    return nil
  end
  return get_documentation(item.label, _5_)
end
local get_lsp_kind
if _2bfuzzy_3f_2b then
  local function _6_(item)
    local flags = item[4]
    return {label = item[1], labelDetails = {detail = flags}, kind = (flags__3ekind(flags) or lsp_types.CompletionItemKind.Keyword)}
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
local source = {}
source.is_available = function(self)
  return not (buffer["get-conn-var!"](0) == nil)
end
source.get_debug_name = function(self)
  return "CMP Nvlime"
end
source.get_keyword_pattern = function(self)
  return "\\k\\+"
end
source.complete = function(self, params, callback)
  local called = false
  local on_done
  local function _11_(candidates)
    if not called then
      called = true
      local function _12_()
        local tbl_26_ = {}
        local i_27_ = 0
        for _, c in ipairs((candidates[1] or {})) do
          local val_28_ = get_lsp_kind(c)
          if (nil ~= val_28_) then
            i_27_ = (i_27_ + 1)
            tbl_26_[i_27_] = val_28_
          else
          end
        end
        return tbl_26_
      end
      return callback(_12_())
    else
      return nil
    end
  end
  on_done = _11_
  local input = string.sub(params.context.cursor_before_line, params.offset)
  return get_completion(input, on_done)
end
source.resolve = function(self, item, callback)
  set_documentation(vim.deepcopy(item))
  local function _15_()
    return callback(item)
  end
  return vim.defer_fn(_15_, 5)
end
return source
