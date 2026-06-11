(local km (require "nvlime.keymaps"))
(local im km.mappings.inspector)

(local inspector {})

(fn inspector.add []
  (km.buffer.normal im.normal.action
                    "<Cmd>lua require('nvlime.core.ui.inspector').inspector_select()<CR>"
                    "nvlime: Activate the interactable field/button under the cursor")
  (km.buffer.normal im.normal.current.send
                    "<Cmd>lua require('nvlime.core.ui.inspector').send_cur_value_to_repl()<CR>"
                    "nvlime: Send the value of the field under the cursor to the REPL")
  (km.buffer.normal im.normal.current.source
                    "<Cmd>lua require('nvlime.core.ui.inspector').find_source('part')<CR>"
                    "nvlime: Open the source code for the value of the field under the cursor")
  (km.buffer.normal im.normal.inspected.send
                    "<Cmd>lua require('nvlime.core.ui.inspector').send_cur_inspectee_to_repl()<CR>"
                    "nvlime: Send the value being inspected to the REPL")
  (km.buffer.normal im.normal.inspected.source
                    "<Cmd>lua require('nvlime.core.ui.inspector').find_source('inspectee')<CR>"
                    "nvlime: Open the source code for the value being inspected")
  (km.buffer.normal im.normal.inspected.previous
                    "<Cmd>lua require('nvlime.core.ui.inspector').inspector_pop()<CR>"
                    "nvlime: Return to the previous inspected object")
  (km.buffer.normal im.normal.inspected.next
                    "<Cmd>lua require('nvlime.core.ui.inspector').inspector_next()<CR>"
                    "nvlime: Move to the next inspected object")
  (km.buffer.normal im.normal.next_field
                    "<Cmd>lua require('nvlime.core.ui.inspector').next_field(v:true)<CR>"
                    "nvlime: Select the next interactable field/button")
  (km.buffer.normal im.normal.prev_field
                    "<Cmd>lua require('nvlime.core.ui.inspector').next_field(v:false)<CR>"
                    "nvlime: Select the previous interactable field/button")
  (km.buffer.normal im.normal.refresh
                    "<Cmd>call b:nvlime_conn.InspectorReinspect({c, r -> c.ui.OnInspect(c, r, v:null, v:null)})<CR>"
                    "nvlime: Refresh the inspector"))

inspector
