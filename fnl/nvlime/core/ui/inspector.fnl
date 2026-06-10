"Inspector module — Fennel migration of autoload/nvlime/ui/inspector.vim (159 lines).
Provides inspector buffer interactions: select, navigate, REPL send, source lookup."

(local {: nvim_win_close}
       vim.api)

(local {: getcurpos
          : setpos}
       vim.fn)

(local ui (require "nvlime.core.ui"))

(local inspector {})

;;; ============================================================================
;;; Private helpers
;;; ============================================================================

(fn inspector.get-cur-coord []
  "Find the coordinate region under the current cursor position.
  Returns the coordinate table or nil if none matches."
  (let [cur-pos (getcurpos)
        line (. cur-pos 2)
        col (. cur-pos 3)]
    (var coord nil)
    (each [_ c (ipairs vim.b.nvlime_inspector_coords)]
      (when ((. vim.fn "nvlime#ui#MatchCoord") c line col)
        (set coord c)
        (return)))
    coord))

(fn inspector.on-inspector-pop-complete [which conn result]
  "Callback for InspectorPop/InspectorNext.
  which: 'previous' or 'next' (for error message context)
  conn: connection object
  result: inspector content or nil if no previous/next object."
  (if (not result)
      (ui.err-msg (.. "No " which " object."))
      ((. (: conn :ui) :OnInspect) conn result nil nil)))

(fn inspector.inspector-fetch-all-cb [acc conn result]
  "Recursive callback for fetching all inspector content in chunks.
  acc: accumulator table with :title and :content [items len start end]
  conn: connection object
  result: [items count start end] from InspectorRange."
  (let [new-items (. result 1)]
    (when new-items
      (each [_ item (ipairs new-items)]
        (table.insert (. acc :content 1) item))))
  (let [content (. acc :content)
        total-count (. result 2)
        cur-start (. result 3)
        fetched-end (. result 4)]
    (if (> total-count fetched-end)
        ;; More content to fetch
        (let [range-size (- fetched-end cur-start)]
          (: conn :InspectorRange
             fetched-end
             (+ fetched-end range-size)
             (fn [c r]
               (inspector.inspector-fetch-all-cb acc c r))))
        ;; All content fetched
        (do
          (tset content 2 (length (. content 1)))
          (tset content 4 (. content 2))
          (let [full-content [{"name" "TITLE" "package" "KEYWORD"}
                              (. acc :title)
                              {"name" "CONTENT" "package" "KEYWORD"}
                              content]]
            ((. (: conn :ui) :OnInspect) conn full-content nil nil)
            (vim.cmd "echom 'Done fetching inspector content.'"))))))

(fn inspector.find-source-cb [edit-cmd conn msg]
  "Callback for FindSourceLocationForEmacs.
  edit-cmd: Vim edit command (e.g., 'hide edit')
  conn: connection object
  msg: source location result or error."
  (let [pcall-result (pcall (fn []
                              (let [loc ((. vim.fn "nvlime#ParseSourceLocation") msg)]
                                ((. vim.fn "nvlime#GetValidSourceLocation") loc))))
        valid-loc (if (. pcall-result 1)
                    (. pcall-result 2)
                    [])]
    (if (. valid-loc 2)
        ;; Valid location found — navigate to source
        (do
          (nvim_win_close 0 true)
          (ui.show-source conn valid-loc edit-cmd))
        ;; Check for error or no source
        (if (and msg
                 (= (. msg 1 "name") "ERROR"))
            (ui.err-msg (. msg 2))
            (ui.err-msg "No source available.")))))

;;; ============================================================================
;;; Public API
;;; ============================================================================

(fn inspector.inspector-select []
  "Handle selection of an interactable field under the cursor.
  Supports ACTION (call action), VALUE (inspect part), and RANGE (navigate pages)."
  (let [coord (inspector.get-cur-coord)]
    (when (not coord)
      (return))

    (case coord.type
      "ACTION"
      (: vim.b.nvlime_conn
         :InspectorCallNthAction
         coord.id
         (fn [c r]
           ((. (: c :ui) :OnInspect) c r nil nil)))

      "VALUE"
      (: vim.b.nvlime_conn
         :InspectNthPart
         coord.id
         (fn [c r]
           ((. (: c :ui) :OnInspect) c r nil nil)))

      "RANGE"
      (let [range-size (- vim.b.nvlime_inspector_content_end
                          vim.b.nvlime_inspector_content_start)
            build-content (fn [content]
                            [{"name" "TITLE" "package" "KEYWORD"}
                             vim.b.nvlime_inspector_title
                             {"name" "CONTENT" "package" "KEYWORD"}
                             content])]
        (if (> coord.id 0)
            ;; Next range
            (let [next-start vim.b.nvlime_inspector_content_end
                  next-end (+ vim.b.nvlime_inspector_content_end range-size)]
              (: vim.b.nvlime_conn
                 :InspectorRange
                 next-start
                 next-end
                 (fn [c r]
                   ((. (: c :ui) :OnInspect) c (build-content r) nil nil))))
            (< coord.id 0)
            ;; Previous range
            (let [next-start (vim.fn.max [0 (- vim.b.nvlime_inspector_content_start range-size)])
                  next-end vim.b.nvlime_inspector_content_start]
              (: vim.b.nvlime_conn
                 :InspectorRange
                 next-start
                 next-end
                 (fn [c r]
                   ((. (: c :ui) :OnInspect) c (build-content r) nil nil))))
            ;; Fetch all content
            (do
              (vim.cmd "echom 'Fetching all inspector content, please wait...'")
              (let [acc {:title vim.b.nvlime_inspector_title
                         :content [[] 0 0 0]}]
                (: vim.b.nvlime_conn
                   :InspectorRange
                   0
                   range-size
                   (fn [c r]
                     (inspector.inspector-fetch-all-cb acc c r)))))))

      ;; Unknown type — no-op
      _ nil)))

(fn inspector.send-cur-value-to-repl []
  "Send the value under the cursor to the REPL.
  Only works on VALUE-type coordinates."
  (let [coord (inspector.get-cur-coord)]
    (when (or (not coord)
              (!= coord.type "VALUE"))
      (return))

    (let [conn vim.b.nvlime_conn]
      ((. (: conn :ui) :OnWriteString)
       conn
       "--\n"
       {"name" "REPL-SEP" "package" "KEYWORD"})
      (: conn
         :WithThread
         {"name" "REPL-THREAD" "package" "KEYWORD"}
         (fn []
           ((. conn :ListenerEval)
            (.. "(nth-value 0 (swank:inspector-nth-part " coord.id "))")
            nil))))))

(fn inspector.send-cur-inspectee-to-repl []
  "Send the currently inspected object to the REPL."
  (let [conn vim.b.nvlime_conn]
    ((. (: conn :ui) :OnWriteString)
     conn
     "--\n"
     {"name" "REPL-SEP" "package" "KEYWORD"})
    (: conn
       :WithThread
       {"name" "REPL-THREAD" "package" "KEYWORD"}
       (fn []
         ((. conn :ListenerEval)
          "(swank::istate.object swank::*istate*)"
          nil)))))

(fn inspector.find-source [type ...]
  "Find and open the source location for the inspector object.
  type: 'inspectee' (current object) or 'part' (value under cursor)
  edit-cmd: Vim edit command (default: 'hide edit')."
  (let [edit-cmd (or (select 1 ...) "hide edit")
        conn vim.b.nvlime_conn]
    (if (= type "inspectee")
        (: conn
           :FindSourceLocationForEmacs
           ["INSPECTOR" 0]
           (fn [c msg]
             (inspector.find-source-cb edit-cmd c msg)))
        (= type "part")
        (let [coord (inspector.get-cur-coord)]
          (when (or (not coord)
                    (!= coord.type "VALUE"))
            (return))
          (: conn
             :FindSourceLocationForEmacs
             ["INSPECTOR" coord.id]
             (fn [c msg]
               (inspector.find-source-cb edit-cmd c msg))))
        ;; Unknown type
        (ui.err-msg (.. "Unknown source type: " type)))))

(fn inspector.next-field [forward]
  "Navigate to the next/previous interactable coordinate.
  forward: true for next, false for previous.
  Wraps around to first coordinate if none found in direction."
  (when (<= (length vim.b.nvlime_inspector_coords) 0)
    (return))

  (let [cur-pos (getcurpos)
        sorted-coords ((. vim.fn "nvlime#ui#CoordSorter")
                        (vim.fn.copy vim.b.nvlime_inspector_coords)
                        forward)]
    (var next-coord ((. vim.fn "nvlime#ui#FindNextCoord")
                     [(. cur-pos 2) (. cur-pos 3)]
                     sorted-coords
                     forward))
    (set next-coord (or next-coord (. sorted-coords 1)))
    (let [begin (. next-coord :begin)]
      (setpos "." [0 (. begin 1) (. begin 2) 0 (. begin 2)]))))

(fn inspector.inspector-pop []
  "Navigate to the previously inspected object."
  (: vim.b.nvlime_conn
     :InspectorPop
     (fn [conn result]
       (inspector.on-inspector-pop-complete "previous" conn result))))

(fn inspector.inspector-next []
  "Navigate to the next inspected object."
  (: vim.b.nvlime_conn
     :InspectorNext
     (fn [conn result]
       (inspector.on-inspector-pop-complete "next" conn result))))

;;; ============================================================================
;;; Module export
;;; ============================================================================

inspector
