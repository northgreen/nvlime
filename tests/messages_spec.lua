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

  describe('plist-to-dict', function()
    it('converts keyword-plist to dict with lowercased keys', function()
      eq({FOO = 1, BAR = 'hello'}, exec_lua[[
        local conn = require('nvlime.core.connection')
        conn._call({}, 'plist-to-dict', {}) -- trigger mixin loading
        local plist = {
          {name = 'FOO', package = 'KEYWORD'}, 1,
          {name = 'BAR', package = 'KEYWORD'}, 'hello',
        }
        return conn['plist-to-dict'](nil, plist)
      ]])
    end)

    it('handles empty plist', function()
      eq({}, exec_lua[[
        local conn = require('nvlime.core.connection')
        conn._call({}, 'plist-to-dict', {}) -- trigger mixin loading
        return conn['plist-to-dict'](nil, {})
      ]])
    end)
  end)

  describe('has-key / get', function()
    it('has-key finds original case', function()
      eq(1, exec_lua[[
        return require('nvlime.core.connection')['has-key']({FOO = 1}, 'FOO')
      ]])
    end)

    it('has-key finds lowercase', function()
      eq(1, exec_lua[[
        return require('nvlime.core.connection')['has-key']({FOO = 1}, 'foo')
      ]])
    end)

    it('has-key returns nil for missing', function()
      local result = exec_lua[[
        local v = require('nvlime.core.connection')['has-key']({FOO = 1}, 'BAR')
        return {type(v) == 'nil' or (type(v) == 'userdata' and tostring(v) == 'vim.NIL')}
      ]]
      eq(true, result[1])
    end)

    it('get returns default for missing key', function()
      eq('default', exec_lua[[
        return require('nvlime.core.connection').get({}, 'FOO', 'default')
      ]])
    end)
  end)
end)
