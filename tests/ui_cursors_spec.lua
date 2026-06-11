local helpers = require('nvim-test.helpers')
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('ui_cursors: module loads', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
    ]]
  end)

  it('ui_cursors loads as a table', function()
    eq(true, exec_lua[[
      return type(require('nvlime.ui_cursors')) == 'table'
    ]])
  end)
end)

describe('ui_cursors: get_text', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
    ]]
  end)

  it('extracts single-line text', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local uc = require('nvlime.ui_cursors')
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'hello world'})
      return uc.get_text({1, 1}, {1, 5})
    ]]
    eq('hello', result)
  end)

  it('extracts multi-line text', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local uc = require('nvlime.ui_cursors')
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'line1', 'line2', 'line3'})
      return uc.get_text({1, 1}, {2, 5})
    ]]
    eq('line1\nline2', result)
  end)
end)

describe('ui_cursors: cur_char', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
    ]]
  end)

  it('gets character under cursor', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local uc = require('nvlime.ui_cursors')
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'hello'})
      vim.fn.cursor(1, 1)
      return uc.cur_char()
    ]]
    eq('h', result)
  end)
end)
