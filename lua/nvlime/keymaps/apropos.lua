local km = require("nvlime.keymaps")
local am = km.mappings.apropos
local apropos = {}
apropos.add = function()
  return km.buffer.normal(am.normal.inspect, "<Cmd>lua require('nvlime.core.plugin').inspect(\"'\" .. vim.fn.substitute(vim.fn.getline('.'), '  .*$', '', ''))<CR>", "nvlime: Inspect current symbol")
end
return apropos
