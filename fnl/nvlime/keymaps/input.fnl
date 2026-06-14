(local km (require "nvlime.keymaps"))
(local im km.mappings.input)
(local km-window (require "nvlime.window.keymaps"))
(local {: nvim_win_close
        : nvim_win_get_cursor}
       vim.api)

(local Input {})

(fn Input.add []
  (km.buffer.normal im.normal.complete
                    "<Cmd>lua require('nvlime.core.ui.input').from_buffer_complete()<CR>"
                    "nvlime: Complete the input")
  (km.buffer.insert im.insert.keymaps_help
                    #(km-window.toggle)
                    "Show keymaps help")
  (km.buffer.insert im.insert.complete
                    "<Cmd>lua require('nvlime.core.ui.input').from_buffer_complete()<CR>"
                    "nvlime: Complete the input")
  (km.buffer.insert im.insert.next_history
                    "<Cmd>lua require('nvlime.core.ui.input').next_history_item()<CR>"
                    "nvlime: Show the next item in input history")
  (km.buffer.insert im.insert.prev_history
                    "<Cmd>lua require('nvlime.core.ui.input').next_history_item(v:false)<CR>"
                    "nvlime: Show the previous item in input history")
  (km.buffer.insert im.insert.leave_insert
                    #(let [[linenr col] (nvim_win_get_cursor 0)]
                       (if (and (= linenr 1) (= col 0))
                           (nvim_win_close 0 true))
                       (km.feedkeys "<Esc>"))
                    "Close window or leave insert mode"))

Input
