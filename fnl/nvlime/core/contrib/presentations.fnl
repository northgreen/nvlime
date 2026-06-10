;;; nvlime.core.contrib.presentations --- SWANK-PRESENTATIONS contrib module
;;; Provides presentation inspection and highlighting support.

(local connection (require "nvlime.core.connection"))

;;; Public methods (added to connection)

(fn connection.inspect-presentation [self pres-id reset callback]
  "Start inspecting an object saved by SWANK-PRESENTATIONS.
   PRES-ID should be a valid ID from PRESENTATION-START messages.
   If RESET is truthy, the inspector will be reset first.
   Results delivered via CALLBACK: (callback self result)."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INSPECT-PRESENTATION") pres-id reset])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#presentations#InspectPresentation" chan msg))))

(fn connection.init-presentations [self]
  "Register presentation methods on connection and initialize SWANK presentations."
  (tset self :InspectPresentation connection.inspect-presentation)
  (tset (. self :server_event_handlers) "PRESENTATION-START"
        (fn [conn msg]
          (vim.fn.luaeval "require(\"nvlime.contrib.presentations\").on_start(_A[1], _A[2])" [conn msg])))
  (tset (. self :server_event_handlers) "PRESENTATION-END"
        (fn [conn msg]
          (vim.fn.luaeval "require(\"nvlime.contrib.presentations\").on_end(_A[1], _A[2])" [conn msg])))
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INIT-PRESENTATIONS")])
             (fn [chan msg]
               (self:simple-send-cb nil "nvlime#contrib#presentations#Init" chan msg)))
  self)

connection
