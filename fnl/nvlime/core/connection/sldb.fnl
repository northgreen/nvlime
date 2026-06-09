;;; SLDB (debugger) methods for NvlimeConnection.
;;; Mixin module - requires connection.fnl and adds functions to it.

(local connection (require "nvlime.core.connection"))

(fn connection.sldb-abort [self callback]
  "Invokes the ABORT restart when the debugger is active."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "SLDB-ABORT")])
             (fn [chan msg]
               (self:sldb-send-cb callback "nvlime#SLDBAbort" chan msg))))

(fn connection.sldb-break [self func-name callback]
  "Sets a breakpoint at entry to a function with the name func-name."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "SLDB-BREAK") func-name])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#SLDBBreak" chan msg))))

(fn connection.sldb-continue [self callback]
  "Invokes the CONTINUE restart when the debugger is active."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "SLDB-CONTINUE")])
             (fn [chan msg]
               (self:sldb-send-cb callback "nvlime#SLDBContinue" chan msg))))

(fn connection.sldb-step [self frame callback]
  "Enters stepping mode in frame when the debugger is active."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "SLDB-STEP") frame])
             (fn [chan msg]
               (self:sldb-send-cb callback "nvlime#SLDBStep" chan msg))))

(fn connection.sldb-next [self frame callback]
  "Steps over the current function call in frame when the debugger is active."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "SLDB-NEXT") frame])
             (fn [chan msg]
               (self:sldb-send-cb callback "nvlime#SLDBNext" chan msg))))

(fn connection.sldb-out [self frame callback]
  "Steps out of the current function in frame when the debugger is active."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "SLDB-OUT") frame])
             (fn [chan msg]
               (self:sldb-send-cb callback "nvlime#SLDBOut" chan msg))))

(fn connection.sldb-return-from-frame [self frame str callback]
  "Evaluates str and returns from frame with the evaluation result."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "SLDB-RETURN-FROM-FRAME") frame str])
             (fn [chan msg]
               (self:sldb-send-cb callback "nvlime#SLDBReturnFromFrame" chan msg))))

(fn connection.sldb-disassemble [self frame callback]
  "Disassembles the code for frame."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "SLDB-DISASSEMBLE") frame])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#SLDBDisassemble" chan msg))))

(fn connection.invoke-nth-restart-for-emacs [self level restart callback]
  "Invokes a restart at level when the debugger is active."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INVOKE-NTH-RESTART-FOR-EMACS") level restart])
             (fn [chan msg]
               (self:sldb-send-cb callback "nvlime#InvokeNthRestartForEmacs" chan msg))))

(fn connection.restart-frame [self frame callback]
  "Restarts a frame when the debugger is active."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "RESTART-FRAME") frame])
             (fn [chan msg]
               (self:sldb-send-cb callback "nvlime#RestartFrame" chan msg))))

(fn connection.frame-locals-and-catch-tags [self frame callback]
  "Gets info about local variables and catch tags for frame."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "FRAME-LOCALS-AND-CATCH-TAGS") frame])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#FrameLocalsAndCatchTags" chan msg))))

(fn connection.frame-source-location [self frame callback]
  "Gets the source location for frame when the debugger is active.
  Fixes remote path if result is a LOCATION object."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "FRAME-SOURCE-LOCATION") frame])
             (fn [chan msg]
               ;; Inline check-return-status
               (let [status (. msg 2 1)]
                 (when (not= status.name "OK")
                   (error (.. "nvlime#FrameSourceLocation returned: "
                              (vim.inspect (. msg 2))))))
               ;; Inline try-to-call + location fix
               (let [loc-data (. msg 2 2)]
                 (when (= (type callback) "function")
                   (if (and loc-data (= (. loc-data 1 :name) "LOCATION"))
                       (callback self (self:fix-remote-path loc-data))
                       (callback self loc-data)))))))

(fn connection.eval-string-in-frame [self str frame package callback]
  "Evaluates str in package within the context of frame."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "EVAL-STRING-IN-FRAME") str frame package])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#EvalStringInFrame" chan msg))))

connection
