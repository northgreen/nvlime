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
