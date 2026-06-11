(local km (require "nvlime.keymaps"))
(local xm km.mappings.xref)

(local xref {})

(fn xref.add []
  (km.buffer.normal xm.normal.source
                    "<Cmd>lua require('nvlime.core.ui.xref').open_cur_xref()<CR>"
                    "nvlime: Open the selected source location")
  (km.buffer.normal xm.normal.source_split
                    "<Cmd>lua require('nvlime.core.ui.xref').open_cur_xref('split')<CR>"
                    "nvlime: Open the selected source location in a split")
  (km.buffer.normal xm.normal.source_vsplit
                    "<Cmd>lua require('nvlime.core.ui.xref').open_cur_xref('vsplit')<CR>"
                    "nvlime: Open the selected source location in a vertical split")
  (km.buffer.normal xm.normal.source_tab
                    "<Cmd>lua require('nvlime.core.ui.xref').open_cur_xref('tabedit')<CR>"
                    "nvlime: Open the selected source location in a new tabpage"))

xref
