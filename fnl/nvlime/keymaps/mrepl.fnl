(local km (require "nvlime.keymaps"))
(local mm km.mappings.mrepl)

(local mrepl {})

(fn mrepl.add []
  (km.buffer.normal mm.normal.clear
                    "<Cmd>lua require('nvlime.core.ui.mrepl').clear()<CR>"
                    "nvlime: Clear the MREPL buffer")
  (km.buffer.normal mm.normal.disconnect
                    "<Cmd>lua require('nvlime.core.ui.mrepl').disconnect()<CR>"
                    "nvlime: Disconnect from this REPL")
  (km.buffer.insert mm.insert.space_arglist
                    "<Space><Cmd>lua require('nvlime.core.plugin')['space-enter-key']()<CR>"
                    "nvlime: Trigger the arglist hint")
  (km.buffer.insert mm.insert.submit
                    "<C-r>=require('nvlime.core.ui.mrepl').submit()<CR>"
                    "nvlime: Submit the last input to the REPL")
  (km.buffer.insert mm.insert.cr_arglist
                    "<CR><Cmd>lua require('nvlime.core.plugin')['space-enter-key']()<CR>"
                    "nvlime: Insert a newline and trigger the arglist hint")
  (km.buffer.insert mm.insert.interrupt
                    "<C-r>=require('nvlime.core.ui.mrepl').interrupt()<CR>"
                    "nvlime: Interrupt the MREPL thread"))

mrepl
