local lsp_types = require("cmp.types.lsp")
local buffer = require("nvlime.buffer")
local opts = require("nvlime.config")
require("cmp.types.cmp")

-- Check if SWANK-FUZZY is in contribs
local fuzzy_QMARK = false
for _, v in ipairs(opts.contribs) do
  if v == "SWANK-FUZZY" then
    fuzzy_QMARK = true
    break
  end
end

local flag_kind = {
  b = lsp_types.CompletionItemKind.Variable,
  f = lsp_types.CompletionItemKind.Function,
  g = lsp_types.CompletionItemKind.Method,
  c = lsp_types.CompletionItemKind.Class,
  t = lsp_types.CompletionItemKind.Class,
  m = lsp_types.CompletionItemKind.Operator,
  s = lsp_types.CompletionItemKind.Operator,
  p = lsp_types.CompletionItemKind.Module
}

local kind_precedence = {
  lsp_types.CompletionItemKind.Module,
  lsp_types.CompletionItemKind.Class,
  lsp_types.CompletionItemKind.Operator,
  lsp_types.CompletionItemKind.Method,
  lsp_types.CompletionItemKind.Function,
  lsp_types.CompletionItemKind.Variable
}

--- @param flags string
--- @return number|nil
local function flags_to_kind(flags)
  local kinds = {}
  for i = 1, #flags do
    local kind = flag_kind[flags:sub(i, i)]
    if kind then
      kinds[kind] = true
    end
  end
  for i = 1, #kind_precedence do
    if kinds[kind_precedence[i]] then
      return kind_precedence[i]
    end
  end
  return nil
end

--- @param item table
local function set_documentation(item)
  local get_documentation = vim.fn["nvlime#cmp#get_docs"]
  get_documentation(item.label, function(doc)
    item.documentation = {
      kind = "markdown",
      value = string.gsub(doc, "^Documentation for the symbol.-\n\n", "", 1)
    }
  end)
end

local get_lsp_kind
if fuzzy_QMARK then
  get_lsp_kind = function(item)
    local flags = item[4]
    return {
      label = item[1],
      labelDetails = {detail = flags},
      kind = flags_to_kind(flags) or lsp_types.CompletionItemKind.Keyword
    }
  end
else
  get_lsp_kind = function(item)
    return {label = item}
  end
end

local get_completion = vim.fn[fuzzy_QMARK and "nvlime#cmp#get_fuzzy" or "nvlime#cmp#get_simple"]

local source = {}

function source.is_available(self)
  return buffer["get-conn-var!"](0) ~= nil
end

function source.get_debug_name(self)
  return "CMP Nvlime"
end

function source.get_keyword_pattern(self)
  return "\\k\\+"
end

function source.complete(self, params, callback)
  local on_done = function(candidates)
    callback(vim.tbl_map(get_lsp_kind, candidates or {}))
  end
  local input = string.sub(params.context.cursor_before_line, params.offset)
  get_completion(input, on_done)
end

function source.resolve(self, item, callback)
  set_documentation(item)
  vim.defer_fn(function()
    callback(item)
  end, 5)
end

return source
