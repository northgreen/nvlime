local helpers = require('nvim-test.helpers')
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('nvlime.config', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua;' .. cwd .. '/after/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
      vim.opt.rtp:append(cwd .. '/after')
    ]]
  end)

  describe('basic defaults', function()
    it('leader = "<LocalLeader>"', function()
      eq('<LocalLeader>', exec_lua[[return require('nvlime.config').leader]])
    end)

    it('implementation = "sbcl"', function()
      eq('sbcl', exec_lua[[return require('nvlime.config').implementation]])
    end)

    it('input_history_limit = 100', function()
      eq(100, exec_lua[[return require('nvlime.config').input_history_limit]])
    end)
  end)

  describe('autodoc', function()
    it('autodoc.enabled = false', function()
      eq(false, exec_lua[[return require('nvlime.config').autodoc.enabled]])
    end)

    it('autodoc.max_level = 5', function()
      eq(5, exec_lua[[return require('nvlime.config').autodoc.max_level]])
    end)

    it('autodoc.max_lines = 50', function()
      eq(50, exec_lua[[return require('nvlime.config').autodoc.max_lines]])
    end)
  end)

  describe('main_window', function()
    it('main_window.position = "right"', function()
      eq('right', exec_lua[[return require('nvlime.config').main_window.position]])
    end)
  end)

  describe('floating_window', function()
    it('floating_window.border = "single"', function()
      eq('single', exec_lua[[return require('nvlime.config').floating_window.border]])
    end)

    it('floating_window.scroll_step = 3', function()
      eq(3, exec_lua[[return require('nvlime.config').floating_window.scroll_step]])
    end)
  end)

  describe('indent_keywords', function()
    it('defun = 2', function()
      eq(2, exec_lua[[
        local c = require('nvlime.config')
        return c.indent_keywords['defun']
      ]])
    end)

    it('defmacro = 2', function()
      eq(2, exec_lua[[
        local c = require('nvlime.config')
        return c.indent_keywords['defmacro']
      ]])
    end)
  end)
end)
