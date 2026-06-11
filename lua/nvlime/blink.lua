local blink_types = require("blink.cmp.types")
local buffer = require("nvlime.buffer")
local opts = require("nvlime.config")
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
local fuzzy_disabled_3f = false
local FUZZY_TIMEOUT = 5000
local function server_has_fuzzy_3f(conn)
  local contribs = conn.cb_data.contribs
  return (contribs and (vim.fn.index(contribs, "SWANK-FUZZY") >= 0))
end
local flag_kind = {b = blink_types.CompletionItemKind.Variable, f = blink_types.CompletionItemKind.Function, g = blink_types.CompletionItemKind.Method, c = blink_types.CompletionItemKind.Class, t = blink_types.CompletionItemKind.Class, m = blink_types.CompletionItemKind.Operator, s = blink_types.CompletionItemKind.Operator, p = blink_types.CompletionItemKind.Module}
local kind_precedence = {blink_types.CompletionItemKind.Module, blink_types.CompletionItemKind.Class, blink_types.CompletionItemKind.Operator, blink_types.CompletionItemKind.Method, blink_types.CompletionItemKind.Function, blink_types.CompletionItemKind.Variable}
local function flags__3ekind(flags)
  if ((type(flags) == "string") and (#flags > 0)) then
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
  local function _5_(_self, doc_string)
    item["documentation"] = {kind = "markdown", value = string.gsub(doc_string, "^Documentation for the symbol.-\n\n", "", 1)}
    return callback(item)
  end
  return conn["documentation-symbol"](conn, item.label, _5_)
end
local function get_lsp_kind(use_fuzzy_3f, item)
  if use_fuzzy_3f then
    local flags = item[3]
    return {label = item[1], labelDetails = {detail = flags}, kind = (flags__3ekind(flags) or blink_types.CompletionItemKind.Keyword)}
  else
    return {label = item}
  end
end
local Source = {}
Source["__index"] = Source
Source.new = function(_, opts0)
  local self = setmetatable({}, Source)
  self["opts"] = (opts0 or {})
  return self
end
Source.enabled = function(self)
  return ((vim.bo.filetype == "lisp") and buffer["get-conn-var!"](0))
end
Source.get_trigger_characters = function(self)
  return {}
end
Source.get_completions = function(self, ctx, callback)
  local called = false
  local handling_complete = false
  do
    local cursor_line = ctx.cursor[1]
    local cursor_col = ctx.cursor[2]
    local keyword = (ctx:get_keyword() or "")
    local start_col = (cursor_col - #keyword)
    local conn = buffer["get-conn-var!"](0)
    if conn then
      local use_fuzzy_3f = (_2bfuzzy_3f_2b and server_has_fuzzy_3f(conn) and not fuzzy_disabled_3f)
      local process_candidates
      local function _7_(candidates, is_fuzzy)
        if not handling_complete then
          handling_complete = true
          called = true
          local raw_items
          local _8_
          if is_fuzzy then
            _8_ = candidates[1]
          else
            _8_ = vim.list_slice(candidates, 2)
          end
          raw_items = (_8_ or {})
          local items
          do
            local tbl_26_ = {}
            local i_27_ = 0
            for _, c in ipairs(raw_items) do
              local val_28_
              do
                local item = get_lsp_kind(is_fuzzy, c)
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
          return callback({items = items, is_incomplete_backward = false, is_incomplete_forward = false})
        else
          return nil
        end
      end
      process_candidates = _7_
      if use_fuzzy_3f then
        local function _13_(_self, candidates)
          return process_candidates(candidates, true)
        end
        connection["fuzzy-completions"](conn, keyword, _13_)
        local function _14_()
          if not handling_complete then
            fuzzy_disabled_3f = true
            vim.notify("nvlime: fuzzy-completions timed out after 5s, falling back to simple-completions", vim.log.levels.WARN)
            local function _15_(_self, candidates)
              return process_candidates(candidates, false)
            end
            return connection["simple-completions"](conn, keyword, _15_)
          else
            return nil
          end
        end
        vim.defer_fn(_14_, FUZZY_TIMEOUT)
      else
        local function _17_(_self, candidates)
          return process_candidates(candidates, false)
        end
        connection["simple-completions"](conn, keyword, _17_)
      end
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
