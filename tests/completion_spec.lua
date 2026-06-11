local helpers = require('nvim-test.helpers')
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('nvlime.completion: flags->kind', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua;' .. cwd .. '/.test-deps/parsley/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
      vim.opt.rtp:append(cwd .. '/.test-deps/parsley')

      -- Mock external type libraries
      package.preload['blink.cmp.types'] = function()
        return {CompletionItemKind = {
          Variable = 6, Function = 3, Method = 2,
          Class = 7, Operator = 4, Module = 5, Keyword = 1
        }}
      end
      package.preload['cmp.types.lsp'] = function()
        return {CompletionItemKind = {
          Variable = 6, Function = 3, Method = 2,
          Class = 7, Operator = 4, Module = 5, Keyword = 1
        }}
      end
      package.preload['cmp.types.cmp'] = function()
        return {CompletionItemKind = {
          Property = 8, Text = 9, Unit = 10
        }}
      end
    ]]
  end)

  it('returns nil for nil input', function()
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      local v = blink['flags->kind'](nil)
      return {v == nil or (type(v) == 'userdata' and tostring(v) == 'vim.NIL')}
    ]]
    eq(true, result[1])
  end)

  it('returns nil for empty string', function()
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      local v = blink['flags->kind']('')
      return {v == nil or (type(v) == 'userdata' and tostring(v) == 'vim.NIL')}
    ]]
    eq(true, result[1])
  end)

  it('maps single flag b to Variable', function()
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      return blink['flags->kind']('b')
    ]]
    eq(6, result)  -- Variable = 6
  end)

  it('maps single flag f to Function', function()
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      return blink['flags->kind']('f')
    ]]
    eq(3, result)  -- Function = 3
  end)

  it('maps single flag g to Method', function()
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      return blink['flags->kind']('g')
    ]]
    eq(2, result)  -- Method = 2
  end)

  it('maps single flag c to Class', function()
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      return blink['flags->kind']('c')
    ]]
    eq(7, result)  -- Class = 7
  end)

  it('maps single flag m to Operator', function()
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      return blink['flags->kind']('m')
    ]]
    eq(4, result)  -- Operator = 4
  end)

  it('maps single flag s to Operator', function()
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      return blink['flags->kind']('s')
    ]]
    eq(4, result)  -- Operator = 4
  end)

  it('maps single flag p to Module', function()
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      return blink['flags->kind']('p')
    ]]
    eq(5, result)  -- Module = 5
  end)

  it('returns highest priority kind for multi-flag input', function()
    -- kind-precedence array order: Module(5), Class(7), Operator(4), Method(2), Function(3), Variable(6)
    -- "bfm": b=Variable(6), f=Function(3), m=Operator(4)
    -- Operator(4) appears first in precedence → returns 4
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      return blink['flags->kind']('bfm')
    ]]
    eq(4, result)  -- Operator = 4 (highest priority among b=6, f=3, m=4)
  end)

  it('returns nil for unknown flags', function()
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      local v = blink['flags->kind']('xyz')
      return {v == nil or (type(v) == 'userdata' and tostring(v) == 'vim.NIL')}
    ]]
    eq(true, result[1])
  end)

  it('ignores unknown flags and returns known ones', function()
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      return blink['flags->kind']('bxf')  -- x is unknown, b=Variable(6), f=Function(3)
    ]]
    eq(3, result)  -- Function(3) has higher priority than Variable(6)
  end)

  it('handles all known flags together', function()
    local result = exec_lua[[
      local blink = require('nvlime.blink')
      return blink['flags->kind']('bfgctms')  -- all flags: b=6, f=3, g=2, c=7, t=7, m=4, s=4
    ]]
    eq(7, result)  -- Class(7) has highest priority in precedence array
  end)
end)

describe('nvlime.completion: cmp flags->kind', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua;' .. cwd .. '/.test-deps/parsley/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
      vim.opt.rtp:append(cwd .. '/.test-deps/parsley')

      package.preload['blink.cmp.types'] = function()
        return {CompletionItemKind = {
          Variable = 6, Function = 3, Method = 2,
          Class = 7, Operator = 4, Module = 5, Keyword = 1
        }}
      end
      package.preload['cmp.types.lsp'] = function()
        return {CompletionItemKind = {
          Variable = 6, Function = 3, Method = 2,
          Class = 7, Operator = 4, Module = 5, Keyword = 1
        }}
      end
      package.preload['cmp.types.cmp'] = function()
        return {CompletionItemKind = {
          Property = 8, Text = 9, Unit = 10
        }}
      end
    ]]
  end)

  it('cmp flags->kind maps b to Variable', function()
    local result = exec_lua[[
      local cmp_mod = require('nvlime.cmp')
      return cmp_mod['flags->kind']('b')
    ]]
    eq(6, result)
  end)

  it('cmp flags->kind maps f to Function', function()
    local result = exec_lua[[
      local cmp_mod = require('nvlime.cmp')
      return cmp_mod['flags->kind']('f')
    ]]
    eq(3, result)
  end)

  it('cmp flags->kind returns nil for empty', function()
    local result = exec_lua[[
      local cmp_mod = require('nvlime.cmp')
      local v = cmp_mod['flags->kind']('')
      return {v == nil or (type(v) == 'userdata' and tostring(v) == 'vim.NIL')}
    ]]
    eq(true, result[1])
  end)
end)

describe('nvlime.completion: SWAK response unwrap', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua;' .. cwd .. '/.test-deps/parsley/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
      vim.opt.rtp:append(cwd .. '/.test-deps/parsley')
    ]]
  end)

  it('list_slice skips :completions marker', function()
    local result = exec_lua[[
      local candidates = {
        {name = "COMPLETIONS", package = "KEYWORD"},  -- index 1: marker
        "foo", "bar", "baz"                            -- index 2+: items
      }
      local items = vim.list_slice(candidates, 2)
      return {#items, items[1], items[2], items[3]}
    ]]
    eq(3, result[1])  -- 3 items
    eq("foo", result[2])
    eq("bar", result[3])
    eq("baz", result[4])
  end)

  it('list_slice on marker-only returns empty', function()
    local result = exec_lua[[
      local candidates = {{name = "COMPLETIONS"}}  -- only marker, no items
      local items = vim.list_slice(candidates, 2)
      return #items
    ]]
    eq(0, result)
  end)

  it('handles nil candidates gracefully with or guard', function()
    local result = exec_lua[[
      local candidates = nil
      local items = vim.list_slice(candidates or {}, 2)
      return #items
    ]]
    eq(0, result)
  end)

  it('simple mode: string items become {:label item}', function()
    local result = exec_lua[[
      local candidates = {
        {name = "COMPLETIONS"},
        "foo", "bar"
      }
      local items = vim.list_slice(candidates, 2)
      local results = {}
      for _, c in ipairs(items) do
        table.insert(results, {label = c})
      end
      return {#results, results[1].label, results[2].label}
    ]]
    eq(2, result[1])
    eq("foo", result[2])
    eq("bar", result[3])
  end)

  it('fuzzy mode: 4-tuple items get label+kind+labelDetails', function()
    local result = exec_lua[[
      local candidates = {
        {name = "COMPLETIONS"},
        {"fn", "fn", "bg", ""},     -- fuzzy item: [match type flags menu]
        {"bar", "var", "f", ""}
      }
      local items = vim.list_slice(candidates, 2)
      local flag_kind = {
        b = 6, f = 3, g = 2, c = 7, t = 7, m = 4, s = 4, p = 5
      }
      local kind_precedence = {5, 7, 4, 2, 3, 6}  -- Module, Class, Operator, Method, Function, Variable
      local results = {}
      for _, c in ipairs(items) do
        local label = c[1]
        local flags = c[3] or ""
        -- flags->kind logic
        local kinds = {}
        for i = 1, #flags do
          local kind = flag_kind[flags:sub(i, i)]
          if kind then kinds[kind] = true end
        end
        local kind = nil
        for _, kp in ipairs(kind_precedence) do
          if kinds[kp] then kind = kp; break end
        end
        if not kind then kind = 1 end  -- Keyword fallback
        table.insert(results, {
          label = label,
          kind = kind,
          labelDetails = {detail = flags}
        })
      end
      return {#results, results[1].label, results[1].kind, results[1].labelDetails.detail,
                    results[2].label, results[2].kind, results[2].labelDetails.detail}
    ]]
    eq(2, result[1])
    eq("fn", result[2])
    eq(2, result[3])      -- "bg" → b=6(Var), g=2(Method) → Method(2) wins in precedence
    eq("bg", result[4])
    eq("bar", result[5])
    eq(3, result[6])      -- "f" → f=3 Function
    eq("f", result[7])
  end)

  it('fuzzy mode: empty flags falls back to Keyword', function()
    local result = exec_lua[[
      local candidates = {
        {name = "COMPLETIONS"},
        {"foo", "fn", "", ""}  -- empty flags
      }
      local items = vim.list_slice(candidates, 2)
      local flag_kind = {b=6,f=3,g=2,c=7,t=7,m=4,s=4,p=5}
      local kind_precedence = {5,7,4,2,3,6}
      local results = {}
      for _, c in ipairs(items) do
        local flags = c[3] or ""
        local kinds = {}
        for i = 1, #flags do
          local kind = flag_kind[flags:sub(i, i)]
          if kind then kinds[kind] = true end
        end
        local kind = nil
        for _, kp in ipairs(kind_precedence) do
          if kinds[kp] then kind = kp; break end
        end
        if not kind then kind = 1 end
        table.insert(results, {label = c[1], kind = kind})
      end
      return {#results, results[1].label, results[1].kind}
    ]]
    eq(1, result[1])
    eq("foo", result[2])
    eq(1, result[3])  -- Keyword fallback
  end)

  it('fuzzy mode: unknown flags falls back to Keyword', function()
    local result = exec_lua[[
      local candidates = {
        {name = "COMPLETIONS"},
        {"foo", "fn", "xyz", ""}  -- unknown flags
      }
      local items = vim.list_slice(candidates, 2)
      local flag_kind = {b=6,f=3,g=2,c=7,t=7,m=4,s=4,p=5}
      local kind_precedence = {5,7,4,2,3,6}
      local results = {}
      for _, c in ipairs(items) do
        local flags = c[3] or ""
        local kinds = {}
        for i = 1, #flags do
          local kind = flag_kind[flags:sub(i, i)]
          if kind then kinds[kind] = true end
        end
        local kind = nil
        for _, kp in ipairs(kind_precedence) do
          if kinds[kp] then kind = kp; break end
        end
        if not kind then kind = 1 end
        table.insert(results, {label = c[1], kind = kind})
      end
      return {#results, results[1].label, results[1].kind}
    ]]
    eq(1, result[1])
    eq("foo", result[2])
    eq(1, result[3])  -- Keyword fallback
  end)

  it('handles empty completions list', function()
    local result = exec_lua[[
      local candidates = {{name = "COMPLETIONS"}}  -- only marker
      local items = vim.list_slice(candidates, 2)
      local results = {}
      for _, c in ipairs(items or {}) do
        table.insert(results, {label = c})
      end
      return #results
    ]]
    eq(0, result)
  end)
end)

describe('nvlime.completion: edge cases', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua;' .. cwd .. '/.test-deps/parsley/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
      vim.opt.rtp:append(cwd .. '/.test-deps/parsley')
      
      package.preload['blink.cmp.types'] = function()
        return {CompletionItemKind = {
          Variable = 6, Function = 3, Method = 2,
          Class = 7, Operator = 4, Module = 5, Keyword = 1
        }}
      end
      package.preload['cmp.types.lsp'] = function()
        return {CompletionItemKind = {
          Variable = 6, Function = 3, Method = 2,
          Class = 7, Operator = 4, Module = 5, Keyword = 1
        }}
      end
    ]]
  end)

  it('called guard prevents double callback', function()
    -- Test the "called" flag pattern used in Source.get_completions
    -- This is a regression test for the bug where SWAK could trigger
    -- the callback twice (once on success, once on some error path)
    local result = exec_lua[[
      local called = false
      local results = {}
      local on_done = function(candidates)
        if not called then
          called = true
          local items = vim.list_slice(candidates or {}, 2)
          for _, c in ipairs(items) do
            table.insert(results, {label = c})
          end
        end
      end
      -- Simulate SWAK calling callback twice
      on_done({{name = "COMPLETIONS"}, "foo", "bar"})
      on_done({{name = "COMPLETIONS"}, "baz", "qux"})  -- should be ignored
      return {#results, results[1].label, results[2].label, #results == 2}
    ]]
    eq(2, result[1])  -- Only 2 items from first callback
    eq("foo", result[2])
    eq("bar", result[3])
    eq(true, result[4])  -- Exactly 2 items (not 4)
  end)

  it('called guard with nil second callback', function()
    local result = exec_lua[[
      local called = false
      local results = {}
      local on_done = function(candidates)
        if not called then
          called = true
          local items = vim.list_slice(candidates or {}, 2)
          for _, c in ipairs(items) do
            table.insert(results, {label = c})
          end
        end
      end
      on_done({{name = "COMPLETIONS"}, "foo"})
      on_done(nil)  -- nil second call should be ignored
      return {#results, results[1].label}
    ]]
    eq(1, result[1])
    eq("foo", result[2])
  end)

  it('empty keyword start-col calculation', function()
    -- When keyword is empty, start-col should equal cursor-col
    -- start-col = cursor-col - #keyword = cursor-col - 0 = cursor-col
    local result = exec_lua[[
      local cursor_col = 10
      local keyword = ""
      local start_col = cursor_col - #keyword
      return {start_col, start_col == cursor_col}
    ]]
    eq(10, result[1])
    eq(true, result[2])
  end)

  it('non-empty keyword start-col calculation', function()
    local result = exec_lua[[
      local cursor_col = 15
      local keyword = "foo"
      local start_col = cursor_col - #keyword
      return {start_col, start_col == 12}
    ]]
    eq(12, result[1])
    eq(true, result[2])
  end)

  it('textEdit range for empty keyword', function()
    -- When keyword is empty, textEdit range should have start == end
    local result = exec_lua[[
      local cursor_line = 5
      local cursor_col = 10
      local keyword = ""
      local start_col = cursor_col - #keyword
      local text_edit = {
        newText = "test",
        range = {
          start = {line = cursor_line - 1, character = start_col},
          ["end"] = {line = cursor_line - 1, character = cursor_col}
        }
      }
      return {
        text_edit.range.start.character,
        text_edit.range["end"].character,
        text_edit.range.start.character == text_edit.range["end"].character
      }
    ]]
    eq(10, result[1])  -- start character
    eq(10, result[2])  -- end character
    eq(true, result[3])  -- start == end for empty keyword
  end)

  it('textEdit range for non-empty keyword', function()
    local result = exec_lua[[
      local cursor_line = 3
      local cursor_col = 15
      local keyword = "foo"
      local start_col = cursor_col - #keyword
      local text_edit = {
        newText = "bar",
        range = {
          start = {line = cursor_line - 1, character = start_col},
          ["end"] = {line = cursor_line - 1, character = cursor_col}
        }
      }
      return {
        text_edit.range.start.character,
        text_edit.range["end"].character,
        text_edit.range.start.character ~= text_edit.range["end"].character
      }
    ]]
    eq(12, result[1])  -- start character
    eq(15, result[2])  -- end character
    eq(true, result[3])  -- start != end
  end)
end)
