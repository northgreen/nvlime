local helpers = require('nvim-test.helpers')
local eq = helpers.eq
local exec_lua = helpers.exec_lua

describe('nvlime.core.server', function()
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

  describe('build-server-command-for-sbcl', function()
    it('returns sbcl command with --load and --eval', function()
      eq({'sbcl', '--load', 'loader.lisp', '--eval', '(print 1)'}, exec_lua[[
        local srv = require('nvlime.core.server')
        return srv['build-server-command-for-sbcl']('loader.lisp', '(print 1)')
      ]])
    end)
  end)

  describe('build-server-command-for-ccl', function()
    it('returns ccl command', function()
      local result = exec_lua[[
        local srv = require('nvlime.core.server')
        local cmd = srv['build-server-command-for-ccl']('loader.lisp', '(print 1)')
        return cmd[1]
      ]]
      eq('ccl', result)
    end)
  end)
end)
