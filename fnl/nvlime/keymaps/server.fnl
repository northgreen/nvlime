(local km (require "nvlime.keymaps"))
(local sm km.mappings.server)

(local server {})

(fn server.add []
  (km.buffer.normal sm.normal.connect
                    "<Cmd>lua require('nvlime.core.server').connect_to_cur_server()<CR>"
                    "nvlime: Connect to this server")
  (km.buffer.normal sm.normal.stop
                    "<Cmd>lua require('nvlime.core.server').stop_cur_server()<CR>"
                    "nvlime: Stop this server"))

server
