"Event handlers for server events — migrated from autoload/nvlime/ui.vim lines 125-239.
Extends the ui table from core/ui.fnl with on-* methods.
Also exports private callbacks used by input buffer completion."

(local {: nvim_create_autocmd
        : nvim_buf_set_var}
       vim.api)

(local {: luaeval
        : cursor}
       vim.fn)

(local call vim.fn.call)
(local ui (require "nvlime.core.ui"))
(local connection (require "nvlime.core.connection"))
(local xref (require "nvlime.core.ui.xref"))

;;; ============================================================================
;;; Private callbacks — exported for input buffer completion
;;; ============================================================================
;;; These were s:ReturnMiniBufferContent and s:ReadStringInputComplete in ui.vim.
;;; They are called by the input buffer's completion callback and need to access
;;; b:nvlime_conn and the current buffer content.

(fn return-mini-buffer-content [thread ttag]
  "Returns minibuffer content to Lisp via conn.Return.
  Called when user submits input from minibuffer."
  (let [content (ui.cur-buffer-content false)]
    (call (. vim.b.nvlime_conn :Return)
          [thread ttag content])))

(fn return-string-input-complete [thread ttag]
  "Returns string input to Lisp via conn.ReturnString.
  Ensures content ends with newline before sending."
  (let [content (ui.cur-buffer-content false)
        content (if (and (> (length content) 0)
                         (not= (. content (length content)) "\n"))
                  (.. content "\n")
                  content)]
    (call (. vim.b.nvlime_conn :ReturnString)
          [thread ttag content])))
;;; ============================================================================
;;; Debug events
;;; ============================================================================

(fn ui.on-debug [self conn thread level condition restarts frames conts]
  "Opens SLDB window and fills buffer with debugger state.
  Called when the Lisp debugger is activated."
  (let [[_ bufnr] (luaeval
                    "require('nvlime.window.main.sldb').open(_A[1], _A[2])"
                    [[]
                     {:conn-name (. (. conn :cb_data) :name)
                      :thread thread
                      :frames frames
                      :level level}])]
    (ui.with-buffer
      bufnr
      (fn []
        (call (. vim.fn "nvlime#ui#sldb#FillSLDBBuf")
              [thread level condition restarts frames])))))

(fn ui.on-debug-activate [self conn thread level select]
  "Opens SLDB window and positions cursor.
  Called when debugger frame is selected."
  (let [[_ bufnr] (luaeval
                    "require('nvlime.window.main.sldb').open(_A[1], _A[2])"
                    [[]
                     {:conn-name (. (. conn :cb_data) :name)
                      :thread thread}])]
    (when (> bufnr 0)
      (cursor [1 1 0 1]))))

(fn ui.on-debug-return [self conn thread level stepping]
  "Closes SLDB window when debugger returns.
  Delegates to sldb module."
  (luaeval
    "require('nvlime.window.main.sldb')['on-debug-return'](_A)"
    {:conn-name (. (. conn :cb_data) :name)
     :thread thread
     :level level}))

;;; ============================================================================
;;; REPL I/O events
;;; ============================================================================

(fn ui.on-write-string [self conn str str-type thread]
  "Writes str to REPL buffer.
  If thread is provided, sends WRITE-DONE back to server."
  (luaeval
    "require('nvlime.window.main.repl').open(_A[1], _A[2])"
    [str {:conn-name (. (. conn :cb_data) :name)}])
  (when thread
    (conn:send
      [(connection.kw "NVLIME-RAW-MSG")
       (.. "(:WRITE-DONE " thread ")")]
      nil)))

(fn ui.on-read-string [self conn thread ttag]
  "Opens input buffer for string input from Lisp."
  (call (. vim.fn "nvlime#ui#input#FromBuffer")
        [conn "Input string:" nil
         (fn [] (return-mini-buffer-content thread ttag))]))

(fn ui.on-read-from-minibuffer
     [self conn thread ttag prompt init-val]
  "Opens input buffer with prompt for minibuffer-style input."
  (call (. vim.fn "nvlime#ui#input#FromBuffer")
        [conn prompt init-val
         (fn [] (return-string-input-complete thread ttag))]))

;;; ============================================================================
;;; Editor state events
;;; ============================================================================

(fn ui.on-indentation-update [self conn indent-info]
  "Updates indentation info on connection.
  indent-info is a list of [symbol indent-info] pairs."
  (when (not (. (. conn :cb_data) :indent-info))
    (tset (. conn :cb_data) :indent-info {}))
  (each [_ i (ipairs indent-info)]
    (tset (. (. conn :cb_data) :indent-info)
          (. i 1)
          [(or (. i 2) nil) (or (. i 3) nil)])))

(fn ui.on-new-features [self conn new-features]
  "Updates connection features list."
  (tset (. conn :cb_data) :features
        (if new-features new-features [])))

(fn ui.on-invalid-rpc [self conn rpc-id err-msg]
  "Shows error for invalid RPC call."
  (ui.err-msg err-msg))

;;; ============================================================================
;;; Inspector event
;;; ============================================================================

(fn ui.on-inspect [self conn content thread tag]
  "Opens inspector window with Lisp object content.
  If thread and tag are provided, sets up autocmd to return nil on buffer leave."
  (let [[_ bufnr] (luaeval
                    "require('nvlime.window.inspector').open(_A)"
                    content)]
    (when thread
      (self:set-current-thread thread bufnr)
      (when tag
        (let [ret-callback
               (fn []
                 (call (. vim.b.nvlime_conn :Return)
                       [thread tag nil]))]
          (nvim_create_autocmd
            "BufWinLeave"
            {:buffer bufnr
             :once true
             :callback ret-callback}))))))

;;; ============================================================================
;;; Trace dialog event
;;; ============================================================================

(fn ui.on-trace-dialog [self conn spec-list trace-count]
  "Opens trace dialog window."
  (let [trace-buf (call
                    (. vim.fn "nvlime#ui#trace_dialog#InitTraceDialogBuf")
                    [conn])]
    (ui.open-buffer-with-win-settings trace-buf false "trace")
    (call (. vim.fn "nvlime#ui#trace_dialog#FillTraceDialogBuf")
          [spec-list trace-count])))

;;; ============================================================================
;;; Cross-reference event
;;; ============================================================================

(fn ui.on-xref [self conn xref-list]
  "Opens cross-reference window.
  Shows error if xref-list is null or not implemented."
  (cond
    (not xref-list)
    (ui.err-msg "No xref found.")

    (and (= (type xref-list) "table")
         (= (. xref-list "name") "NOT-IMPLEMENTED"))
    (ui.err-msg "Not implemented.")

    :else
    (xref.open-xref-buf conn xref-list)))

;;; ============================================================================
;;; Compiler notes event
;;; ============================================================================

(fn ui.on-compiler-notes [self conn note-list orig-win]
  "Opens compiler notes window and fills with notes."
  (when (not note-list)
    (values))
  (let [[_ bufnr] (luaeval
                    "require('nvlime.window.main.notes').open(_A)"
                    {:conn-name (. (. conn :cb_data) :name)})]
    (nvim_buf_set_var bufnr "nvlime_notes_orig_win" orig-win)
    (nvim_buf_set_var bufnr "nvlime_conn" conn)
    (call (. vim.fn "nvlime#ui#compiler_notes#FillCompilerNotesBuf")
          [note-list])))

;;; ============================================================================
;;; Threads event
;;; ============================================================================

(fn ui.on-threads [self conn thread-list]
  "Opens threads window.
  Shows error if thread-list is empty."
  (when (not thread-list)
    (ui.err-msg "The thread list is empty.")
    (values))
  (call (. vim.fn "nvlime#ui#threads#FillThreadsBuf")
        [conn thread-list]))


;;; ============================================================================
;;; Module export
;;; ============================================================================

;;; Hyphen/underscore compatibility for VimScript shim
(setmetatable ui
  {:__index (fn [self key]
              (. self (string.gsub key "_" "-")))})

ui
