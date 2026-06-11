local km = require("nvlime.keymaps")
local nm = km.mappings.notes
local notes = {}
notes.add = function()
  km.buffer.normal(nm.normal.source, "<Cmd>lua require('nvlime.core.ui.compiler_notes').open_cur_note()<CR>", "nvlime: Open the selected source location")
  km.buffer.normal(nm.normal.source_split, "<Cmd>lua require('nvlime.core.ui.compiler_notes').open_cur_note('split')<CR>", "nvlime: Open the selected source location in a split")
  km.buffer.normal(nm.normal.source_vsplit, "<Cmd>lua require('nvlime.core.ui.compiler_notes').open_cur_note('vsplit')<CR>", "nvlime: Open the selected source location in a vertical split")
  return km.buffer.normal(nm.normal.source_tab, "<Cmd>lua require('nvlime.core.ui.compiler_notes').open_cur_note('tabedit')<CR>", "nvlime: Open the selected source location in a new tabpage")
end
return notes
