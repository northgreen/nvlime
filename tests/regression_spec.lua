local helpers = require('nvim-test.helpers')
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('regression: module declarations are tables', function()
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

  it('ui.input loads as a table', function()
    local is_table = exec_lua[[
      return type(require('nvlime.core.ui.input')) == 'table'
    ]]
    eq(true, is_table)
  end)

  it('ui.mrepl loads as a table', function()
    local is_table = exec_lua[[
      return type(require('nvlime.core.ui.mrepl')) == 'table'
    ]]
    eq(true, is_table)
  end)

  it('ui.inspector loads as a table', function()
    eq(true, exec_lua[[return type(require('nvlime.core.ui.inspector')) == 'table']])
  end)

  it('ui.compiler_notes loads as a table', function()
    eq(true, exec_lua[[return type(require('nvlime.core.ui.compiler_notes')) == 'table']])
  end)

  it('ui.xref loads as a table', function()
    eq(true, exec_lua[[return type(require('nvlime.core.ui.xref')) == 'table']])
  end)
end)

describe('regression: config defaults', function()
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

  it('blink.enabled = false', function()
    eq(false, exec_lua[[return require('nvlime.config').blink.enabled]])
  end)

  it('cmp.enabled = false', function()
    eq(false, exec_lua[[return require('nvlime.config').cmp.enabled]])
  end)

  it('arglist.enabled = true', function()
    eq(true, exec_lua[[return require('nvlime.config').arglist.enabled]])
  end)

  it('address.host = "127.0.0.1"', function()
    eq('127.0.0.1', exec_lua[[return require('nvlime.config').address.host]])
  end)

  it('address.port = 7002', function()
    eq(7002, exec_lua[[return require('nvlime.config').address.port]])
  end)
end)

describe('regression: require path underscores', function()
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

  it('conn_manager loads', function()
    local result = exec_lua[[
      local ok, e = pcall(require, 'nvlime.core.conn_manager')
      return {ok, e and tostring(e)}
    ]]
    eq(true, result[1])
  end)

  it('presentation_streams loads', function()
    local ok = exec_lua[[
      local ok = pcall(require, 'nvlime.core.contrib.presentation_streams')
      return ok
    ]]
    eq(true, ok)
  end)

  it('trace_dialog loads', function()
    local ok = exec_lua[[
      local ok = pcall(require, 'nvlime.core.contrib.trace_dialog')
      return ok
    ]]
    eq(true, ok)
  end)
end)
