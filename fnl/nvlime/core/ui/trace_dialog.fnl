;;; nvlime.core.ui.trace_dialog --- Trace dialog buffer interactions.
;; Migrated from autoload/nvlime/ui/trace_dialog.vim (620 lines).
;; Provides trace dialog buffer management: init, fill, refresh, select,
;; navigation, and fold support.

(local {: bufnr
          : getline
          : line
          : getcurpos
          : setpos
          : matchlist
          : getpid
          : getbufvar
          : setbufvar
          : index
          : copy}
       vim.fn)

(local ui (require "nvlime.core.ui"))

(local trace-dialog {})

;;; ============================================================================
;;; Module-level constants
;;; ============================================================================

(local indent-level-width 2)
;; Vim regex pattern for trace entry fold detection
(local trace-entry-fold-pattern "^\\(\\s*\\d*[[:space:]|]\\+\\)\\(`-\\)\\|\\( >\\)\\|\\( <\\)")
(var next-fetch-key 0)

;;; ============================================================================
;;; Private helpers
;;; ============================================================================

(fn trace-dialog.init-trace-dialog-buffer []
  "Set buffer-local options for trace dialog."
  (vim.cmd (.. "setlocal shiftwidth=" indent-level-width))
  (vim.cmd "setlocal foldtext=nvlime#ui#trace_dialog#BuildFoldText(v:foldstart)")
  (vim.cmd "setlocal foldexpr=nvlime#ui#trace_dialog#CalcFoldLevel(v:lnum)")
  (vim.cmd "setlocal foldmethod=expr"))

(fn trace-dialog.add-button [buttons-str name co-type co-id cur-line coords]
  "Add a button coordinate entry and return the concatenated button string."
  (let [button-begin [cur-line (+ (length buttons-str) 1)]
        buttons-str (.. buttons-str name)
        button-end [cur-line (length buttons-str)]]
    (table.insert coords {:begin button-begin :end button-end
                          :type co-type :id co-id})
    buttons-str))

(fn trace-dialog.calc-line-range-shift [new old]
  "Calculate the line delta between new and old line ranges."
  (if (not old)
      0
      (- (. new 2) (. old 2))))

(fn trace-dialog.shift-line-range [line-range delta]
  "Shift a line range by delta. Returns nil if line-range is nil."
  (if (not line-range)
      nil
      [(+ (. line-range 1) delta) (+ (. line-range 2) delta)]))

(fn trace-dialog.get-cur-coord []
  "Return the coordinate object under the cursor, or nil."
  (let [cur-pos (getcurpos)
        cur-line (. cur-pos 1)
        cur-col (. cur-pos 2)]
    (cond
      ;; Check specs region
      (and vim.b.nvlime_trace_specs_line_range
           (>= cur-line (. vim.b.nvlime_trace_specs_line_range 1))
           (<= cur-line (. vim.b.nvlime_trace_specs_line_range 2)))
      (let [line-delta (- (. vim.b.nvlime_trace_specs_line_range 1) 1)
            shifted-line (- cur-line line-delta)]
        (each [_ c (ipairs vim.b.nvlime_trace_specs_coords)]
          (when ((. vim.fn "nvlime#ui#MatchCoord") c shifted-line cur-col)
            (return c)))
        nil)

      ;; Check entries header region
      (and vim.b.nvlime_trace_entries_header_line_range
           (>= cur-line (. vim.b.nvlime_trace_entries_header_line_range 1))
           (<= cur-line (. vim.b.nvlime_trace_entries_header_line_range 2)))
      (let [line-delta (- (. vim.b.nvlime_trace_entries_header_line_range 1) 1)
            shifted-line (- cur-line line-delta)]
        (each [_ c (ipairs vim.b.nvlime_trace_entries_header_coords)]
          (when ((. vim.fn "nvlime#ui#MatchCoord") c shifted-line cur-col)
            (return c)))
        nil)

      ;; Check entries region
      (and vim.b.nvlime_trace_entries_line_range
           (>= cur-line (. vim.b.nvlime_trace_entries_line_range 1))
           (<= cur-line (. vim.b.nvlime_trace_entries_line_range 2)))
      (let [line-delta (- (. vim.b.nvlime_trace_entries_line_range 1) 1)
            shifted-line (- cur-line line-delta)]
        (each [_ c (ipairs vim.b.nvlime_trace_entries_coords)]
          (when ((. vim.fn "nvlime#ui#MatchCoord") c shifted-line cur-col)
            (return c)))
        nil)

      :else nil)))

(fn trace-dialog.name-obj-to-str [name]
  "Convert a name object to a display string.
  Handles dict ({:package :name}) and list ([type ...]) cases."
  (if (. name :package)
      ;; Dict case: {:package :name}
      (.. (. name :package) "::" (. name :name))
      ;; List case: [type-element ...]
      (let [name-type-obj (. name 1)
            name-type-obj (cond
                            (= (. name-type-obj :package) "KEYWORD")
                            (.. ":" (. name-type-obj :name))

                            (= (. name-type-obj :package) "COMMON-LISP")
                            (. name-type-obj :name)

                            :else
                            (.. (. name-type-obj :package)
                                "::" (. name-type-obj :name)))]
        (var name-list [name-type-obj])
        (for [i 2 (length name)]
          (table.insert name-list
                        (trace-dialog.name-obj-to-str (. name i))))
        (.. "(" (table.concat name-list " ") ")"))))

(fn trace-dialog.arg-list-to-dict [arg-list]
  "Convert an argument list [[idx val] ...] to a dict {idx: val}."
  (let [arg-list (or arg-list [])
        args {}]
    (each [_ r (ipairs arg-list)]
      (tset args (. r 1) (. r 2)))
    args))

(fn trace-dialog.align-trace-id [id width]
  "Right-align trace id within the given width."
  (let [str-id (tostring id)]
    (.. (string.rep " " (- width (string.len str-id))) str-id)))

(fn trace-dialog.indent [str count]
  "Prepend count spaces before str."
  (.. (string.rep " " count) str))

(fn trace-dialog.construct-trace-entry-args
    [entry-id arg-dict prefix button-type cur-line coords]
  "Construct argument/retval lines for a trace entry.
  arg-dict keys are numeric strings. Returns [content cur-line] tuple."
  (var content "")
  (var cur-line cur-line)
  ;; Get keys sorted numerically
  (let [keys []]
    (for [k _ (pairs arg-dict)]
      (table.insert keys (tonumber k)))
    (table.sort keys)
    (each [_ i (ipairs keys)]
      (let [line (.. prefix
                     (trace-dialog.add-button
                       "" (. arg-dict (tostring i)) button-type
                       [entry-id i] cur-line coords)
                     "\n")]
        (set content (.. content line))
        (set cur-line (+ cur-line 1)))))
  [content cur-line])

(fn trace-dialog.draw-trace-entries [toplevel cached-entries coords ...]
  "Recursively draw trace entry tree.
  Isomeric: toplevel call returns nothing, nested calls return [content cur-line].
  Optional args: cur-level acc-content cur-line line-prefix id-width"
  (let [varargs [...]
        cur-level (or (. varargs 1) 0)
        acc-content (or (. varargs 2) "")
        cur-line (or (. varargs 3) 1)
        line-prefix (or (. varargs 4) "")]
    (var id-width (or (. varargs 5) nil))

    ;; Compute id-width on first call
    (when (not id-width)
      (let [keys []]
        (for [k _ (pairs cached-entries)]
          (table.insert keys (tonumber k)))
        (table.sort keys)
        (if (> (length keys) 0)
            (set id-width (string.len (tostring (. keys (length keys)))))
            (set id-width 0))))

    (var line-prefix line-prefix)
    (var next-line-prefix (.. line-prefix
                              (string.rep " " (- indent-level-width 1))
                              "|"))
    (var content "")
    (var cur-line cur-line)
    (let [line-range vim.b.nvlime_trace_entries_line_range
          first-line (if line-range
                       (. line-range 1)
                       (line "$"))
          last-line (if line-range
                      (. line-range 2)
                      (line "$"))]

      (for [i 1 (length toplevel)]
        (let [tid (. toplevel i)
              entry (. cached-entries tid)]

          ;; Adjust prefix for last element at non-top level
          (when (and (= tid (. toplevel (length toplevel)))
                     (> (length line-prefix) 0))
            (set line-prefix
                 (.. (string.sub line-prefix 1
                                 (- (string.len line-prefix) 2))
                     " "))
            (set next-line-prefix (.. line-prefix
                                      (string.rep " "
                                                  (- indent-level-width 1))
                                      "|")))

          (let [connector-char (if (= content "") " " "`")
                name-line (.. (trace-dialog.align-trace-id
                                (. entry :id) id-width)
                              line-prefix connector-char
                              (string.rep " " (- indent-level-width 1))
                              " "
                              (trace-dialog.name-obj-to-str (. entry :name))
                              "\n")]
            (set content (.. content name-line))
            (set cur-line (+ cur-line 1))

            ;; Compute arg_ret_prefix
            (let [arg-ret-prefix
                  (if (> (length (. entry :children)) 0)
                      (.. (string.rep " " id-width) next-line-prefix)
                      (.. (string.rep " " id-width)
                          (string.sub next-line-prefix 1
                                      (- (string.len next-line-prefix) 2))
                          " "))]

              ;; Args
              (let [[arg-content new-line]
                    (trace-dialog.construct-trace-entry-args
                      (. entry :id) (. entry :args)
                      (.. arg-ret-prefix " > ")
                      "TRACE-ENTRY-ARG" cur-line coords)]
                (set content (.. content arg-content))
                (set cur-line new-line))

              ;; Retvals
              (let [[ret-content new-line]
                    (trace-dialog.construct-trace-entry-args
                      (. entry :id) (. entry :retvals)
                      (.. arg-ret-prefix " < ")
                      "TRACE-ENTRY-RETVAL" cur-line coords)]
                (set content (.. content ret-content))
                (set cur-line new-line))

              ;; Children
              (when (> (length (. entry :children)) 0)
                (let [[child-content new-line]
                      (trace-dialog.draw-trace-entries
                        (. entry :children) cached-entries coords
                        (+ cur-level 1) content cur-line
                        next-line-prefix id-width)]
                  (set content child-content)
                  (set cur-line new-line)))))))

      ;; Toplevel vs nested return
      (if (= acc-content "")
          (do
            ;; Replace buffer content
            (let [old-cur-pos (getcurpos)
                  pcall-result (pcall (fn []
                                        (ui.replace-content content first-line last-line)))]
              (setpos "." old-cur-pos)
              (when (not (. pcall-result 1))
                (error (. pcall-result 2))))
            (set vim.b.nvlime_trace_entries_line_range
                 [first-line
                  (+ first-line
                     (length (vim.split content "\n" {:trimempty false}))
                     -1)]))
          [(.. acc-content content) cur-line]))))

(fn trace-dialog.draw-spec-list [spec-list coords]
  "Draw the spec list section of the trace dialog."
  (let [line-range vim.b.nvlime_trace_specs_line_range
        first-line (if line-range (. line-range 1) 1)
        last-line (if line-range (. line-range 2) (line "$"))
        spec-list (or spec-list [])
        title (.. "Traced (" (tostring (length spec-list)) ")")]
    (var content (.. title "\n"
                     (string.rep "=" (string.len title)) "\n\n"))
    (var cur-line 4)

    ;; Header buttons: [refresh] [untrace all]
    (let [header-buttons
          (trace-dialog.add-button
            (trace-dialog.add-button "" "[refresh]"
                                     "REFRESH-SPECS" nil cur-line coords)
            " " nil nil cur-line coords)]
      (set content (.. content
                       (trace-dialog.add-button
                         header-buttons "[untrace all]"
                         "UNTRACE-ALL-SPECS" nil cur-line coords)
                       "\n\n"))
      (set cur-line (+ cur-line 2)))

    ;; Spec entries
    (each [_ spec (ipairs spec-list)]
      (let [untrace-btn
            (trace-dialog.add-button
              "" "[untrace]" "UNTRACE-SPEC" spec cur-line coords)]
        (set content (.. content untrace-btn " "
                         (trace-dialog.name-obj-to-str spec) "\n"))
        (set cur-line (+ cur-line 1))))

    (set content (.. content "\n"))

    ;; Replace buffer content
    (let [old-cur-pos (getcurpos)
          pcall-result (pcall (fn []
                                (ui.replace-content content first-line last-line)))]
      (setpos "." old-cur-pos)
      (when (not (. pcall-result 1))
        (error (. pcall-result 2))))

    (set vim.b.nvlime_trace_specs_line_range
         [first-line
          (+ first-line
             (length (vim.split content "\n" {:trimempty false}))
             -1)])

    ;; Shift dependent line ranges
    (let [delta (trace-dialog.calc-line-range-shift
                  vim.b.nvlime_trace_specs_line_range line-range)]
      (set vim.b.nvlime_trace_entries_header_line_range
           (trace-dialog.shift-line-range
             vim.b.nvlime_trace_entries_header_line_range delta))
      (set vim.b.nvlime_trace_entries_line_range
           (trace-dialog.shift-line-range
             vim.b.nvlime_trace_entries_line_range delta)))))

(fn trace-dialog.draw-trace-entry-header [entry-count cached-entry-count coords]
  "Draw the trace entries header section."
  (let [line-range vim.b.nvlime_trace_entries_header_line_range
        first-line (if line-range (. line-range 1) (line "$"))
        last-line (if line-range (. line-range 2) (line "$"))
        title (.. "Trace Entries (" (tostring cached-entry-count) "/"
                     (tostring entry-count) ")")]
    (var content (.. title "\n"
                     (string.rep "=" (string.len title)) "\n\n"))
    (var cur-line 4)
    (var header-buttons
         (trace-dialog.add-button
           "" "[refresh]"
           "REFRESH-TRACE-ENTRY-HEADER" nil cur-line coords))
      (set header-buttons (.. header-buttons " "))

      (when (!= cached-entry-count entry-count)
        (set header-buttons
             (trace-dialog.add-button
               header-buttons "[fetch next batch]"
               "FETCH-NEXT-TRACE-ENTRIES-BATCH" nil cur-line coords))
        (set header-buttons (.. header-buttons " "))
        (set header-buttons
             (trace-dialog.add-button
               header-buttons "[fetch all]"
               "FETCH-ALL-TRACE-ENTRIES" nil cur-line coords))
        (set header-buttons (.. header-buttons " ")))

      (set header-buttons
           (trace-dialog.add-button
             header-buttons "[clear]"
             "CLEAR-TRACE-ENTRIES" nil cur-line coords))
    (set content (.. content header-buttons "\n\n"))

    ;; Replace buffer content
    (let [old-cur-pos (getcurpos)
          pcall-result (pcall (fn []
                                (ui.replace-content content first-line last-line)))]
      (setpos "." old-cur-pos)
      (when (not (. pcall-result 1))
        (error (. pcall-result 2))))

    (if (not line-range)
        (set vim.b.nvlime_trace_entries_header_line_range
             [first-line
              (+ first-line
                 (length (vim.split content "\n" {:trimempty false}))
                 -2)])
        (set vim.b.nvlime_trace_entries_header_line_range
             [first-line
              (+ first-line
                 (length (vim.split content "\n" {:trimempty false}))
                 -1)]))))

(fn trace-dialog.get-fetch-key []
  "Generate or return the current fetch key."
  (if (not vim.b.nvlime_trace_fetch_key)
      (let [fetch-key next-fetch-key]
        (set next-fetch-key (+ fetch-key 1))
        (when (> next-fetch-key 65535)
          (set next-fetch-key 0))
        (set vim.b.nvlime_trace_fetch_key
             (.. (tostring (getpid)) "_" (tostring fetch-key)))))
  vim.b.nvlime_trace_fetch_key)

(fn trace-dialog.reset-trace-entries []
  "Reset all trace entry state and clear the buffer region."
  (set vim.b.nvlime_trace_fetch_key nil)
  (set vim.b.nvlime_trace_cached_entries nil)
  (set vim.b.nvlime_trace_toplevel_entries nil)
  (set vim.b.nvlime_trace_max_id nil)
  (set vim.b.nvlime_trace_entries_coords nil)

  (let [line-range vim.b.nvlime_trace_entries_line_range]
    (set vim.b.nvlime_trace_entries_line_range nil)
    (when line-range
      (vim.cmd "setlocal modifiable")
      (vim.cmd (.. (. line-range 1) "," (. line-range 2) "delete _"))
      (vim.fn.append (- (. line-range 1) 1) "")
      (vim.cmd "setlocal nomodifiable"))))

;;; ============================================================================
;;; Callbacks
;;; ============================================================================

(fn trace-dialog.report-specs-complete [trace-buf conn result]
  "Callback for ReportSpecs — redraws spec list."
  (let [coords []]
    (setbufvar trace-buf :modifiable 1)
    (ui.with-buffer trace-buf
                    #(trace-dialog.draw-spec-list result coords))
    (setbufvar trace-buf :modifiable 0)
    (setbufvar trace-buf "nvlime_trace_specs_coords" coords)))

(fn trace-dialog.report-total-complete [trace-buf conn result]
  "Callback for ReportTotal — redraws trace entry header."
  (let [cached-entries (getbufvar trace-buf "nvlime_trace_cached_entries" {})
        coords []]
    (setbufvar trace-buf :modifiable 1)
    (ui.with-buffer trace-buf
                    #(trace-dialog.draw-trace-entry-header
                       result (length cached-entries) coords))
    (setbufvar trace-buf :modifiable 0)
    (setbufvar trace-buf "nvlime_trace_entries_header_coords" coords)))

(fn trace-dialog.dialog-untrace-all-complete [trace-buf conn result]
  "Callback for DialogUntraceAll — shows results and refreshes specs."
  (when result
    (each [_ r (ipairs result)]
      (print r)))
  (: conn :ReportSpecs
     #(trace-dialog.report-specs-complete trace-buf conn $1)))

(fn trace-dialog.dialog-untrace-complete [trace-buf conn result]
  "Callback for DialogUntrace — shows result and refreshes specs."
  (print result)
  (: conn :ReportSpecs
     #(trace-dialog.report-specs-complete trace-buf conn $1)))

(fn trace-dialog.report-partial-tree-complete [trace-buf fetch-all conn result]
  "Callback for ReportPartialTree — caches entries and optionally recurses."
  (let [[entry-list remaining fetch-key] result
        entry-list (or entry-list [])
        cached-entries (getbufvar trace-buf "nvlime_trace_cached_entries" {})
        toplevel-entries (getbufvar trace-buf
                                    "nvlime_trace_toplevel_entries" [])]
    (var max-id (getbufvar trace-buf "nvlime_trace_max_id" 0))

    ;; Process each entry
    (each [_ t-entry (ipairs entry-list)]
      (let [[id parent name arg-list retval-list] t-entry
            entry-obj (or (. cached-entries id)
                          {:id id :children []})]
        (set entry-obj.id id)
        (set entry-obj.parent parent)
        (set entry-obj.name name)
        (set entry-obj.args (trace-dialog.arg-list-to-dict arg-list))
        (set entry-obj.retvals (trace-dialog.arg-list-to-dict retval-list))

        (let [parent-obj (if parent
                           (. cached-entries parent)
                           nil)]
          (if (not parent-obj)
              ;; Top-level entry
              (when (< (index toplevel-entries id) 0)
                (table.insert toplevel-entries id))
              ;; Child entry
              (when (< (index (. parent-obj :children) id) 0)
                (table.insert (. parent-obj :children) id))))

        (set (. cached-entries id) entry-obj)
        (when (> id max-id)
          (set max-id id))))

    ;; Save state
    (setbufvar trace-buf "nvlime_trace_cached_entries" cached-entries)
    (setbufvar trace-buf "nvlime_trace_toplevel_entries" toplevel-entries)
    (setbufvar trace-buf "nvlime_trace_max_id" max-id)

    ;; Fetch more or render
    (if (and fetch-all (> remaining 0))
        (: conn :ReportPartialTree fetch-key
           #(trace-dialog.report-partial-tree-complete
              trace-buf fetch-all conn $1))
        (do
          (vim.cmd "setlocal modifiable")
          (let [header-coords []]
            (ui.with-buffer trace-buf
                            #(trace-dialog.draw-trace-entry-header
                               (+ (length cached-entries) remaining)
                               (length cached-entries)
                               header-coords))
            (setbufvar trace-buf
                       "nvlime_trace_entries_header_coords" header-coords))

          (let [entry-coords []]
            (ui.with-buffer trace-buf
                            #(trace-dialog.draw-trace-entries
                               toplevel-entries cached-entries entry-coords))
            (vim.cmd "setlocal nomodifiable")
            (setbufvar trace-buf
                       "nvlime_trace_entries_coords" entry-coords))))))

(fn trace-dialog.clear-trace-tree-complete [trace-buf conn result]
  "Callback for ClearTraceTree — resets entries and refreshes."
  (ui.with-buffer trace-buf trace-dialog.reset-trace-entries)
  (: conn :ReportTotal
     #(trace-dialog.report-total-complete trace-buf conn $1)))

;;; ============================================================================
;;; Public API
;;; ============================================================================

(fn trace-dialog.init-trace-dialog-buf [conn]
  "Initialize trace dialog buffer for connection. Returns buffer number."
  (let [[_win bufnr]
        (vim.fn.luaeval
          "require\"nvlime.window.trace\".open(_A[1], _A[2])"
          [[] {:conn-name (. (. conn :cb_data) :name)}])
        bufnr (tonumber bufnr)]
    (when (not (ui.nvlime-buffer-initialized bufnr))
      (setbufvar bufnr "nvlime_conn" conn)
      (ui.with-buffer bufnr trace-dialog.init-trace-dialog-buffer))
    bufnr))

(fn trace-dialog.fill-trace-dialog-buf [spec-list trace-count]
  "Fill trace dialog buffer with spec list and trace entry header."
  (vim.cmd "setlocal modifiable")

  (set vim.b.nvlime_trace_specs_coords [])
  (trace-dialog.draw-spec-list spec-list vim.b.nvlime_trace_specs_coords)

  (set vim.b.nvlime_trace_entries_header_coords [])
  (let [cached-entries (or vim.b.nvlime_trace_cached_entries {})]
    (trace-dialog.draw-trace-entry-header
      trace-count (length cached-entries)
      vim.b.nvlime_trace_entries_header_coords))

  (vim.cmd "setlocal nomodifiable"))

(fn trace-dialog.refresh-specs []
  "Request refreshed specs from the connection."
  (: vim.b.nvlime_conn :ReportSpecs
     #(trace-dialog.report-specs-complete
        (bufnr "%") vim.b.nvlime_conn $1)))

(fn trace-dialog.select [...]
  "Handle button click or trace entry inspection.
  Optional action: 'button' (default), 'inspect', or 'to_repl'."
  (let [varargs [...]
        action (or (. varargs 1) "button")
        coord (trace-dialog.get-cur-coord)]

    (when (not coord)
      (return))

    (if (= action "button")
        ;; Button actions
        (cond
          (= (. coord :type) "REFRESH-SPECS")
          (trace-dialog.refresh-specs)

          (= (. coord :type) "UNTRACE-ALL-SPECS")
          (: vim.b.nvlime_conn :DialogUntraceAll
             #(trace-dialog.dialog-untrace-all-complete
                (bufnr "%") vim.b.nvlime_conn $1))

          (= (. coord :type) "UNTRACE-SPEC")
          (: vim.b.nvlime_conn :DialogUntrace
             [((. vim.fn "nvlime#CL") "QUOTE") (. coord :id)]
             #(trace-dialog.dialog-untrace-complete
                (bufnr "%") vim.b.nvlime_conn $1))

          (= (. coord :type) "REFRESH-TRACE-ENTRY-HEADER")
          (: vim.b.nvlime_conn :ReportTotal
             #(trace-dialog.report-total-complete
                (bufnr "%") vim.b.nvlime_conn $1))

          (= (. coord :type) "FETCH-NEXT-TRACE-ENTRIES-BATCH")
          (: vim.b.nvlime_conn :ReportPartialTree
             (trace-dialog.get-fetch-key)
             #(trace-dialog.report-partial-tree-complete
                (bufnr "%") false vim.b.nvlime_conn $1))

          (= (. coord :type) "FETCH-ALL-TRACE-ENTRIES")
          (: vim.b.nvlime_conn :ReportPartialTree
             (trace-dialog.get-fetch-key)
             #(trace-dialog.report-partial-tree-complete
                (bufnr "%") true vim.b.nvlime_conn $1))

          (= (. coord :type) "CLEAR-TRACE-ENTRIES")
          (: vim.b.nvlime_conn :ClearTraceTree
             #(trace-dialog.clear-trace-tree-complete
                (bufnr "%") vim.b.nvlime_conn $1)))

        ;; Inspect/to_repl actions for trace entry args/retvals
        (or (= (. coord :type) "TRACE-ENTRY-ARG")
            (= (. coord :type) "TRACE-ENTRY-RETVAL"))
        (cond
          (= action "inspect")
          (let [part-type (if (= (. coord :type) "TRACE-ENTRY-ARG")
                            "ARG" "RETVAL")]
            (: vim.b.nvlime_conn :InspectTracePart
               (. (. coord :id) 1) (. (. coord :id) 2) part-type
               (fn [c r]
                 (. (. c :ui) :OnInspect c r nil nil))))

          (= action "to_repl")
          (let [part-type (if (= (. coord :type) "TRACE-ENTRY-ARG")
                            ":arg" ":retval")
                args-str (table.concat
                           [(tostring (. (. coord :id) 1))
                            (tostring (. (. coord :id) 2))
                            part-type]
                           " ")]
            (: (. vim.b.nvlime_conn :ui) :OnWriteString
               vim.b.nvlime_conn
               "--\n"
               {:name "REPL-SEP" :package "KEYWORD"})
            (: vim.b.nvlime_conn :WithThread
               {:name "REPL-THREAD" :package "KEYWORD"}
               (fn []
                 (: vim.b.nvlime_conn
                    :ListenerEval
                    (.. "(nth-value 0 (swank-trace-dialog:find-trace-part "
                        args-str "))")))))))))

(fn trace-dialog.next-field [forward]
  "Navigate to the next interactive field.
  forward: true for forward, false for backward."
  (let [cur-pos (getcurpos)
        dir-int (if forward 1 0)

        ;; Build coord groups using vim.b temp var + vim.fn.eval for sort
        coord-specs [vim.b.nvlime_trace_specs_line_range
                     (do
                       (set vim.b._nvlime_tmp_coords
                            (copy vim.b.nvlime_trace_specs_coords))
                       (vim.fn.eval
                         (.. "sort(b:_nvlime_tmp_coords, "
                             "function('nvlime#ui#CoordSorter', ["
                             dir-int "]))")))]
        coord-header [vim.b.nvlime_trace_entries_header_line_range
                      (do
                        (set vim.b._nvlime_tmp_coords
                             (copy vim.b.nvlime_trace_entries_header_coords))
                        (vim.fn.eval
                          (.. "sort(b:_nvlime_tmp_coords, "
                              "function('nvlime#ui#CoordSorter', ["
                              dir-int "]))")))]
        coord-entries [vim.b.nvlime_trace_entries_line_range
                       (do
                         (set vim.b._nvlime_tmp_coords
                              (copy vim.b.nvlime_trace_entries_coords))
                         (vim.fn.eval
                           (.. "sort(b:_nvlime_tmp_coords, "
                               "function('nvlime#ui#CoordSorter', ["
                               dir-int "]))")))]

        coord-groups [coord-specs coord-header coord-entries]]
    (var coord-groups coord-groups)

    (when (not forward)
      (let [reversed []]
        (for [i (length coord-groups) 1 -1]
          (table.insert reversed (. coord-groups i)))
        (set coord-groups reversed)))

    (var next-coord nil)
    (var next-line-range nil)

    ;; Find next coordinate across groups
    (each [_ group (ipairs coord-groups)]
      (let [line-range (. group 1)
            sorted-coords (. group 2)]
        (when line-range
          (let [shifted-line (- (. cur-pos 1) (. line-range 1) -1)
                found ((. vim.fn "nvlime#ui#FindNextCoord")
                        [shifted-line (. cur-pos 2)]
                        sorted-coords forward)]
            (when found
              (set next-coord found)
              (set next-line-range line-range)
              (return))))))

    ;; Wrap around to first coord if none found
    (when (not next-coord)
      (each [_ group (ipairs coord-groups)]
        (let [sorted-coords (. group 2)]
          (when (> (length sorted-coords) 0)
            (set next-coord (. sorted-coords 1))
            (set next-line-range (. group 1))
            (return)))))

    ;; Move cursor
    (when (and next-coord next-line-range)
      (let [next-line (+ (. (. next-coord :begin) 1)
                         (. next-line-range 1) -1)
            next-col (. (. next-coord :begin) 2)]
        (setpos "." [0 next-line next-col 0 next-col])))))

(fn trace-dialog.calc-fold-level [...]
  "Calculate fold level for the given line (for foldexpr).
  Optional arg: line_nr (defaults to v:lnum)."
  (let [varargs [...]
        line-nr (or (. varargs 1) vim.v.lnum)
        line-text (getline line-nr)
        matched (matchlist line-text trace-entry-fold-pattern)]
    (if (> (length matched) 0)
        (let [id-width (if vim.b.nvlime_trace_max_id
                         (string.len (tostring vim.b.nvlime_trace_max_id))
                         0)]
          (math.floor (/ (- (string.len (. matched 2)) id-width) 2)))
        0)))

(fn trace-dialog.build-fold-text [...]
  "Build fold text for the given fold start (for foldtext).
  Optional arg: fold-start (defaults to v:foldstart)."
  (let [varargs [...]
        fold-start (or (. varargs 1) vim.v.foldstart)
        s-line (getline fold-start)
        matched (matchlist s-line trace-entry-fold-pattern)]
    (if (> (length matched) 0)
        (.. (. matched 2) " ")
        "...")))

;;; ============================================================================
;;; Module exports
;;; ============================================================================

;;; Hyphen/underscore compatibility for VimScript shim
(setmetatable trace-dialog
  {:__index (fn [self key]
              (. self (string.gsub key "_" "-")))})

trace-dialog
