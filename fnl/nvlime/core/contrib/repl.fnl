;;; nvlime.core.contrib.repl --- SWANK-REPL contrib module
;;; Provides REPL creation and listener evaluation via SWANK's SWANK-REPL contrib.

(local connection (require "nvlime.core.connection"))
(local logger (require "nvlime.logger"))

;;; Private helper

(fn check-and-report-return-status [conn return-msg caller]
  "Validates return status. On ABORT or unknown error, writes to UI and returns nil.
  Returns true on OK status."
  (let [status (. return-msg 2 1)]
    (logger.debug (.. "check-and-report-return-status: status=" (tostring (vim.inspect status)) " caller=" caller))
    (if (= status.name "OK")
        (do
          (logger.debug "check-and-report-return-status: OK")
          true)
        (if (= status.name "ABORT")
            (do
              (logger.warn (.. "check-and-report-return-status: ABORT - " (. return-msg 2 2)))
              ((. (: conn :ui) :OnWriteString)
               conn
               (.. (. return-msg 2 2) "\n")
               {:name "ABORT-REASON" :package "KEYWORD"})
              nil)
            (do
              (logger.warn (.. "check-and-report-return-status: UNKNOWN-ERROR - " (vim.inspect (. return-msg 2))))
              ((. (: conn :ui) :OnWriteString)
               conn
               (vim.inspect (. return-msg 2))
               {:name "UNKNOWN-ERROR" :package "KEYWORD"})
              nil)))))

;;; Public methods (added to connection)

(fn connection.create-repl [self coding-system callback]
  "Create a new REPL session on the Lisp server.
  CODING-SYSTEM is optional. Results delivered via CALLBACK: (callback self result)."
  (let [cmd [(connection.sym "SWANK-REPL" "CREATE-REPL")]]
    (when (not= coding-system nil)
      (table.insert cmd (connection.kw "CODING-SYSTEM"))
      (table.insert cmd coding-system))
    (self:send (self:emacs-rex cmd)
               (fn [chan msg]
                 (self:check-return-status msg "nvlime#contrib#repl#CreateREPL")
                 (self:try-to-call callback [self (. msg 2 2)])))))

(fn connection.listener-eval [self expr callback]
  "Evaluate EXPR in the listener REPL.
  Results delivered via CALLBACK: (callback self result).
  Handles ABORT status by writing to UI instead of throwing."
  (logger.debug (.. "listener-eval: expr=" expr))
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-REPL" "LISTENER-EVAL") expr (connection.kw "WINDOW-WIDTH") 80])
             (fn [chan msg]
               (logger.debug (.. "listener-eval callback: msg=" (vim.inspect msg)))
               (logger.debug (.. "listener-eval callback: msg-len=" (tostring (length msg))))
               (when (check-and-report-return-status self msg "nvlime#contrib#repl#ListenerEval")
                 (logger.debug "listener-eval callback: calling user callback")
                 (self:try-to-call callback [self (. msg 2 2)])))))

(fn connection.init-repl [self callback]
  "Register REPL methods on connection object and create default REPL.
  Calls callback when done."
  (tset self :CreateREPL connection.create-repl)
  (tset self :ListenerEval connection.listener-eval)
  (self:create-repl nil (fn [_ _]
                        (when callback
                          (callback self)))))

connection
