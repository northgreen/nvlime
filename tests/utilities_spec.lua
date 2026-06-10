local helpers = require('nvim-test.helpers')
local eq = helpers.eq
local exec_lua = helpers.exec_lua

describe('nvlime.utilities', function()
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

  describe('plist->table', function()
    it('converts alternating key-value pairs to dict', function()
      eq({FILE = '/path/file.lisp', POSITION = 42}, exec_lua[[
        local util = require('nvlime.utilities')
        local plist = {
          {name = 'FILE', package = 'KEYWORD'}, '/path/file.lisp',
          {name = 'POSITION', package = 'KEYWORD'}, 42,
        }
        return util['plist->table'](plist)
      ]])
    end)

    it('handles empty list', function()
      eq({}, exec_lua[[
        return require('nvlime.utilities')['plist->table']({})
      ]])
    end)
  end)

  describe('text->lines', function()
    it('splits on newlines', function()
      eq({'foo', 'bar'}, exec_lua[[return require('nvlime.utilities')['text->lines']('foo\nbar')]])
    end)

    it('handles nil input', function()
      eq({}, exec_lua[[return require('nvlime.utilities')['text->lines'](nil)]])
    end)

    it('handles empty string', function()
      eq({}, exec_lua[[return require('nvlime.utilities')['text->lines']('')]])
    end)
  end)

  describe('coord-range', function()
    it('unpacks coord table', function()
      eq({1, 5, 1, 10}, exec_lua[[
        local util = require('nvlime.utilities')
        local coord = {['begin'] = {1, 5}, ['end'] = {1, 10}}
        local r1, r2, r3, r4 = util['coord-range'](coord)
        return {r1, r2, r3, r4}
      ]])
    end)
  end)

  describe('in-coord-range?', function()
    it('returns true for point inside range', function()
      eq(true, exec_lua[[
        local util = require('nvlime.utilities')
        local coord = {['begin'] = {5, 10}, ['end'] = {5, 20}}
        return util['in-coord-range?'](coord, 5, 15)
      ]])
    end)

    it('returns false before range', function()
      eq(false, exec_lua[[
        local util = require('nvlime.utilities')
        local coord = {['begin'] = {5, 10}, ['end'] = {5, 20}}
        return util['in-coord-range?'](coord, 5, 5)
      ]])
    end)

    it('returns false for different line', function()
      eq(false, exec_lua[[
        local util = require('nvlime.utilities')
        local coord = {['begin'] = {5, 10}, ['end'] = {5, 20}}
        return util['in-coord-range?'](coord, 6, 15)
      ]])
    end)
  end)
end)
