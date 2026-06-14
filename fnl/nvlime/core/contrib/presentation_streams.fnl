;;; nvlime.core.contrib.presentation_streams --- SWANK-PRESENTATION-STREAMS contrib module
;;; Initializes SWANK presentation streams support.

(local connection (require "nvlime.core.connection"))

(fn connection.init-presentation-streams [self callback]
  "Initialize presentation streams on the connection.
  Calls callback when done."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INIT-PRESENTATION-STREAMS")])
             (fn [chan msg]
               (self:simple-send-cb nil "nvlime#contrib#presentation_streams#Init" chan msg)
               (when callback
                 (callback self)))))

connection
