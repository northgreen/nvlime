local helpers = require('nvim-test.helpers')
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('ui: pad', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua;' .. cwd .. '/after/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
      vim.opt.rtp:append(cwd .. '/after')
    ]]
  end)

  it('pads string with separator', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      return require('nvlime.core.ui').pad('hello', ':', 10)
    ]]
    eq('hello:      ', result)
  end)
end)

describe('ui: append-string', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua;' .. cwd .. '/after/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
      vim.opt.rtp:append(cwd .. '/after')
    ]]
  end)

  it('appends text to current buffer', function()
    local line_count = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local ui = require('nvlime.core.ui')
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'line1', ''})
      ui.append_string('line2')
      return vim.fn.line('$')
    ]]
    eq(2, line_count)
  end)
end)

describe('ui: match-coord', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
    ]]
  end)

  it('returns nil for null coord', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local r = require('nvlime.core.ui').match_coord({begin = nil, ["end"] = nil}, 1, 1)
      return r == nil or type(r) == 'function'
    ]]
    eq(true, result)
  end)

  it('matches single-line coord', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local ui = require('nvlime.core.ui')
      local coord = {begin = {1, 3}, ["end"] = {1, 8}}
      return ui.match_coord(coord, 1, 5)
    ]]
    eq(true, result)
  end)

  it('rejects point outside single-line coord', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local ui = require('nvlime.core.ui')
      local coord = {begin = {1, 3}, ["end"] = {1, 8}}
      local r = ui.match_coord(coord, 1, 1)
      return r == nil or type(r) == 'function'
    ]]
    eq(true, result)
  end)

  it('matches multi-line coord on begin line', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local ui = require('nvlime.core.ui')
      local coord = {begin = {1, 5}, ["end"] = {3, 2}}
      return ui.match_coord(coord, 1, 7)
    ]]
    eq(true, result)
  end)

  it('matches multi-line coord on end line', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local ui = require('nvlime.core.ui')
      local coord = {begin = {1, 5}, ["end"] = {3, 2}}
      return ui.match_coord(coord, 3, 1)
    ]]
    eq(true, result)
  end)

  it('matches multi-line coord between lines', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local ui = require('nvlime.core.ui')
      local coord = {begin = {1, 5}, ["end"] = {3, 2}}
      return ui.match_coord(coord, 2, 1)
    ]]
    eq(true, result)
  end)

  it('rejects point above multi-line coord', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local ui = require('nvlime.core.ui')
      local coord = {begin = {2, 5}, ["end"] = {4, 2}}
      local r = ui.match_coord(coord, 1, 1)
      return r == nil or type(r) == 'function'
    ]]
    eq(true, result)
  end)

  it('rejects point below multi-line coord', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local ui = require('nvlime.core.ui')
      local coord = {begin = {2, 5}, ["end"] = {4, 2}}
      local r = ui.match_coord(coord, 5, 1)
      return r == nil or type(r) == 'function'
    ]]
    eq(true, result)
  end)
end)

describe('ui: sort-coords', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
    ]]
  end)

  it('sorts coords forward by begin position', function()
    local sorted = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local ui = require('nvlime.core.ui')
      local coords = {
        {begin = {3, 1}, ["end"] = {3, 5}},
        {begin = {1, 2}, ["end"] = {1, 8}},
        {begin = {2, 3}, ["end"] = {2, 6}},
      }
      return ui.sort_coords(coords, true)
    ]]
    eq(1, sorted[1].begin[1])
    eq(2, sorted[2].begin[1])
    eq(3, sorted[3].begin[1])
  end)
end)

describe('ui: find-next-coord', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
    ]]
  end)

  it('finds next coord forward', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local ui = require('nvlime.core.ui')
      local sorted = {
        {begin = {1, 2}, ["end"] = {1, 8}},
        {begin = {2, 3}, ["end"] = {2, 6}},
        {begin = {3, 1}, ["end"] = {3, 5}},
      }
      return ui.find_next_coord({1, 5}, sorted, true)
    ]]
    eq(2, result.begin[1])
  end)

  it('finds next coord backward', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local ui = require('nvlime.core.ui')
      local sorted = {
        {begin = {1, 2}, ["end"] = {1, 8}},
        {begin = {2, 3}, ["end"] = {2, 6}},
        {begin = {3, 1}, ["end"] = {3, 5}},
      }
      return ui.find_next_coord({2, 5}, sorted, false)
    ]]
    eq(1, result.begin[1])
  end)
end)

describe('ui: jump-to-or-open-file', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua;' .. cwd .. '/after/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
      vim.opt.rtp:append(cwd .. '/after')
    ]]
  end)

  it('opens readable file', function()
    local result = exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      local ui = require('nvlime.core.ui')
      -- Use Makefile as it always exists
      local ok, err = pcall(ui.jump_to_or_open_file, cwd .. '/Makefile', nil, nil, 'hide edit', true)
      if not ok then
        return 'error: ' .. tostring(err)
      end
      return vim.fn.bufname('%')
    ]]
    -- Should contain Makefile in the buffer name
    eq(true, string.find(result, 'Makefile') ~= nil)
  end)
end)

describe('ui: is-yes-string', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
    ]]
  end)

  it('matches ye', function()
    eq(true, exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      return require('nvlime.core.ui').is_yes_string('ye')
    ]])
  end)

  it('matches Yes', function()
    eq(true, exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      return require('nvlime.core.ui').is_yes_string('Yes')
    ]])
  end)

  it('matches yes', function()
    eq(true, exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      return require('nvlime.core.ui').is_yes_string('yes')
    ]])
  end)

  it('rejects n', function()
    eq(false, exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      return require('nvlime.core.ui').is_yes_string('n')
    ]])
  end)

  it('rejects empty', function()
    eq(false, exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      return require('nvlime.core.ui').is_yes_string('')
    ]])
  end)
end)

describe('ui: normalize-package-name', function()
  before_each(function()
    helpers.clear()
    exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      vim.opt.rtp:append(cwd .. '/lua')
    ]]
  end)

  it('returns empty for #: prefix', function()
    eq('', exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      return require('nvlime.core.ui').normalize_package_name('#:common-lisp')
    ]])
  end)

  it('returns empty for #:: prefix', function()
    eq('', exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      return require('nvlime.core.ui').normalize_package_name('#::cl-user')
    ]])
  end)

  it('returns empty for double quotes', function()
    eq('', exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      return require('nvlime.core.ui').normalize_package_name('"my-pkg"')
    ]])
  end)

  it('returns empty for plain name', function()
    eq('', exec_lua[[
      local cwd = vim.fn.getcwd()
      package.path = package.path .. ';' .. cwd .. '/lua/?.lua'
      return require('nvlime.core.ui').normalize_package_name('foo-bar')
    ]])
  end)
end)
