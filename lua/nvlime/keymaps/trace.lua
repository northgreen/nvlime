local km = require("nvlime.keymaps")
local tm = km.mappings.trace
local trace = {}
trace.add = function()
  km.buffer.normal(tm.normal.action, "<Cmd>lua require('nvlime.core.ui.trace_dialog').select()<CR>", "nvlime: Activate the interactable field/button under the cursor")
  km.buffer.normal(tm.normal.refresh, "<Cmd>lua require('nvlime.core.plugin')['open-trace-dialog']()<CR>", "nvlime: Refresh the trace dialog")
  km.buffer.normal(tm.normal.inspect_value, "<Cmd>lua require('nvlime.core.ui.trace_dialog').select('inspect')<CR>", "nvlime: Inspect the value of the field under the cursor")
  km.buffer.normal(tm.normal.send_value, "<Cmd>lua require('nvlime.core.ui.trace_dialog').select('to_repl')<CR>", "nvlime: Send the value of the field under the cursor to the REPL")
  km.buffer.normal(tm.normal.next_field, "<Cmd>lua require('nvlime.core.ui.trace_dialog').next_field(true)<CR>", "nvlime: Select the next interactable field/button")
  return km.buffer.normal(tm.normal.prev_field, "<Cmd>lua require('nvlime.core.ui.trace_dialog').next_field(false)<CR>", "nvlime: Select the previous interactable field/button")
end
return trace
