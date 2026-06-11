;;; nvlime.core.contrib.mrepl --- SWANK-MREPL contrib module

(local connection (require "nvlime.core.connection"))
(local ui (require "nvlime.core.ui"))
(local mrepl-ui (require "nvlime.core.ui.mrepl"))

;;; Private helper functions

(fn append-output [repl-buf str]
  (setbufvar repl-buf :modifiable 1)
  (ui.with-buffer repl-buf #(ui.append-string str))
  (setbufvar repl-buf :modifiable 0))

(fn ensure-buffer-open [buf win-type]
  (when (<= (length (vim.fn.win_findbuf buf)) 0)
    (ui.keep-cur-window
          #(ui.open-buffer-with-win-settings buf false win-type))))

(fn build-prompt [chan-obj]
  (.. (. (. chan-obj :mrepl) :prompt 1) "> "))

;;; Private channel event handlers

(fn on-write-result [conn chan-obj msg]
  (when (. conn :ui)
    ((: conn :ui) :OnMREPLWriteResult conn chan-obj (. msg 2))))

(fn on-write-string [conn chan-obj msg]
  (when (. conn :ui)
    ((: conn :ui) :OnMREPLWriteString conn chan-obj (. msg 2))))

(fn on-prompt [conn chan-obj msg]
  (tset (. chan-obj :mrepl) :prompt [(. msg 2) (. msg 3)])
  (when (. conn :ui)
    ((: conn :ui) :OnMREPLPrompt conn chan-obj)))

(fn on-set-read-mode [conn chan-obj msg]
  (tset (. chan-obj :mrepl) :mode (. (. msg 2) :name)))

(fn on-evaluation-aborted [conn chan-obj msg]
  (when (. conn :ui)
    ((: conn :ui) :OnMREPLWriteResult conn chan-obj "; Evaluation aborted")))

(local channel-event-handlers
       {:WRITE-RESULT on-write-result
        :WRITE-STRING on-write-string
        :PROMPT on-prompt
        :SET-READ-MODE on-set-read-mode
        :EVALUATION-ABORTED on-evaluation-aborted})

(fn mrepl-channel-cb [conn chan-obj msg]
  (let [msg-type (. msg 1)
        handler (get channel-event-handlers (. msg-type :name))]
    (when handler
      (handler conn chan-obj msg))
    (when (and (not handler)
               (or vim.g._nvlime_debug false))
      (vim.fn.echom (.. "Unknown message: " (vim.fn.string msg))))))

(fn create-mrepl-cb [conn callback local-chan chan msg]
  (conn:check-return-status msg "nvlime.core.contrib.mrepl.create-mrepl")
  (let [mrepl-info (. msg 2 2)
        chan-id (. mrepl-info 1)
        thread-id (. mrepl-info 2)
        pkg-name (. mrepl-info 3)
        pkg-prompt (. mrepl-info 4)]
    (tset (. local-chan :mrepl) :peer chan-id)
    (tset (. local-chan :mrepl) :prompt [pkg-name pkg-prompt])
    (let [remote-chan (: conn :make-remote-channel chan-id)]
      (tset remote-chan :mrepl {:thread thread-id
                                :peer (. local-chan :id)}))
    (conn:try-to-call callback [conn mrepl-info])))

;;; Public methods (added to connection)

(fn connection.create-mrepl [self chan-id callback]
  (let [chan-id (or chan-id vim.v.null)
        callback (or callback vim.v.null)
        chan-obj (self:make-local-channel chan-id mrepl-channel-cb)]
    (tset chan-obj :mrepl {:mode "EVAL"})
    (self:send (self:emacs-rex [(connection.sym "SWANK-MREPL" "CREATE-MREPL")
                                (. chan-obj :id)])
               (fn [msg]
                 (create-mrepl-cb self callback chan-obj nil msg)))))

;;; UI methods (added to ui singleton)

(fn ui.on-mrepl-write-result [self conn chan-obj result]
  (let [mrepl-buf (mrepl-ui.init-mrepl-buf conn chan-obj)]
    (ensure-buffer-open mrepl-buf "mrepl")
    (mrepl-ui.show-result mrepl-buf result)))

(fn ui.on-mrepl-write-string [self conn chan-obj content]
  (let [mrepl-buf (mrepl-ui.init-mrepl-buf conn chan-obj)]
    (ensure-buffer-open mrepl-buf "mrepl")
    (append-output mrepl-buf content)))

(fn ui.on-mrepl-prompt [self conn chan-obj]
  (let [mrepl-buf (mrepl-ui.init-mrepl-buf conn chan-obj)]
    (ensure-buffer-open mrepl-buf "mrepl")
    (mrepl-ui.show-prompt mrepl-buf (build-prompt chan-obj))))

;;; Init

(fn connection.init-mrepl [self]
  (tset self :CreateMREPL connection.create-mrepl)
  (let [ui-obj (ui.get-ui)]
    (tset ui-obj :OnMREPLWriteResult ui.on-mrepl-write-result)
    (tset ui-obj :OnMREPLWriteString ui.on-mrepl-write-string)
    (tset ui-obj :OnMREPLPrompt ui.on-mrepl-prompt)))

return connection
