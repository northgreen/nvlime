local helpers = require('nvim-test.helpers')
local eq = helpers.eq
local exec_lua = helpers.exec_lua

describe('nvlime.core.connection', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua;' .. cwd .. '/after/?.lua;' .. cwd .. '/.test-deps/parsley/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
      vim.opt.rtp:append(cwd .. '/after')
      vim.opt.rtp:append(cwd .. '/.test-deps/parsley')
    ]]
  end)

  describe('symbol constructors', function()
    it('sym creates symbol dict', function()
      eq({package = 'SWANK', name = 'CONNECTION-INFO'}, exec_lua[[
        local conn = require('nvlime.core.connection')
        return conn.sym('SWANK', 'CONNECTION-INFO')
      ]])
    end)

    it('kw creates keyword symbol', function()
      eq({package = 'KEYWORD', name = 'PING'}, exec_lua[[
        return require('nvlime.core.connection').kw('PING')
      ]])
    end)

    it('cl creates COMMON-LISP symbol', function()
      eq({package = 'COMMON-LISP', name = 'CAR'}, exec_lua[[
        return require('nvlime.core.connection').cl('CAR')
      ]])
    end)
  end)
end)
