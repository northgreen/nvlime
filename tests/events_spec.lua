local helpers = require('nvim-test.helpers')
local eq = helpers.eq
local exec_lua = helpers.exec_lua

describe('nvlime.core.connection (events mixin)', function()
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

  describe('keyword-list-2-dict', function()
    it('converts keyword list to dict', function()
      eq({['FOO-BAR'] = 1, ['BAZ-QUUX'] = 'hello'}, exec_lua[[
        local conn = require('nvlime.core.connection')
        conn._call({}, 'keyword-list-2-dict', {}) -- trigger mixin loading
        local input = {
          {{name = 'FOO-BAR', package = 'KEYWORD'}, 1},
          {{name = 'BAZ-QUUX', package = 'KEYWORD'}, 'hello'},
        }
        return conn['keyword-list-2-dict'](nil, input)
      ]])
    end)

    it('handles empty list', function()
      eq({}, exec_lua[[
        local conn = require('nvlime.core.connection')
        conn._call({}, 'keyword-list-2-dict', {}) -- trigger mixin loading
        return conn['keyword-list-2-dict'](nil, {})
      ]])
    end)
  end)
end)
