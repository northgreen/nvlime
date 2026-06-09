;;; Swank protocol methods for NvlimeConnection.
;;; Mixin module - requires connection.fnl and adds functions to it.

(local connection (require "nvlime.core.connection"))

;;; Module-level helpers

(fn transform-compiler-policy [policy]
  "Converts dict policy like {:DEBUG 3 :SPEED 0} to quoted policy list."
  (if (= (type policy) "table")
      (let [plc-list []]
        (each [key val (pairs policy)]
          (tset plc-list (+ (length plc-list) 1)
                {:head [(connection.cl key)] :tail val}))
        [(connection.cl "QUOTE") plc-list])
      policy))

(fn fix-xref-list-paths [conn xref-list]
  "Fixes paths in xref results."
  (when (= (type xref-list) "table")
    (each [_ spec (pairs xref-list)]
      (when (and (= (type (. spec 1)) "string")
                 (= (. spec 2 1 :name) "LOCATION"))
        (tset spec 2 (conn:fix-remote-path (. spec 2)))))))

;;; Threads

(fn connection.list-threads [self callback]
  "Lists all threads on the Lisp server."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "LIST-THREADS")])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#ListThreads" chan msg))))

(fn connection.kill-nth-thread [self nth callback]
  "Kill a thread presented in the thread list.
   nth should be a valid index in the thread list, instead of a thread ID."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "KILL-NTH-THREAD") nth])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#KillNthThread" chan msg))))

(fn connection.debug-nth-thread [self nth callback]
  "Activate the debugger in a thread presented in the thread list.
   nth should be a valid index in the thread list, instead of a thread ID."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "DEBUG-NTH-THREAD") nth])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#DebugNthThread" chan msg))))

;;; Symbols

(fn connection.undefine-function [self func-name callback]
  "Undefine a function with the name func-name."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "UNDEFINE-FUNCTION") func-name])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#UndefineFunction" chan msg))))

(fn connection.unintern-symbol [self sym-name package callback]
  "Unintern a symbol with the name sym-name."
  (let [package (or package
                    (let [pkg-info (self:get-current-package)]
                      (if (= (type pkg-info) "table")
                          (. pkg-info 1)
                          nil)))]
    (self:send (self:emacs-rex
                 [(connection.sym "SWANK" "UNINTERN-SYMBOL") sym-name package])
               (fn [chan msg]
                 (self:simple-send-cb callback "nvlime#UninternSymbol" chan msg)))))

(fn connection.set-package [self package callback]
  "Bind a Common Lisp package to the current buffer."
  (let [bufnr (vim.api.nvim_get_current_buf)]
    (self:send (self:emacs-rex
                 [(connection.sym "SWANK" "SET-PACKAGE") package])
               (fn [chan msg]
                 (self:check-return-status msg "nvlime#SetPackage")
                 (vim.api.nvim_buf_call bufnr
                   (fn []
                     (self:set-current-package [(. msg 2 2) (. msg 2 2)])))
                 (when (= (type callback) "function")
                   (callback self (. msg 2 2)))))))

(fn connection.describe-symbol [self symbol callback]
  "Get a description for symbol."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "DESCRIBE-SYMBOL") symbol])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#DescribeSymbol" chan msg))))

;;; Completion

(fn connection.operator-arg-list [self operator callback]
  "Get the arglist description for operator."
  (let [cur-package (let [pkg-info (self:get-current-package)]
                      (if (= (type pkg-info) "table")
                          (. pkg-info 1)
                          nil))]
    (self:send (self:emacs-rex
                 [(connection.sym "SWANK" "OPERATOR-ARGLIST") operator cur-package])
               (fn [chan msg]
                 (self:simple-send-cb callback "nvlime#OperatorArgList" chan msg)))))

(fn connection.simple-completions [self symbol callback]
  "Get a simple completion list for symbol."
  (let [cur-package (let [pkg-info (self:get-current-package)]
                      (if (= (type pkg-info) "table")
                          (. pkg-info 1)
                          nil))]
    (self:send (self:emacs-rex
                 [(connection.sym "SWANK" "SIMPLE-COMPLETIONS") symbol cur-package])
               (fn [chan msg]
                 (self:simple-send-cb callback "nvlime#SimpleCompletions" chan msg)))))

;;; Return

(fn connection.return-string [self thread ttag str]
  "Send EMACS-RETURN-STRING to server."
  (self:send [(connection.kw "EMACS-RETURN-STRING") thread ttag str] nil))

(fn connection.return [self thread ttag val]
  "Send EMACS-RETURN to server."
  (self:send [(connection.kw "EMACS-RETURN") thread ttag val] nil))

;;; Macro Expansion

(fn connection.swank-macro-expand-one [self expr callback]
  "Perform one macro expansion on expr."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "SWANK-MACROEXPAND-1") expr])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#SwankMacroExpandOne" chan msg))))

(fn connection.swank-macro-expand [self expr callback]
  "Expand expr until the resulting form cannot be macro-expanded anymore."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "SWANK-MACROEXPAND") expr])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#SwankMacroExpand" chan msg))))

(fn connection.swank-macro-expand-all [self expr callback]
  "Recursively expand all macros in expr."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "SWANK-MACROEXPAND-ALL") expr])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#SwankMacroExpandAll" chan msg))))

;;; Compilation

(fn connection.disassemble-form [self expr callback]
  "Compile and disassemble expr."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "DISASSEMBLE-FORM") expr])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#DisassembleForm" chan msg))))

(fn connection.compile-string-for-emacs [self expr buffer position filename policy callback]
  "Compile expr. buffer, position and filename specify where expr is from."
  (let [policy (transform-compiler-policy policy)
        fixed-filename (self:fix-local-path filename)]
    (self:send (self:emacs-rex
                 [(connection.sym "SWANK" "COMPILE-STRING-FOR-EMACS")
                  expr buffer
                  [(connection.cl "QUOTE")
                   [[(connection.kw "POSITION") position]]]
                  fixed-filename policy])
               (fn [chan msg]
                 (self:simple-send-cb callback "nvlime#CompileStringForEmacs" chan msg)))))

(fn connection.compile-file-for-emacs [self filename load policy callback]
  "Compile a file with the name filename."
  (let [policy (transform-compiler-policy policy)
        fixed-filename (self:fix-local-path filename)
        cmd [(connection.sym "SWANK" "COMPILE-FILE-FOR-EMACS")
             fixed-filename load]]
    (when policy
      (table.insert cmd (connection.kw "POLICY"))
      (table.insert cmd policy))
    (self:send (self:emacs-rex cmd)
               (fn [chan msg]
                 (self:simple-send-cb callback "nvlime#CompileFileForEmacs" chan msg)))))

(fn connection.load-file [self filename callback]
  "Load a file with the name filename."
  (let [fixed-filename (self:fix-local-path filename)]
    (self:send (self:emacs-rex
                 [(connection.sym "SWANK" "LOAD-FILE") fixed-filename])
               (fn [chan msg]
                 (self:simple-send-cb callback "nvlime#LoadFile" chan msg)))))

;;; XRef

(fn connection.xref [self ref-type name callback]
  "Cross reference lookup."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "XREF")
                (connection.kw ref-type) name])
             (fn [chan msg]
               (self:check-return-status msg "nvlime#XRef")
               (let [result (. msg 2 2)]
                 (fix-xref-list-paths self result)
                 (when (= (type callback) "function")
                   (callback self result))))))

(fn connection.find-definitions-for-emacs [self name callback]
  "Lookup definitions for symbol name."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "FIND-DEFINITIONS-FOR-EMACS") name])
             (fn [chan msg]
               (self:check-return-status msg "nvlime#FindDefinitionsForEmacs")
               (let [result (. msg 2 2)]
                 (fix-xref-list-paths self result)
                 (when (= (type callback) "function")
                   (callback self result))))))

(fn connection.find-source-location-for-emacs [self spec callback]
  "Lookup source locations for certain objects.
   spec is like [\"STRING\" expr package] or [\"INSPECTOR\" part-id] or [\"SLDB\" frame nth]."
  (let [spec-type (. spec 1)
        kw-list [(connection.kw spec-type)]]
    (each [_ item (pairs (vim.list_slice spec 2))]
      (table.insert kw-list item))
    (let [spec-expr [(connection.cl "QUOTE") kw-list]]
      (self:send (self:emacs-rex
                   [(connection.sym "SWANK" "FIND-SOURCE-LOCATION-FOR-EMACS") spec-expr])
                 (fn [chan msg]
                   (self:check-return-status msg "nvlime#FindSourceLocationForEmacs")
                   (let [result (. msg 2 2)]
                     (when (= (type callback) "function")
                       (if (and result (= (. result 1 :name) "LOCATION"))
                           (callback self (self:fix-remote-path result))
                                                       (callback self result)))))))))

(fn connection.apropos-list-for-emacs [self name external-only case-sensitive package callback]
  "Lookup symbol names containing name."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "APROPOS-LIST-FOR-EMACS")
                name external-only case-sensitive package])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#AproposListForEmacs" chan msg))))

(fn connection.documentation-symbol [self sym-name callback]
  "Find the documentation for symbol sym-name."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "DOCUMENTATION-SYMBOL") sym-name])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#DocumentationSymbol" chan msg))))

connection
