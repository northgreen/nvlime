"Threads module — Fennel migration of autoload/nvlime/ui/threads.vim (127 lines).
Provides thread list display and management for nvlime."

(local {: luaeval
        : getline
        : cursor
        : setbufvar
        : setpos
        : getcurpos
        : trim
        : split
        : input
        : strdisplaywidth}
       vim.fn)

(local ui (require "nvlime.core.ui"))

(local threads {})

;;; ============================================================================
;;; Private helpers
;;; ============================================================================

(fn threads.normalize-field-value [val]
  "Normalize a field value to string for display."
  (if (= (type val) "string")
      val
      (if (= (type val) "table")
          (. val "name")
          (tostring val))))

(fn threads.calc-field-width [field thread-list]
  "Calculate the maximum display width of a field across all threads."
  (var max-width 0)
  (each [_ thread (ipairs thread-list)]
    (let [str-width (strdisplaywidth
                      (threads.normalize-field-value (. thread (+ field 1))))]
      (when (> str-width max-width)
        (set max-width str-width))))
  max-width)

(fn threads.calc-all-field-widths [thread-list]
  "Calculate display widths for all fields in the thread list."
  (let [header (. thread-list 1)]
    (let [widths {}]
      (each [idx _ (pairs header)]
        (tset widths idx (threads.calc-field-width idx thread-list)))
      widths)))

(fn threads.create-thread-field [field-widths thread]
  "Create a formatted display string for a thread row."
  (var field "")
  (var idx 0)
  (each [_ column (ipairs thread)]
    (let [width (. field-widths (+ idx 1))
          n-str (threads.normalize-field-value column)]
      (if (> idx 0)
          (set field (.. field (ui.pad (.. vim.g.nvlime_vert_sep " " n-str)
                                       ""
                                       (+ width 2))))
          (set field (.. field (ui.pad (.. " " n-str)
                                       ""
                                       (+ width 1))))))
    (set idx (+ idx 1)))
  field)

;;; ============================================================================
;;; Public API
;;; ============================================================================

(fn threads.fill-threads-buf [conn thread-list]
  "Populate the threads buffer with the given thread list.
  conn: connection object
  thread-list: array of thread data rows (first row is header)"
  (let [field-widths (threads.calc-all-field-widths thread-list)
        horiz-sep vim.g.nvlime_horiz_sep]
    (var win-width 0)
    (each [_ w (ipairs field-widths)]
      (set win-width (+ win-width w)))
    (set win-width (+ win-width 8))

    (var header-line (threads.create-thread-field field-widths (. thread-list 1)))
    (var sep-line (.. (string.rep horiz-sep (+ (. field-widths 1) 1))
                      "─┼─"
                      (string.rep horiz-sep (. field-widths 2))
                      "─┼─"
                      (string.rep horiz-sep (+ (. field-widths 3) 1))))

    (var lines [header-line sep-line])
    (var coords {})
    (var idx 0)
    (for [i 2 (length thread-list)]
      (let [thread (. thread-list i)]
        (table.insert lines (threads.create-thread-field field-widths thread))
        (tset coords (. thread 1) idx)
        (set idx (+ idx 1))))

    (let [[_win-id buf-nr] (luaeval
                             "require(\"nvlime.window.threads\").open(_A[1], _A[2])"
                             [lines {:conn-name (. (. conn :cb_data) :name)}])]
      (setbufvar buf-nr "nvlime_thread_coords" coords)
      (cursor 3 1))))

(fn threads.interrupt-cur-thread []
  "Interrupt the thread on the current line."
  (let [id (tonumber (getline "."))]
    (when (> id 0)
      (vim.b.nvlime_conn :Interrupt id))))

(fn threads.kill-cur-thread []
  "Kill the thread on the current line, with user confirmation."
  (let [field (getline ".")
        id (tonumber field)]
    (when (> id 0)
      (let [parts (split field vim.g.nvlime_vert_sep)
            thread-name (trim (. parts 2) " " 0)
            coords vim.b.nvlime_thread_coords
            answer (input (.. "Kill thread \"" thread-name "\"? (y/n) "))]
        (if (ui.is-yes-string answer)
            (vim.b.nvlime_conn :KillNthThread (. coords id)
                               (fn [c _r] (threads.refresh c)))
            (ui.err-msg "Canceled."))))))

(fn threads.debug-cur-thread []
  "Debug the thread on the current line."
  (let [id (tonumber (getline "."))]
    (when (> id 0)
      (vim.b.nvlime_conn :DebugNthThread (. vim.b.nvlime_thread_coords id)))))

(fn threads.refresh [conn keep-cur-pos]
  "Asynchronously refresh the thread list.
  conn: connection object (nil for current buffer connection)
  keep-cur-pos: whether to restore cursor position after refresh (default: true)"
  (let [keep-cur-pos (or keep-cur-pos true)
        cur-pos (if keep-cur-pos (getcurpos) nil)
        conn (or conn vim.b.nvlime_conn)]
    (conn :ListThreads
          (fn [c result]
            (c.ui.OnThreads c result)
            (when cur-pos (setpos "." cur-pos))))))

;;; ============================================================================
;;; Module export
;;; ============================================================================

threads
