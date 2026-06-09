-- Nvlime blink.cmp integration
-- This module is automatically loaded when blink.cmp is available

local ok, _ = pcall(require, 'blink.cmp')
if not ok then
  return
end

local opts = require("nvlime.config")
if opts.blink.enabled then
  vim.g.nvlime_blink_registered = true
end
