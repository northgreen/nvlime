"SLDB module — Fennel migration of autoload/nvlime/ui/sldb.vim (498 lines).
Provides SLDB debugger buffer interactions: fill, restart, frame locals, source
lookup, eval, inspect, disassemble, return."

(local {: nvim_buf_set_option}
       vim.api)

(local {: luaeval
        : bufnr
        : getline
        : line
        : search
        : setpos
        : deletebufline
        : inputlist
        : win_id2win
        : win_gotoid
        : matchlist}
       vim.fn)

(local ui (require "nvlime.core.ui"))
(local buffer (require "nvlime.buffer"))
(local input (require "nvlime.core.ui.input"))

(local sldb {})

;;; ============================================================================
;;; Private helpers
;;; ============================================================================

(fn sldb.find-max-restart-name-len [restarts]
  "Find the maximum restart name length and whether any has a leading asterisk.
  restarts: array of [name description] pairs (1-indexed in Lua).
  Returns [max-name-len has-star] tuple."
  (var max-name-len 0)
  (var has-star false)
  (each [_ r (ipairs restarts)]
    (let [name (. r 1)]
      (if (= (. name 1) "*")
          (do
            (set has-star true)
            (let [name-len (- (length name) 1)]
              (when (> name-len max-name-len)
                (set max-name-len name-len))))
          (let [name-len (length name)]
            (when (> name-len max-name-len)
               (set max-name-len name-len))))))
  [max-name-len has-star])

(fn sldb.format-restart-line [r max-name-len has-star]
  "Format a single restart line for display.
  r: [name description] pair
  max-name-len: maximum name width for padding
  has-star: whether any restart has a leading asterisk
  Returns formatted string."
  (let [name (. r 1)
        desc (. r 2)
        has-star-prefix (= (. name 1) "*")]
    (if has-star
        (if has-star-prefix
            (let [pad (string.rep " "
                                  (+ (- max-name-len (- (length name) 1)) 1))]
              (.. " " name pad "- " desc))
            (let [pad (string.rep " "
                                  (+ (- max-name-len (length name)) 1))]
              (.. " " name pad "- " desc)))
        (let [pad (string.rep " "
                              (+ (- max-name-len (length name)) 1))]
          (.. " " name pad "- " desc)))))

(fn sldb.match-var-index []
  "Find the index of the variable under the cursor relative to the Locals header.
  Returns 0-based index (negative if not in a locals section)."
  (let [loc (search "\\v^\\tLocals:$" "bnWz")
        this (line ".")]
    (- this loc -1)))

(fn sldb.match-var-name []
  "Extract the variable name from the current line.
  Returns variable name string or empty string."
  (let [matches (matchlist (getline ".") "\\v^\\t  ([^ ]+):\\s+")]
    (if (> (length matches) 0)
        (. matches 2)
        "")))

(fn sldb.match-file []
  "Extract file path and position from the current line.
  Returns [file position] pair or [0 0] if no match."
  (let [matches (matchlist (getline ".")
                           "\\v^\\tFile:\\s+(.*) ([0-9]+)$")]
    (if (> (length matches) 0)
        [(. matches 2) (. matches 3)]
        [0 0])))

(fn sldb.match-restart []
  "Extract restart number from the current line.
  Returns 0-based index or -1 if no match."
  (let [matches (matchlist (getline ".")
                           "\\v^  R\\s+([0-9]+)\\.\\s+\\*?[a-zA-Z\\-]+\\s+-\\s.+$")]
    (if (> (length matches) 0)
        (tonumber (. matches 2))
        -1)))

(fn sldb.match-frame-string [line]
  "Extract frame number from a line string.
  Returns 0-based index or -1 if no match."
  (let [matches (matchlist line "\\v^  F\\s+([0-9]+)\\.\\s")]
    (if (> (length matches) 0)
        (tonumber (. matches 2))
        -1)))

(fn sldb.match-frame [...]
  "Find the frame number at or before the cursor position.
  srch-backwards: if true, search backwards for frame header (default: false).
  Returns 0-based frame index or -1 if not found."
  (let [srch-backwards (or (select 1 ...) false)
        line (getline ".")
        fnd (sldb.match-frame-string line)]
    (if (or (> fnd -1) (not srch-backwards))
        fnd
        (let [lnr (search "\\v^[^\\t]" "bnWz")]
          (if (= lnr 0)
              -1
              (sldb.match-frame-string (getline lnr)))))))

(fn sldb.frame-restartable [frame]
  "Check if a frame is restartable.
  frame: [index name flags?] tuple.
  Returns true if restartable, false otherwise."
  (if (> (length frame) 2)
      (let [flags ((. vim.fn "nvlime#PListToDict") (. frame 3))]
        ((. vim.fn "nvlime#Get") flags "RESTARTABLE" false))
      false))

;;; ============================================================================
;;; Callbacks
;;; ============================================================================

(fn sldb.show-frame-locals-cb [frame restartable line conn result]
  "Callback for FrameLocalsAndCatchTags — appends locals and catch tags.
  frame: frame index (0-based)
  restartable: whether frame is restartable
  line: buffer line number to append after
  conn: connection object
  result: [locals catch-tags] pair"
  (var content "\n")
  (let [locals (. result 1)]
    (when locals
      (set content (.. content "\tLocals:\n"))
      (var rlocals [])
      (var max-name-len 0)
      (each [_ lc (ipairs locals)]
        (let [rlc ((. vim.fn "nvlime#PListToDict") lc)]
          (table.insert rlocals rlc)
          (let [rlc-l (length ((. vim.fn "nvlime#Get") rlc "NAME"))]
            (when (> rlc-l max-name-len)
              (set max-name-len rlc-l)))))
      (each [_ rlc (ipairs rlocals)]
        (set content
             (.. content
                 "\t  "
                 ((. vim.fn "nvlime#ui#Pad")
                  ((. vim.fn "nvlime#Get") rlc "NAME")
                  ":"
                  max-name-len)
                 ((. vim.fn "nvlime#Get") rlc "VALUE")
                 "\n"))))
    (let [catch-tags (. result 2)]
      (when catch-tags
        (set content (.. content "\tCatch tags:\n"))
        (each [_ ct (ipairs catch-tags)]
          (set content (.. content "\t  " ct "\n")))))
    (let [thread (conn :GetCurrentThread)
          buf (bufnr (ui.sldb-buf-name conn thread) false)]
      (ui.with-buffer buf
                      (fn []
                        (vim.cmd "setlocal modifiable")
                        (ui.append-string content line)
                        (vim.cmd "setlocal nomodifiable"))))))

(fn sldb.show-frame-source-location-cb [frame line conn result]
  "Callback for FrameSourceLocation — appends file location and snippet.
  frame: frame index (0-based)
  line: buffer line number to append after
  conn: connection object
  result: [type-name data] pair"
  (when (not (= (. result 1 "name") "LOCATION"))
    (ui.err-msg (. result 2))
    (return))

  (var snippet "")
  (var content "")

  (if (= (type (. result 2)) "table")
      ;; List result — parse as keyword list
      (let [r ((. vim.fn "nvlime#KeywordList2Dict")
               (vim.fn.slice result 1))]
        (when ((. vim.fn "nvlime#HasKey") r "SNIPPET")
          (set snippet ((. vim.fn "nvlime#Get") r "SNIPPET")))
        (when ((. vim.fn "nvlime#HasKey") r "SOURCE-FORM")
          (set snippet ((. vim.fn "nvlime#Get") r "SOURCE-FORM")))
        (when (and ((. vim.fn "nvlime#HasKey") r "FILE")
                   ((. vim.fn "nvlime#HasKey") r "POSITION"))
          (set content
               (.. content
                   "\n\tFile: "
                   ((. vim.fn "nvlime#Get") r "FILE")
                   " "
                   ((. vim.fn "nvlime#Get") r "POSITION")
                   "\n"))))
      ;; Simple position result
      (do
        (set content (.. content "\n\tPosition: " (. result 2) "\n"))
        (set snippet nil)))

  (when snippet
    (let [snippet-lines (vim.split snippet "\n" {:trimempty false})
          indented-lines []]
      (each [_ val (ipairs snippet-lines)]
        (table.insert indented-lines (.. "\t  " val)))
      (set content
           (.. content
               "\n\tSnippet:\n"
               (table.concat indented-lines "\n")
               "\n"))))

  (let [thread (conn :GetCurrentThread)
        buf (bufnr (ui.sldb-buf-name conn thread) false)]
    (ui.with-buffer buf
                    (fn []
                      (vim.cmd "setlocal modifiable")
                      (ui.append-string content line)
                      (vim.cmd "setlocal nomodifiable")))))

(fn sldb.open-frame-source-cb [edit-cmd win-to-go force-open conn result]
  "Callback for FrameSourceLocation — opens source file.
  edit-cmd: Vim edit command
  win-to-go: target window id
  force-open: whether to force open new window
  conn: connection object
  result: source location data"
  (let [pcall-result (pcall (fn []
                              (let [src-loc ((. vim.fn "nvlime#ParseSourceLocation") result)]
                                ((. vim.fn "nvlime#GetValidSourceLocation") src-loc))))
        valid-loc (if (. pcall-result 1)
                    (. pcall-result 2)
                    [])]
    (if (and (> (length valid-loc) 0)
             (. valid-loc 2))
        ;; Valid location found
        (do
          (when (> win-to-go 0)
            (when (<= (win_id2win win-to-go) 0)
              (return))
            (win_gotoid win-to-go))
          ((. vim.fn "nvlime#ui#ShowSource") conn valid-loc edit-cmd force-open))
        ;; Check for error or no source
        (if (and result
                 (= (. result 1 "name") "ERROR"))
            (ui.err-msg (. result 2))
            (ui.err-msg "No source available.")))))

(fn sldb.find-source-cb [edit-cmd win-to-go force-open frame conn msg]
  "Callback for FrameLocalsAndCatchTags — prompts for variable and finds source.
  edit-cmd: Vim edit command
  win-to-go: target window id
  force-open: whether to force open new window
  frame: frame index (0-based)
  conn: connection object
  msg: [locals catch-tags] pair"
  (let [locals (. msg 1)]
    (when (not locals)
      (ui.err-msg "No local variable.")
      (return))

    (var options [])
    (each [idx lc (ipairs locals)]
      (let [lc-dict ((. vim.fn "nvlime#PListToDict") lc)
            var-name ((. vim.fn "nvlime#Get") lc-dict "NAME")]
        (table.insert options
                      (.. (tostring idx) ". " var-name))))

    (vim.cmd "echohl Question")
    (vim.cmd "echom 'Which variable?'")
    (vim.cmd "echohl None")
    (let [nth-var (inputlist options)]
      (when (> nth-var 0)
        (conn :FindSourceLocationForEmacs
              ["SLDB" frame (- nth-var 1)]
              (fn [c r]
                (sldb.open-frame-source-cb edit-cmd win-to-go force-open c r)))
        (return)))
    (ui.err-msg "Canceled.")))

(fn sldb.inspect-in-cur-frame-input-complete [frame thread]
  "Callback for InspectVarInCurFrame input — inspects evaluated expression.
  frame: frame index (0-based)
  thread: thread id"
  (let [content (ui.cur-buffer-content true)]
    (if (> (length content) 0)
        (vim.b.nvlime_conn
         :WithThread
         thread
         (fn []
           (vim.b.nvlime_conn
            :InspectInFrame
            content
            frame
            (fn [c r]
              ((. (: c :ui) :OnInspect) c r nil nil)))))
        (ui.err-msg "Canceled."))))

(fn sldb.eval-string-in-cur-frame-input-complete [frame thread package]
  "Callback for EvalStringInCurFrame input — evaluates expression in frame.
  frame: frame index (0-based)
  thread: thread id
  package: current package"
  (let [content (ui.cur-buffer-content true)]
    (if (> (length content) 0)
        (vim.b.nvlime_conn
         :WithThread
         thread
         (fn []
           (vim.b.nvlime_conn
            :EvalStringInFrame
            content
            frame
            package
            (fn [c r]
              ((. (: c :ui) :OnWriteString) c (.. r "\n")
               {"name" "FRAME-EVAL-RESULT" "package" "KEYWORD"})))))
        (ui.err-msg "Canceled."))))

(fn sldb.send-value-in-cur-frame-to-repl-input-complete [frame thread package]
  "Callback for SendValueInCurFrameToREPL input — evals and sends to REPL.
  frame: frame index (0-based)
  thread: thread id
  package: current package"
  (let [content (ui.cur-buffer-content true)]
    (if (> (length content) 0)
        ;; Escape double quotes in content for embedding in Lisp reader macro
        (let [escaped-content (select 1 (string.gsub content "\"" "\\\""))
              eval-expr (.. "(setf cl-user::* #.(read-from-string \""
                            escaped-content
                            "\"))")]
          (vim.b.nvlime_conn
           :WithThread
           thread
           (fn []
             (vim.b.nvlime_conn
              :EvalStringInFrame
              eval-expr
              frame
              package
              (fn [c _r]
                (c :WithThread
                   {"name" "REPL-THREAD" "package" "KEYWORD"}
                   (fn []
                        ((. c :ListenerEval) "cl-user::*")))))))
          (ui.err-msg "Canceled."))))

(fn sldb.return-from-cur-frame-input-complete [frame thread]
  "Callback for ReturnFromCurFrame input — returns from frame with value.
  frame: frame index (0-based)
  thread: thread id"
  (let [content (ui.cur-buffer-content true)]
    (if (> (length content) 0)
        (vim.b.nvlime_conn
         :WithThread
         thread
         (fn []
           (vim.b.nvlime_conn
            :SLDBReturnFromFrame
            frame
            content)))
        (ui.err-msg "Canceled."))))

;;; ============================================================================
;;; Public API
;;; ============================================================================

(fn sldb.fill-sldb-buf [thread level condition restarts frames]
  "Populate the SLDB buffer with debugger state.
  thread: thread identifier string
  level: debugger level number
  condition: array of condition description strings
  restarts: array of [name description] pairs
  frames: array of [index name flags?] tuples"
  (vim.cmd "setlocal modifiable")
  ((. vim.fn "nvlime#ClearCurrentBuffer"))

  ;; Thread and level header
  ((. vim.fn "nvlime#ui#AppendString")
   (.. "Thread: " thread "; Level: " (tostring level) "\n\n"))

  ;; Condition description
  (var condition-str "")
  (each [_ c (ipairs condition)]
    (when (= (type c) "string")
      (set condition-str (.. condition-str c "\n"))))
  (set condition-str (.. condition-str "\n"))
  ((. vim.fn "nvlime#ui#AppendString") condition-str)

  ;; Restarts section
  (var restarts-str "Restarts:\n")
  (let [[max-name-len has-star] (sldb.find-max-restart-name-len restarts)
        max-digits (string.len (tostring (- (length restarts) 1)))]
    (for [ri 0 (- (length restarts) 1)]
      (let [r (. restarts (+ ri 1))
            idx-str ((. vim.fn "nvlime#ui#Pad") (tostring ri) "." max-digits)
            restart-line (sldb.format-restart-line r max-name-len has-star)]
        (set restarts-str
             (.. restarts-str "  R " idx-str restart-line "\n")))))
  (set restarts-str (.. restarts-str "\n"))
  ((. vim.fn "nvlime#ui#AppendString") restarts-str)

  ;; Frames section
  (var frames-str "Frames:\n")
  (let [max-digits (string.len (tostring (- (length frames) 1)))]
    (each [_ f (ipairs frames)]
      (let [idx-str ((. vim.fn "nvlime#ui#Pad") (tostring (. f 1)) "." max-digits)]
        (set frames-str (.. frames-str "  F " idx-str (. f 2) "\n")))))
  ((. vim.fn "nvlime#ui#AppendString") frames-str)

  (vim.cmd "setlocal nomodifiable"))

(fn sldb.choose-cur-restart []
  "Handle selection on current line: restart, frame details, or file source.
  Checks for restart number first, then frame number, then file position."
  (let [nth (sldb.match-restart)]
    (when (>= nth 0)
      (vim.b.nvlime_conn
       :InvokeNthRestartForEmacs
       vim.b.nvlime_sldb_level
       nth)
      (return)))

  (when (> (sldb.show-frame-details) -1)
    (return))

  (let [[fn-name pos] (sldb.match-file)]
    (when (> (length fn-name) 0)
      (sldb.open-frame-source))))

(fn sldb.show-frame-details []
  "Show or toggle frame locals for the frame under cursor.
  Returns 1 if frame was matched, -1 if not on a frame line."
  (let [nth (sldb.match-frame)]
    (when (< nth 0)
      (return -1))
    (let [cur-line (line ".")
          frame-line-pattern "^\\s*F \\d\\+\\|^\\%$"]
      (if (!= (vim.fn.match (getline (+ cur-line 1)) frame-line-pattern) -1)
          ;; Frame has content below — show locals
          (let [frame (. vim.b.nvlime_sldb_frames (+ nth 1))
                restartable (sldb.frame-restartable frame)]
            ((. vim.fn "nvlime#ChainCallbacks")
             (fn [continuation]
               (vim.b.nvlime_conn
                :FrameLocalsAndCatchTags
                nth
                (fn [c r]
                  (continuation nth restartable cur-line c r))))
             (fn [& args]
               (apply sldb.show-frame-locals-cb args))))
          ;; Frame is already expanded — collapse it
          (let [next-frame-line (search frame-line-pattern "nW")]
            (when (> next-frame-line 0)
              (vim.cmd "setlocal modifiable")
              (deletebufline (bufnr "%") (+ cur-line 1) (- next-frame-line 1))
              (vim.cmd "setlocal nomodifiable")))))
     1)))

(fn sldb.open-frame-source [...]
  "Open the source location for the frame under cursor.
  edit-cmd: Vim edit command (default: 'hide edit')."
  (let [edit-cmd (or (select 1 ...) "hide edit")]
    (var nth (sldb.match-frame true))
    (when (< nth 0)
      (set nth 0))

    (let [[win-to-go count-specified]
          ((. vim.fn "nvlime#ui#ChooseWindowWithCount") nil)]
      (when (and (<= win-to-go 0) count-specified)
        (return))

      (vim.b.nvlime_conn
       :FrameSourceLocation
       nth
       (fn [c r]
          (sldb.open-frame-source-cb edit-cmd win-to-go count-specified c r))))))

(fn sldb.find-source [...]
  "Find source location for a variable in the current frame.
  edit-cmd: Vim edit command (default: 'hide edit')."
  (let [edit-cmd (or (select 1 ...) "hide edit")]
    (var nth (sldb.match-frame))
    (when (< nth 0)
      (set nth 0))

    (let [[win-to-go count-specified]
          ((. vim.fn "nvlime#ui#ChooseWindowWithCount") nil)]
      (when (and (<= win-to-go 0) count-specified)
        (return))

      (vim.b.nvlime_conn
       :FrameLocalsAndCatchTags
       nth
       (fn [c msg]
          (sldb.find-source-cb edit-cmd win-to-go count-specified nth c msg))))))

(fn sldb.restart-cur-frame []
  "Restart the frame under cursor if it is restartable."
  (let [nth (sldb.match-frame)]
    (when (and (>= nth 0)
               (< nth (length vim.b.nvlime_sldb_frames)))
      (let [frame (. vim.b.nvlime_sldb_frames (+ nth 1))]
        (if (sldb.frame-restartable frame)
            (vim.b.nvlime_conn :RestartFrame nth)
            (ui.err-msg (.. "Frame " (tostring nth) " is not restartable.")))))))

(fn sldb.step-cur-or-last-frame [opr]
  "Step, next, or out of the current frame.
  opr: 'step', 'next', or 'out'"
  (var nth (sldb.match-frame))
    (when (< nth 0)
      (set nth 0))

    (match opr
      "step" (vim.b.nvlime_conn :SLDBStep nth)
      "next" (vim.b.nvlime_conn :SLDBNext nth)
      "out"  (vim.b.nvlime_conn :SLDBOut nth)))

(fn sldb.inspect-cur-condition []
  "Inspect the current debug condition."
  (vim.b.nvlime_conn
   :InspectCurrentCondition
   (fn [c r]
     ((. (: c :ui) :OnInspect) c r nil nil))))

(fn sldb.inspect-var-in-cur-frame []
  "Inspect a variable in the current frame.
  If cursor is on a variable name with index, inspect directly.
  Otherwise, prompt for expression to evaluate."
  (let [varname (sldb.match-var-name)
        nth (sldb.match-frame true)]
    (when (< nth 0)
      (return))

    (let [thread (vim.b.nvlime_conn :GetCurrentThread)
          var-num (sldb.match-var-index)]
      (if (and (> (length varname) 0) (>= var-num 0))
          ;; Direct variable inspection
          (vim.b.nvlime_conn
           :WithThread
           thread
           (fn []
             (vim.b.nvlime_conn
              :InspectFrameVar
              var-num
              nth
              (fn [c r]
                ((. (: c :ui) :OnInspect) c r nil nil)))))
          ;; Prompt for expression
          (input.from-buffer
           vim.b.nvlime_conn
           "Inspect in frame (evaluated):"
           nil
           (fn []
             (sldb.inspect-in-cur-frame-input-complete nth thread)))))))

(fn sldb.eval-string-in-cur-frame []
  "Evaluate a string expression in the current frame."
  (var nth (sldb.match-frame))
    (when (< nth 0)
      (set nth 0))

    (let [thread (vim.b.nvlime_conn :GetCurrentThread)
          cur-package (. ((. vim.b.nvlime_conn :GetCurrentPackage)) 1)]
      (input.from-buffer
       vim.b.nvlime_conn
       "Eval in frame:"
       nil
       (fn []
          (sldb.eval-string-in-cur-frame-input-complete nth thread cur-package)))))

(fn sldb.send-value-in-cur-frame-to-repl []
  "Evaluate a string in the current frame and send result to REPL."
  (var nth (sldb.match-frame))
    (when (< nth 0)
      (set nth 0))

    (let [thread (vim.b.nvlime_conn :GetCurrentThread)
          cur-package (. ((. vim.b.nvlime_conn :GetCurrentPackage)) 1)]
      (input.from-buffer
       vim.b.nvlime_conn
       "Eval in frame and send result to REPL:"
       nil
        (fn []
          (sldb.send-value-in-cur-frame-to-repl-input-complete
            nth thread cur-package)))))

(fn sldb.disassemble-cur-frame []
  "Disassemble the current frame."
  (var nth (sldb.match-frame))
    (when (< nth 0)
      (set nth 0))

    (let [thread (vim.b.nvlime_conn :GetCurrentThread)]
      (vim.b.nvlime_conn
       :WithThread
       thread
       (fn []
         (vim.b.nvlime_conn
          :SLDBDisassemble
          nth
          (fn [_c r]
            (luaeval "require(\"nvlime.window.disassembly\").open(_A)" r)))))))

(fn sldb.return-from-cur-frame []
  "Return from the current frame with a value."
  (var nth (sldb.match-frame))
  (when (< nth 0)
    (set nth 0))

  (let [thread (vim.b.nvlime_conn :GetCurrentThread)]
    (input.from-buffer
     vim.b.nvlime_conn
     "Return from frame (evaluated):"
     nil
     (fn []
       (sldb.return-from-cur-frame-input-complete nth thread)))))

;;; ============================================================================
;;; Module export
;;; ============================================================================

sldb
