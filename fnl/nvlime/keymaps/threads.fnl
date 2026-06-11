(local km (require "nvlime.keymaps"))
(local tm km.mappings.threads)

(local threads {})

(fn threads.add []
  (km.buffer.normal tm.normal.interrupt
                    "<Cmd>lua require('nvlime.core.ui.threads').interrupt_cur_thread()<CR>"
                    "nvlime: Interrupt the selected thread")
  (km.buffer.normal tm.normal.kill
                    "<Cmd>lua require('nvlime.core.ui.threads').kill_cur_thread()<CR>"
                    "nvlime: Kill the selected thread")
  (km.buffer.normal tm.normal.invoke_debugger
                    "<Cmd>lua require('nvlime.core.ui.threads').debug_cur_thread()<CR>"
                    "nvlime: Invoke the debugger in the selected thread")
  (km.buffer.normal tm.normal.refresh
                    "<Cmd>lua require('nvlime.core.ui.threads').refresh()<CR>"
                    "nvlime: Refresh the thread list"))

threads
