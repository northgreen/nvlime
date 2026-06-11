local lsp_types = require("cmp.types.lsp")
local buffer = require("nvlime.buffer")
local opts = require("nvlime.config")
require("cmp.types.cmp")
require("nvlime.core.connection.swank")
require("nvlime.core.contrib.fuzzy")
local connection = require("nvlime.core.connection")
local has_fuzzy_3f = false
for _, v in ipairs(opts.contribs) do
  if ("SWANK-FUZZY" == v) then
    has_fuzzy_3f = true
  else
  end
end
local _2bfuzzy_3f_2b = has_fuzzy_3f
local function server_has_fuzzy_3f(conn)
  local contribs = conn.cb_data.contribs
  return (contribs and (vim.fn.index(contribs, "SWANK-FUZZY") >= 0))
end
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
local function set_documentation(conn, item)
  local function _5_(_self, doc_string)
    item["documentation"] = string.gsub(doc_string, "^Documentation for the symbol.-\n\n", "", 1)
    return nil
  end
  return conn["documentation-symbol"](conn, item.label, _5_)
end
local function get_lsp_kind(use_fuzzy_3f, item)
  if use_fuzzy_3f then
    local flags = item[4]
    return {label = item[1], labelDetails = {detail = flags}, kind = (flags__3ekind(flags) or lsp_types.CompletionItemKind.Keyword)}
  else
    return {label = item}
  end
end
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
  local conn = buffer["get-conn-var!"](0)
  if conn then
    local use_fuzzy_3f = (_2bfuzzy_3f_2b and server_has_fuzzy_3f(conn))
    local completion_fn
    if use_fuzzy_3f then
      completion_fn = connection["fuzzy-completions"]
    else
      completion_fn = connection["simple-completions"]
    end
    local on_done
    local function _8_(_self, candidates)
      if not called then
        called = true
        local function _9_()
          local tbl_26_ = {}
          local i_27_ = 0
          local _10_
          if use_fuzzy_3f then
            _10_ = candidates[1]
          else
            _10_ = vim.list_slice(candidates, 2)
          end
          for _, c in ipairs((_10_ or {})) do
            local val_28_ = get_lsp_kind(use_fuzzy_3f, c)
            if (nil ~= val_28_) then
              i_27_ = (i_27_ + 1)
              tbl_26_[i_27_] = val_28_
            else
            end
          end
          return tbl_26_
        end
        return callback(_9_())
      else
        return nil
      end
    end
    on_done = _8_
    local input = string.sub(params.context.cursor_before_line, params.offset)
    return completion_fn(conn, input, on_done)
  else
    return nil
  end
end
source.resolve = function(self, item, callback)
  local conn = buffer["get-conn-var!"](0)
  local function _15_(_self, doc_string)
    item["documentation"] = string.gsub(doc_string, "^Documentation for the symbol.-\n\n", "", 1)
    return callback(item)
  end
  return conn["documentation-symbol"](conn, item.label, _15_)
end
source["flags->kind"] = flags__3ekind
return source
