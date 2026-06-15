;;; nvlime.core.plugin --- Main entry point and user commands
;;; Migrated from autoload/nvlime/plugin.vim (1466 lines)

(local config (require "nvlime.config"))
(local conn-manager (require "nvlime.core.conn_manager"))
(local ui (require "nvlime.core.ui"))
(local input (require "nvlime.core.ui.input"))
(local async (require "nvlime.core.async"))
(local connection (require "nvlime.core.connection"))
;; Load connection mixin modules (they register methods on the connection table)
(require "nvlime.core.connection.channels")
(require "nvlime.core.connection.messages")
(require "nvlime.core.connection.sldb")
(require "nvlime.core.connection.inspector")
(require "nvlime.core.connection.swank")
(require "nvlime.core.connection.events")
;; Load contrib module (registers call-initializers on connection table)
(local contrib (require "nvlime.core.contrib"))
(local server (require "nvlime.core.server"))
(local uc (require "nvlime.ui_cursors"))
(local logger (require "nvlime.logger"))

(local plugin {})

;;; ============================================================================
;;; Private helpers
;;; ============================================================================

(fn input-check-edit-flag [edit text]
  "Returns [text default] based on edit flag.
  When edit is true, text is nil (prompt user) and default is text.
  When edit is false, text is provided and default is nil."
  (if edit
      [nil text]
      [text nil]))

(fn conn-has-contrib [conn contrib-name]
  "Check if connection has a contrib loaded."
  (let [contribs (. conn.cb_data :contribs)]
    (and contribs
         (>= (vim.fn.index contribs contrib-name) 0))))

(fn normalize-identifier-for-indent [ident]
  "Strip pipe delimiters from identifiers for indent lookup."
  (let [ident-len (string.len ident)]
    (if (and (>= ident-len 2)
             (= (. ident 1) "|")
             (= (. ident ident-len) "|"))
        (string.sub ident 2 (- ident-len 1))
        ident)))

(fn complete-find-start []
  "Find the start column for completion."
  (var col (- (vim.fn.col ".") 1))
  (let [line (vim.fn.getline ".")]
    (while (and (> col 0)
                (< (vim.fn.match (. line col) "\\_s\\|[()#;'\"]") 0))
      (set col (- col 1)))
    col))

(fn reset-arglist-state []
  "Clear cached arglist state.
  Called after operations that change function signatures."
  (set autodoc-cache {})
  (set last-arglist-op ""))

(fn show-async-result [conn result]
  "Show macro expansion result in window."
  (vim.fn.luaeval
    "require(\"nvlime.window.macroexpand\").open(_A)"
    result))

(fn show-symbol-description [conn content]
  "Show symbol description in window."
  (vim.fn.luaeval
    "require(\"nvlime.window.description\").open(_A)"
    content))

(fn show-symbol-documentation [conn content]
  "Show symbol documentation in window."
  (vim.fn.luaeval
    "require(\"nvlime.window.documentation\").open(_A)"
    content))

(fn on-xref-complete [conn result]
  "Handle XRef results."
  (when (. conn :ui)
    (conn.ui:on-xref conn result)))

(fn on-apropos-list-complete [conn result]
  "Handle apropos list results."
  (if (not result)
      (ui.err-msg "No result found.")
      (vim.fn.luaeval
        "require(\"nvlime.window.apropos\").open(_A)"
        result)))

(fn on-sldb-break-complete [conn result]
  "Handle breakpoint set result."
  (vim.cmd "echom 'Breakpoint set.'"))

(fn on-undefine-function-complete [conn result]
  "Handle undefine function result."
  (vim.cmd (.. "echom 'Undefined function " result "'")))

(fn on-unintern-symbol-complete [conn result]
  "Handle unintern symbol result."
  (vim.cmd (.. "echom '" result "'")))

(fn on-load-file-complete [fname conn result]
  "Handle load file completion."
  (vim.cmd (.. "echom 'Loaded: " fname "'"))
  (reset-arglist-state))

(fn on-listener-eval-complete [conn result]
  "Handle listener eval result - display values in REPL."
  (when (or (not conn) (not (. conn :ui)))
    (logger.warn "on-listener-eval-complete: no UI available")
    (reset-arglist-state)
    (lua "return"))
  (when (or (not result) (= (type result) "userdata"))
    (conn.ui:on-write-string conn "; No value\n"
      {:name "REPL-RESULT" :package "KEYWORD"})
    (reset-arglist-state)
    (lua "return"))
  (logger.debug (.. "on-listener-eval-complete: result-type=" (tostring (type result))
                    " result-len=" (tostring (length result))))
  (if (and (= (type result) "table")
           (> (length result) 0)
           (= (type (. result 1)) "table")
           (= (. result 1 :name) "VALUES"))
      (do
        (logger.debug "on-listener-eval-complete: result format VALID (VALUES)")
        (let [result-values (vim.list_slice result 2)]
          (if (> (length result-values) 0)
              (each [_ val (ipairs result-values)]
                (conn.ui:on-write-string conn
                 (.. val "\n")
                 {:name "REPL-RESULT" :package "KEYWORD"}))
              (conn.ui:on-write-string conn "; No value\n"
                {:name "REPL-RESULT" :package "KEYWORD"}))))
      (logger.warn (.. "on-listener-eval-complete: result format INVALID, expected VALUES, got "
                    (tostring (type result)))))
  (reset-arglist-state))

(fn on-compilation-complete [orig-win conn result]
  "Handle compilation result."
  (let [[msg-type notes successp duration loadp faslfile] result]
    (if successp
        (do
          (vim.cmd (.. "echom 'Compilation finished in "
                       (tostring duration) " second(s)'"))
          (when (and loadp faslfile)
            (conn:load-file faslfile
                            (fn [c r] (on-load-file-complete faslfile c r)))))
        (ui.err-msg "Compilation failed."))
    (when (. conn :ui)
      (conn.ui:on-compiler-notes conn notes orig-win))))

;;; ============================================================================
;;; Module-level state
;;; ============================================================================

(var autodoc-cache {})
(var last-arglist-op "")
(var key-timer 0)

;;; ============================================================================
;;; Connection setup callbacks
;;; ============================================================================

(fn on-connection-info-complete [conn result]
  "Process connection info and store in cb_data."
  (set conn.cb_data.version (connection.get conn result "VERSION" "<unknown version>"))
  (set conn.cb_data.pid (connection.get conn result "PID" "<unknown pid>"))
  (let [features (connection.get conn result "FEATURES" [])]
    (set conn.cb_data.features (or features []))))

(fn on-swank-require-complete [do-init conn result]
  "Process swank-require result and initialize new contribs."
  (let [new-contribs (or result [])
        old-contribs (or (. conn.cb_data :contribs) [])]
    (set conn.cb_data.contribs new-contribs)
    (when do-init
      (let [added []]
        (each [_ co (ipairs new-contribs)]
          (when (< (vim.fn.index old-contribs co) 0)
            (table.insert added co)))
        (connection.call-initializers conn added
                                      (fn [c]
                                        (vim.cmd
                                          (.. "echom 'Loaded contrib modules: "
                                              (vim.inspect added)))))))))

(fn on-call-initializers-complete [conn]
  "Final callback after all initializers complete."
  (vim.cmd (.. "echom '" conn.cb_data.name " connection established.'")))

(fn maybe-send-secret [conn]
  "Send .slime-secret to server if file exists."
  (let [secret-file (or vim.g.nvlime_secret_file
                        (vim.fn.expand "~/.slime-secret"))]
    (when (= (vim.fn.filereadable secret-file) 1)
      (let [content (vim.fn.readfile secret-file "" 1)]
        (when (> (length content) 0)
          (conn:send [(connection.kw "NVLIME-RAW-MSG") (. content 1)] nil))))))

(fn clean-up-null-buf-connections []
  "Remove null connection bindings from all buffers."
  (let [old-buf (vim.fn.bufnr "%")]
    (pcall (fn []
             (vim.cmd "bufdo! if exists('b:nvlime_conn') && b:nvlime_conn is# v:null | unlet b:nvlime_conn | endif")))
    (pcall vim.cmd (.. "hide buffer " old-buf))))

;;; ============================================================================
;;; ConnectREPL - Main entry point
;;; ============================================================================

(fn plugin.connect-repl [host port remote-prefix timeout name]
  "Connect to a SWANK server.
  Prompts for host/port if not provided.
  Returns connection object or nil on failure."
  (let [def-timeout (if (not= config.connect_timeout -1)
                      config.connect_timeout
                      nil)
        host (or host
                 (let [h (vim.fn.input "Host: " config.address.host)]
                   (if (<= (string.len h) 0)
                       (do (ui.err-msg "Canceled.") (values nil))
                       h)))
        port (or port
                 (let [p (vim.fn.input "Port: "
                                       (tostring config.address.port))]
                   (if (<= (string.len p) 0)
                       (do (ui.err-msg "Canceled.") (values nil))
                       (tonumber p))))
        conn (if name
               (conn-manager.new name)
               (conn-manager.new))
        remote-prefix (or remote-prefix "")
        timeout (or timeout def-timeout)]
    ;; Attempt connection
    (pcall (fn [] (conn:connect host port remote-prefix timeout)))
    (when (not (conn:is-connected))
      (conn-manager.close conn)
      (ui.err-msg "nvlime#Connect: failed to connect")
      (values nil))
    (clean-up-null-buf-connections)
    (set conn.cb_data.remote_host host)
    (set conn.cb_data.remote_port port)
    ;; Send secret if available
    (maybe-send-secret conn)
    ;; Chain: ConnectionInfo → OnConnectionInfoComplete → SwankRequire → OnSwankRequireComplete → CallInitializers → OnCallInitializersComplete
    (conn:chain-callbacks
      (fn [cont] (conn:connection-info true (fn [c r] (do (on-connection-info-complete c r) (cont)))))
      (fn [cont] (on-connection-info-complete conn nil) (cont))
      (fn [cont] (conn:swank-require config.contribs
                                     (fn [c r] (do (on-swank-require-complete false c r) (cont)))))
      (fn [cont] (connection.call-initializers conn nil
                                              (fn [c] (on-call-initializers-complete c) (cont))))
      (fn [] nil))
    conn))

;;; ============================================================================
;;; Connection management commands
;;; ============================================================================

(fn plugin.close-cur-connection []
  "Close the connection bound to the current buffer."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [server (. conn.cb_data :server)]
      (if (not server)
          (do
            (conn-manager.close conn)
            (vim.cmd (.. "echom '" conn.cb_data.name " disconnected.'")))
          (let [answer (vim.fn.input
                         (.. "Also stop server "
                             (vim.inspect server.name) "? (y/n) "))]
             (when (ui.is-yes-string answer)
               (server.stop server))
            (when (and (not (ui.is-yes-string answer))
                       (string.find answer "^[nN]"))
              (conn-manager.close conn)
              (vim.cmd (.. "echom '" conn.cb_data.name " disconnected.'"))))))))

(fn plugin.rename-cur-connection []
  "Rename the connection bound to the current buffer."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [new-name (vim.fn.input "New name: " conn.cb_data.name)]
      (if (> (string.len new-name) 0)
          (conn-manager.rename conn new-name)
          (ui.err-msg "Canceled.")))))

(fn plugin.select-cur-connection []
  "Show a menu to select a connection and bind it to the current buffer."
  (let [conn (conn-manager.select false)]
    (when conn
      (set vim.b.nvlime_conn conn))))

;;; ============================================================================
;;; REPL commands
;;; ============================================================================

(fn plugin.send-to-repl [content edit]
  "Evaluate content in the REPL and show result."
  (let [conn (conn-manager.get true)]
    (when (not conn)
      (ui.err-msg "Not connected. Use :NvlimeConnect first.")
      (values nil))
    (when conn
      (let [[text default] (input-check-edit-flag (or edit false) content)]
        (input.maybe-input
          text
          (fn [str]
            (when (and conn (. conn :ui))
              (conn.ui:on-write-string conn "--\n"
               {:name "REPL-SEP" :package "KEYWORD"})
              (conn:with-thread
               true
               (fn []
                (conn:listener-eval str on-listener-eval-complete)))))
          " Send to REPL "
          default
          conn)))))

(fn plugin.compile [content policy edit]
  "Compile content with optional policy."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) content)]
      (input.maybe-input
        text
        (fn [str]
          (when (. conn :ui)
            (conn.ui:on-write-string conn "--\n"
             {:name "REPL-SEP" :package "KEYWORD"})
            (let [win (vim.fn.win_getid)
                  policy (or policy config.compiler_policy)]
              (conn:compile-string-for-emacs
                str nil 1 nil policy
                (fn [c r] (on-compilation-complete win c r))))))
        " Compile "
        default
        conn))))

(fn plugin.compile-defun []
  "Compile the top-level form at point.
   BLOCKED: requires ui_cursor.fnl for cursor-based form extraction."
  (ui.err-msg "compile-defun: blocked on ui_cursor.fnl (cursor-based form extraction not yet implemented)"))

(fn plugin.load-file [file-name edit]
  "Load a Lisp file."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) file-name)]
      (input.maybe-input
        text
        (fn [fname]
          (conn:load-file fname
                          (fn [c r] (on-load-file-complete fname c r))))
        " Load file "
        (or default "")
        nil
        "file"))))

(fn plugin.set-package [pkg]
  "Set the current Common Lisp package."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [cur-pkg (conn:get-current-package)
          default (if (= (type cur-pkg) "table")
                    (. cur-pkg 1)
                    "COMMON-LISP-USER")]
      (input.maybe-input
        pkg
        (fn [p] (conn:set-package p))
        " Set package "
        default
        conn))))

(fn plugin.inspect [content edit]
  "Evaluate content and launch inspector."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) content)]
      (input.maybe-input
        text
        (fn [str]
          (conn:init-inspector
            str
            (fn [c r]
              (c.ui:on-inspect c r nil nil))))
        " Inspect "
        default
        conn))))

;;; ============================================================================
;;; Compilation file commands
;;; ============================================================================

(fn plugin.compile-file [file-name policy load edit]
  "Compile a Lisp file with optional policy."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) file-name)]
      (input.maybe-input
        text
        (fn [fname]
          (when (. conn :ui)
            (conn.ui:on-write-string conn "--\n"
             {:name "REPL-SEP" :package "KEYWORD"})
            (let [win (vim.fn.win_getid)
                  policy (or policy config.compiler_policy)
                  load (or load true)]
              (conn:compile-file-for-emacs
                fname load policy
                (fn [c r] (on-compilation-complete win c r))))))
        " Compile file "
        (or default "")
        nil
        "file"))))

;;; ============================================================================
;;; Macro expansion commands
;;; ============================================================================

(fn plugin.expand-macro [expr type edit]
  "Perform macro expansion on expr."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) expr)]
      (let [cb-fn (match (or type "expand")
                    "all"   (fn [e] (conn:swank-macro-expand-all e show-async-result))
                    "one"   (fn [e] (conn:swank-macro-expand-one e show-async-result))
                    _       (fn [e] (conn:swank-macro-expand e show-async-result)))]
        (input.maybe-input text cb-fn "Expand macro: " default conn)))))

(fn plugin.disassemble-form [content edit]
  "Compile and disassemble content."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) content)]
      (input.maybe-input
        text
        (fn [expr]
          (conn:disassemble-form expr ui.show-disassemble-form))
        " Disassemble "
        default
        conn))))

;;; ============================================================================
;;; Symbol lookup commands
;;; ============================================================================

(fn plugin.describe-symbol [symbol edit]
  "Show description for symbol."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) symbol)]
      (input.maybe-input
        text
        (fn [sym] (conn:describe-symbol sym show-symbol-description))
        " Describe symbol "
        default
        conn))))

(fn plugin.documentation-symbol [symbol edit]
  "Show documentation for symbol."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) symbol)]
      (input.maybe-input
        text
        (fn [sym] (conn:documentation-symbol sym show-symbol-documentation))
        " Documentation for symbol "
        default
        conn))))

(fn plugin.apropos-list [pattern edit]
  "Apropos search for pattern."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) pattern)]
      (input.maybe-input
        text
        (fn [pat]
          (conn:apropos-list-for-emacs pat false false nil on-apropos-list-complete))
        " Apropos search "
        default
        conn))))

(fn plugin.find-definition [sym edit]
  "Find definition for symbol."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) sym)]
      (input.maybe-input
        text
        (fn [s] (conn:find-definitions-for-emacs s on-xref-complete))
        " Definition of symbol "
        default
        conn))))

(fn plugin.xref-symbol [ref-type sym edit]
  "Cross reference lookup for symbol."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) sym)]
      (input.maybe-input
        text
        (fn [s] (conn:xref ref-type s on-xref-complete))
        " XRef symbol "
        default
        conn))))

(fn plugin.xref-symbol-wrapper []
  "Interactive XRef type picker, then dispatch."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [ref-types ["calls" "calls-who" "references" "binds" "sets"
                     "macroexpands" "specializes" "definition"]]
      (if (> vim.v.count 0)
          (let [answer vim.v.count]
            (dispatch-xref-by-index ref-types answer))
          (let [options []]
            (for [i 1 (length ref-types)]
              (table.insert options (.. i ". " (. ref-types i))))
            (vim.cmd "echohl Question")
            (vim.cmd "echom 'What kind of xref?'")
            (vim.cmd "echohl None")
            (let [answer (vim.fn.inputlist options)]
              (dispatch-xref-by-index ref-types answer)))))))

(fn dispatch-xref-by-index [ref-types answer]
  "Dispatch XRef based on numeric answer."
  (when (<= answer 0)
    (ui.err-msg "Canceled.")
    (values nil))
  (when (> answer (length ref-types))
    (ui.err-msg (.. "Invalid xref type: " (tostring answer)))
    (values nil))
  (let [rtype (. ref-types answer)]
    (if (= rtype "definition")
        (plugin.find-definition)
        (plugin.xref-symbol (string.upper rtype)))))

;;; ============================================================================
;;; Arglist / Autodoc commands
;;; ============================================================================

(fn plugin.show-operator-arglist [op edit]
  "Show arglist for operator."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) op)]
      (input.maybe-input
        text
        (fn [operator]
          (conn:operator-arg-list
            operator
            (fn [c result]
              (when result
                (ui.show-arglist c result)
                (set last-arglist-op operator)))))
        " Arglist for operator "
        default
        conn))))

(fn plugin.cur-autodoc []
  "Show autodoc for current expression at cursor.
   BLOCKED: requires ui_cursor.fnl for cursor-based expression parsing."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (if (conn-has-contrib conn "SWANK-ARGLISTS")
        (ui.err-msg "cur-autodoc: blocked on ui_cursor.fnl (ui.CurRawForm unavailable)")
        (ui.err-msg "cur-autodoc: blocked on ui_cursor.fnl (ui.SurroundingOperator unavailable)"))))

;;; ============================================================================
;;; Breakpoint / Debug commands
;;; ============================================================================

(fn plugin.set-breakpoint [sym edit]
  "Set a breakpoint at function sym."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) sym)]
      (input.maybe-input
        text
        (fn [symbol] (conn:sldb-break symbol on-sldb-break-complete))
        " Set breakpoint at function "
        default
        conn))))

(fn plugin.list-threads []
  "Show thread list window."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (conn:list-threads
      (fn [c result]
        (when (. c :ui)
          (c.ui:on-threads c result))))))

;;; ============================================================================
;;; Undefine / Unintern commands
;;; ============================================================================

(fn plugin.undefine-function [sym edit]
  "Undefine a function."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) sym)]
      (input.maybe-input
        text
        (fn [symbol] (conn:undefine-function symbol on-undefine-function-complete))
        " Undefine function "
        default
        conn))))

(fn plugin.unintern-symbol [sym edit]
  "Unintern a symbol."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) sym)]
      (input.maybe-input
        text
        (fn [raw-sym]
          (let [matched (vim.fn.matchlist raw-sym "\\(\\([^:]\\+\\)\\?::\\?\\)\\?\\(\\k\\+\\)")]
            (when (> (length matched) 0)
              (let [sym-name (. matched 3)
                    prefix (. matched 1)
                    sym-pkg (if (= prefix ":")
                              "KEYWORD"
                              (if (= prefix "")
                                  nil
                                  (. matched 2)))]
                (conn:unintern-symbol sym-name sym-pkg
                                      on-unintern-symbol-complete)))))
        " Unintern symbol "
        default
        conn))))

(fn plugin.undefine-unintern-wrapper []
  "Interactive picker for undefine vs unintern."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [options ["1. Undefine a function" "2. Unintern a symbol"]]
      (vim.cmd "echohl Question")
      (vim.cmd "echom 'What to do?'")
      (vim.cmd "echohl None")
      (let [answer (vim.fn.inputlist options)]
        (cond
          (<= answer 0) (ui.err-msg "Canceled.")
          (= answer 1) (plugin.undefine-function)
          (= answer 2) (plugin.unintern-symbol)
          :else (ui.err-msg (.. "Invalid action: " (tostring answer))))))))

;;; ============================================================================
;;; Swank contrib commands
;;; ============================================================================

(fn plugin.swank-require [contribs do-init]
  "Require SWANK contrib modules."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (conn:swank-require
      contribs
      (fn [c r]
        (on-swank-require-complete (or do-init true) c r)))))

;;; ============================================================================
;;; Trace dialog commands (requires SWANK-TRACE-DIALOG contrib)
;;; ============================================================================

(fn plugin.dialog-toggle-trace [func edit]
  "Toggle traced state of func."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (when (not (conn-has-contrib conn "SWANK-TRACE-DIALOG"))
      (ui.err-msg "SWANK-TRACE-DIALOG is not available.")
      (values nil))
    (let [[text default] (input-check-edit-flag (or edit false) func)]
      (input.maybe-input
        text
        (fn [func-spec]
          (conn:DialogToggleTrace func-spec
            (fn [c r] (vim.cmd "echom 'Traced state toggled.'"))))
        " Toggle tracing "
        default
        conn))))

(fn plugin.open-trace-dialog []
  "Show the trace dialog."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (when (not (conn-has-contrib conn "SWANK-TRACE-DIALOG"))
      (ui.err-msg "SWANK-TRACE-DIALOG is not available.")
      (values nil))
    (conn:ReportSpecs
      (fn [c r]
        (when r
          (vim.fn.luaeval
            "require(\"nvlime.window.trace\").open(_A)"
            r))))))

;;; ============================================================================
;;; MREPL commands (requires SWANK-MREPL contrib)
;;; ============================================================================

(fn plugin.create-mrepl []
  "Create a new REPL thread using SWANK-MREPL."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (if (conn-has-contrib conn "SWANK-MREPL")
        (conn:CreateMREPL vim.v.null
          (fn [c r]
            (vim.cmd "echom 'MREPL created.'"))))))

;;; ============================================================================
;;; Server management stubs (require server.fnl integration)
;;; ============================================================================

(fn plugin.show-current-server []
  "Show the current server console."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [server-obj (. conn.cb_data :server)]
      (if server-obj
          (server.show server-obj)
          (ui.err-msg "No server bound to current connection.")))))

(fn plugin.show-selected-server []
  "Show a selected server console."
  (let [srv (server.select)]
    (when srv (server.show srv))))

(fn plugin.stop-current-server []
  "Stop the current server."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [server-obj (. conn.cb_data :server)]
      (if server-obj
          (server.stop server-obj)
          (ui.err-msg "No server bound to current connection.")))))

(fn plugin.restart-current-server []
  "Restart the current server."
  (let [conn (conn-manager.get true)]
    (when (not conn) (values nil))
    (let [server-obj (. conn.cb_data :server)]
      (if server-obj
          (do
            (server.stop server-obj)
            (server.new true false nil nil))
          (ui.err-msg "No server bound to current connection.")))))

(fn plugin.stop-selected-server []
  "Stop a selected server."
  (let [srv (server.select)]
    (when srv (server.stop srv))))

(fn plugin.rename-selected-server []
  "Rename a selected server."
  (let [srv (server.select)]
    (when srv
      (let [new-name (vim.fn.input "New name: " srv.name)]
        (when (> (string.len new-name) 0)
          (server.rename srv new-name))))))

;;; ============================================================================
;;; Completion
;;; ============================================================================

(fn on-fuzzy-completions-complete [start-col cur-pos conn result]
  "Handle fuzzy completion results."
  (let [cur-pos (vim.list_slice (vim.fn.getcurpos) 2 3)
        comps (or (. result 1) [])
        r-comps []]
    (when (not= cur-pos (vim.list_slice (vim.fn.getcurpos) 2 3))
      (values nil))
    (each [_ c (ipairs comps)]
      (table.insert r-comps {:word (. c 1) :menu (. c 4)}))
    (pcall vim.fn.complete start-col r-comps)))

(fn on-simple-completions-complete [start-col cur-pos conn result]
  "Handle simple completion results."
  (let [cur-pos (vim.list_slice (vim.fn.getcurpos) 2 3)
        comps (or (vim.list_slice result 2) [])]
    (when (not= cur-pos (vim.list_slice (vim.fn.getcurpos) 2 3))
      (values nil))
    (pcall vim.fn.complete start-col comps)))

(fn plugin.completefunc [find-start base]
  "Omnicomplete / completefunc callback.
  Asynchronous - does not return completions directly."
  (let [start-col (complete-find-start)]
    (if find-start
        start-col
        (let [conn (conn-manager.get true)]
          (if (not conn)
              -1
              (let [raw-pos (vim.list_slice (vim.fn.getcurpos) 2 3)
                    cur-pos [(vim.fn.bufnr "%")
                             (. raw-pos 1)
                             (+ (. raw-pos 2) (string.len base))]]
                (if (conn-has-contrib conn "SWANK-FUZZY")
                    (conn:fuzzy-completions
                      base
                      (fn [c r]
                        (on-fuzzy-completions-complete
                          (+ start-col 1) cur-pos c r)))
                    (conn:simple-completions
                      base
                      (fn [c r]
                        (on-simple-completions-complete
                          (+ start-col 1) cur-pos c r))))
                {:words [] :refresh "always"}))))))

;;; ============================================================================
;;; Indentation
;;; ============================================================================

(fn plugin.calc-cur-indent [shift-width]
  "Calculate indent for current line.
   BLOCKED: requires ui_cursor.fnl for ui.ParseOuterOperators.
   Falls back to vim.fn.lispindent."
  (let [shift-width (or shift-width 2)
        line-no (vim.fn.line ".")]
    (vim.fn.lispindent line-no)))

;;; ============================================================================
;;; SpaceEnter / TabKey helpers
;;; ============================================================================

(fn space-enter-cb []
  "Timer callback for SpaceEnter key - shows arglist."
  (if config.autodoc.enabled
      (plugin.cur-autodoc)
      (plugin.show-operator-arglist)))

(fn plugin.space-enter-key []
  "Handle space key press with debounce timer."
  (when (> key-timer 0)
    (vim.fn.timer_stop key-timer))
  (set key-timer (vim.fn.timer_start 150 space-enter-cb)))

(fn plugin.tab-key [key]
  "Handle tab key - indent or complete.
   BLOCKED: requires ui_cursor.fnl for isInString and CalcLeadingSpaces."
  (.. key))

;;; ============================================================================
;;; Buffer setup
;;; ============================================================================

(fn plugin.setup [force]
  "Set up Nvlime for the current buffer.
  Sets omnifunc and indentexpr."
  (when (or (not vim.b.nvlime_setup) force)
    (vim.cmd "setlocal omnifunc=v:lua.require'nvlime.core.plugin'.completefunc")
    (vim.cmd "setlocal indentexpr=v:lua.require'nvlime.core.plugin'.calc-cur-indent()")
    (set vim.b.nvlime_setup true)))

(fn plugin.interaction-mode [enable]
  "Toggle interaction mode.
  Maps <CR> to send expression to REPL."
  (let [enable (or enable
                   (not (or vim.b.nvlime_interaction_mode false)))]
    (set vim.b.nvlime_interaction_mode enable)
    (if enable
        (do
          (vim.cmd "nnoremap <buffer> <silent> <CR> :lua require('nvlime.core.plugin').send_to_repl(require('nvlime.ui_cursors').cur_expr_or_atom())<CR>")
          (vim.cmd "vnoremap <buffer> <silent> <CR> :<C-u>lua require('nvlime.core.plugin').send_to_repl(require('nvlime.ui_cursors').cur_selection())<CR>"))
        (do
          (vim.cmd "nnoremap <buffer> <CR> <CR>")
          (vim.cmd "vnoremap <buffer> <CR> <CR>")))
    (vim.cmd (.. "echom 'Interaction mode "
                  (if enable "enabled" "disabled")
                    ".'"))))

;;; ============================================================================
;;; Module export
;;; ============================================================================


;;; Hyphen/underscore compatibility for VimScript shim calls
;;; VimScript shim calls s:P.send_to_repl which becomes plugin["send_to_repl"]
;;; but Fennel exports as plugin["send-to-repl"] (kebab-case)
;;; This metatable maps snake_case access to kebab-case keys
(setmetatable plugin
  {:__index (fn [self key]
              (let [new-key (string.gsub key "_" "-")]
                (if (= new-key key) nil (. self new-key))))})

;;; Module export
plugin
