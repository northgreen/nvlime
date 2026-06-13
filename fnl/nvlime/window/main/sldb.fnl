(local buffer (require "nvlime.buffer"))
(local main (require "nvlime.window.main"))
(local psl (require "parsley"))
(local pbuf (require "parsley.buffer"))
(local {: nvim_win_set_buf
        : nvim_win_close
        : nvim_buf_get_var}
       vim.api)

(local sldb {})

(local +filetype+ (buffer.gen-filetype buffer.names.sldb))

;;; BufNr {any} ->
(fn buf-callback [bufnr opts]
  (logger.debug (.. "sldb.buf-callback: ENTER bufnr=" (tostring bufnr)))
  (buffer.set-opts bufnr {:filetype +filetype+})
  (buffer.set-vars
    bufnr {:nvlime_sldb_level opts.level
           :nvlime_sldb_frames opts.frames})
  (let [conn (buffer.set-conn-var! bufnr)]
    (logger.debug (.. "sldb.buf-callback: conn=" (tostring (if conn (. conn :cb_data :name) "nil"))))
    (when conn
      (logger.debug (.. "sldb.buf-callback: calling set-current-thread thread=" (tostring opts.thread)))
      (conn:set-current-thread opts.thread)
      (logger.debug "sldb.buf-callback: set-current-thread returned")))
  (logger.debug "sldb.buf-callback: EXIT"))

;;; TODO should process config.stepping?
;;; TODO remove flickering of stepping and continue
;;; {any} ->
(fn sldb.on-debug-return [config]
  (let [(exists? bufnr) (pbuf.exists? (buffer.gen-sldb-name
                                           config.conn-name config.thread))]

    (when exists?
      (let [buf-level (or (nvim_buf_get_var bufnr "nvlime_sldb_level")
                          -1)]
        (when (= buf-level config.level)
          (main.sldb:remove-buf bufnr)
          (buffer.fill! bufnr [])
          (buffer.set-vars bufnr {:buflisted false})
          (if (not (psl.empty? main.sldb.buffers))
              (nvim_win_set_buf
                main.sldb.id (. main.sldb.buffers
                                (length main.sldb.buffers)))
              (nvim_win_close main.sldb.id true)))))))

;;; string {any} -> [WinID BufNr]
(fn sldb.open [content config]
  (let [bufnr (buffer.create-if-not-exists
                (buffer.gen-sldb-name
                  config.conn-name config.thread)
                true
                #(buf-callback $ config))]
    [(main.sldb:open bufnr true) bufnr]))

sldb
