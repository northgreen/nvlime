local helpers = require('nvim-test.helpers')
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('nvlime.blink', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua;' .. cwd .. '/.test-deps/parsley/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
      vim.opt.rtp:append(cwd .. '/.test-deps/parsley')
    ]]
  end)

  it('module loads with parsley dependency', function()
    -- blink.cmp may not be installed, so we just check that pcall doesn't crash
    local result = exec_lua[[
      local ok, e = pcall(require, 'nvlime.blink')
      return {ok, e and tostring(e)}
    ]]
    -- If blink.cmp is not installed, it's acceptable for the module to fail loading
    -- The test passes as long as it fails gracefully (not a Lua syntax error)
    if not result[1] then
      -- Check it's a missing module error, not a crash
      local has_module_error = string.find(tostring(result[2]) or '', 'blink.cmp') ~= nil
      eq(true, has_module_error or result[1])
    else
      eq(true, result[1])
    end
  end)
end)
