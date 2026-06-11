"MREPL module — Fennel migration of autoload/nvlime/ui/mrepl.vim (133 lines).
Provides MREPL buffer management: init, submit, clear, disconnect, interrupt."

(local {: bufnr
           : getline
           : setbufvar
           : getcurpos
           : setpos
           : searchpos
           : feedkeys}
          vim.fn)

(local {: nvim_buf_set_lines}
       vim.api)

(local ui (require "nvlime.core.ui"))
(local connection (require "nvlime.core.connection"))

(local mrepl {})

;;; ============================================================================
;;; Private helpers
;;; ============================================================================

(fn mrepl.show-prompt-or-result [content]
  "Append content to buffer, prepending newline if last line is non-empty."
  (let [last-line (getline "$")]
    (if (> (length last-line) 0)
        (ui.append-string (.. "\n" content))
        (ui.append-string content))))

(fn mrepl.show-banner [conn chan-obj]
  "Build and append MREPL banner with version, pid, and thread info."
  (var banner "MREPL - SWANK")
  (when (. (. conn :cb_data) :version)
    (set banner (.. banner " version " (. conn.cb_data :version))))
  (when (. (. conn :cb_data) :pid)
    (set banner (.. banner ", pid " (. conn.cb_data :pid))))
  (let [remote-chan-id (. chan-obj :mrepl :peer)
        remote-chan-obj (. conn :remote_channels remote-chan-id)]
    (set banner (.. banner ", thread " (. remote-chan-obj :mrepl :thread))))
  (let [banner-len (length banner)]
    (set banner (.. banner "\n" (string.rep "=" banner-len) "\n")))
  (ui.append-string banner))

(fn mrepl.init-mrepl-buf-internal [conn chan-obj]
  "Set local buffer options and show banner for MREPL buffer."
  (set vim.bo.autoindent false)
  (set vim.bo.cindent false)
  (set vim.bo.smartindent false)
  (set vim.bo.iskeyword "@,48-57,_,192-255,+,-,*,/,%,<,=,>,:,$,?,!,@-@,94")
  (set vim.bo.omnifunc "nvlime#plugin#CompleteFunc")
  (set vim.bo.indentexpr "nvlime#plugin#CalcCurIndent()")
  (mrepl.show-banner conn chan-obj))

(fn mrepl.kill-thread-complete [mrepl-buf conn _result]
  "Unload MREPL buffer and remove local/remote channels after kill."
  (let [local-chan (vim.fn.getbufvar mrepl-buf "nvlime_mrepl_channel" nil)]
    (when local-chan
      (vim.cmd (.. "bunload! " mrepl-buf))
      (conn:remove-remote-channel (. local-chan :mrepl :peer))
      (conn:remove-local-channel (. local-chan :id)))))

;;; ============================================================================
;;; Public API
;;; ============================================================================

(fn mrepl.init-mrepl-buf [conn chan-obj]
  "Initialize MREPL buffer for connection and channel.
  Returns buffer number."
  (let [mrepl-buf (bufnr (ui.mrepl-buf-name conn chan-obj) 1)]
    (when (not (ui.nvlime-buffer-initialized mrepl-buf))
      (ui.set-nvlime-buffer-opts mrepl-buf conn)
      (setbufvar mrepl-buf "nvlime_mrepl_channel" chan-obj)
      (setbufvar mrepl-buf "&filetype" "nvlime_mrepl")
      (ui.with-buffer mrepl-buf
                      #(mrepl.init-mrepl-buf-internal conn chan-obj)))
    mrepl-buf))

(fn mrepl.show-prompt [buf prompt]
  "Show prompt string at end of MREPL buffer.
  If buf is current, cursor goes to end of line."
  (ui.with-buffer buf #(mrepl.show-prompt-or-result prompt))
  (when (= (bufnr "%") buf)
    (vim.cmd "normal! G")
    (feedkeys "<End>" "n")))

(fn mrepl.show-result [buf result]
  "Show result string at end of MREPL buffer."
  (ui.with-buffer buf #(mrepl.show-prompt-or-result result)))

(fn mrepl.submit []
  "Extract code after last prompt and send to MREPL.
  Returns key sequence for caller (<CR> or <Esc>GA<CR>)."
  (let [read-mode (. vim.b.nvlime_mrepl_channel :mrepl :mode)]
    (if (= read-mode "EVAL")
        ;; EVAL mode: extract text after last prompt
        (let [prompt (let [chan-obj vim.b.nvlime_mrepl_channel]
                       (.. (. (. chan-obj :mrepl) :prompt 1) "> "))
              old-pos (getcurpos)]
          (vim.cmd "normal! G$")
          (let [eof-pos (getcurpos)
                insert-newline? (or (< (. old-pos 1) (. eof-pos 1))
                                    (and (= (. old-pos 1) (. eof-pos 1))
                                         (<= (. old-pos 2) (. eof-pos 2))))
                last-prompt-pos (searchpos (.. "\\V" prompt) "bcenW")]
            (setpos "." old-pos)
            (let [from-pos [(+ (. last-prompt-pos 1) 1)
                            (+ (. last-prompt-pos 2) 1)]
                  to-pos [(+ (. eof-pos 1) 0)
                          (+ (. eof-pos 2) 1)]
                  to-send (ui.get-text from-pos to-pos)
                  peer (. vim.b.nvlime_mrepl_channel :mrepl :peer)
                  msg (: vim.b.nvlime_conn
                         :EmacsChannelSend
                         peer
                         [(connection.kw "PROCESS") to-send])]
              (: vim.b.nvlime_conn :Send msg)
              (if insert-newline?
                  "<CR>"
                  "<Esc>GA<CR>"))))
        ;; READ mode: send last line
        (let [to-send (.. (getline "$") "\n")
              peer (. vim.b.nvlime_mrepl_channel :mrepl :peer)
              msg (: vim.b.nvlime_conn
                     :EmacsChannelSend
                     peer
                     [(connection.kw "PROCESS") to-send])]
          (: vim.b.nvlime_conn :Send msg)
          "<CR>"))))

(fn mrepl.clear []
  "Clear MREPL buffer and reinitialize with banner and prompt."
  (nvim_buf_set_lines 0 0 -1 false [])
  (mrepl.show-banner vim.b.nvlime_conn vim.b.nvlime_mrepl_channel)
  (let [prompt (let [chan-obj vim.b.nvlime_mrepl_channel]
                 (.. (. (. chan-obj :mrepl) :prompt 1) "> "))]
    (mrepl.show-prompt (bufnr "%") prompt)))

(fn mrepl.disconnect []
  "Kill the remote MREPL thread and unload buffer."
  (let [remote-chan-id (. vim.b.nvlime_mrepl_channel :mrepl :peer)
        remote-chan (. vim.b.nvlime_conn :remote_channels remote-chan-id)
        remote-thread (. remote-chan :mrepl :thread)
        cmd [(connection.kw "EMACS-REX")
             [(connection.sym "SWANK/BACKEND" "KILL-THREAD")
              [(connection.sym "SWANK/BACKEND" "FIND-THREAD")
               remote-thread]]
             nil
             true]]
    (: vim.b.nvlime_conn
       :Send cmd
       (fn [chan msg]
         (: vim.b.nvlime_conn
            :simple-send-cb
            #(mrepl.kill-thread-complete (bufnr "%") vim.b.nvlime_conn $2)
            "nvlime#ui#mrepl#Disconnect"
            chan msg)))))

(fn mrepl.interrupt []
  "Interrupt the remote MREPL thread.
  Returns empty string for <C-r>= mapping compatibility."
  (let [remote-chan-id (. vim.b.nvlime_mrepl_channel :mrepl :peer)
        remote-chan (. vim.b.nvlime_conn :remote_channels remote-chan-id)]
    (: vim.b.nvlime_conn
       :Interrupt (. remote-chan :mrepl :thread)))
  "")

;;; ============================================================================
;;; Module export
;;; ============================================================================

mrepl
