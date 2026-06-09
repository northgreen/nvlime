;;; Inspector methods for NvlimeConnection.
;;; Mixin module - requires connection.fnl and adds functions to it.

(local connection (require "nvlime.core.connection"))

(fn connection.init-inspector [self thing callback]
  "Evaluates thing and start inspecting the evaluation result with the inspector."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INIT-INSPECTOR") thing])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#InitInspector" chan msg))))

(fn connection.inspector-reinspect [self callback]
  "Reload the object being inspected, and update inspector states."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INSPECTOR-REINSPECT")])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#InspectorReinspect" chan msg))))

(fn connection.inspector-range [self r-start r-end callback]
  "Pagination for inspector content.
  r-start is the first index to retrieve.
  r-end is the last index plus one."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INSPECTOR-RANGE") r-start r-end])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#InspectorRange" chan msg))))

(fn connection.inspect-nth-part [self nth callback]
  "Inspect an object presented by the inspector.
  nth should be a valid part number presented by the inspector."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INSPECT-NTH-PART") nth])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#InspectNthPart" chan msg))))

(fn connection.inspector-call-nth-action [self nth callback]
  "Perform an action in the inspector.
  nth should be a valid action number presented by the inspector."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INSPECTOR-CALL-NTH-ACTION") nth])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#InspectorCallNthAction" chan msg))))

(fn connection.inspector-pop [self callback]
  "Inspect the previous object in the stack of inspected objects."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INSPECTOR-POP")])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#InspectorPop" chan msg))))

(fn connection.inspector-next [self callback]
  "Inspect the next object in the stack of inspected objects."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INSPECTOR-NEXT")])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#InspectorNext" chan msg))))

(fn connection.inspect-current-condition [self callback]
  "When the debugger is active, inspect the current condition."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INSPECT-CURRENT-CONDITION")])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#InspectCurrentCondition" chan msg))))

(fn connection.inspect-in-frame [self thing frame callback]
  "When the debugger is active, evaluate thing in the context of frame,
  and start inspecting the evaluation result."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INSPECT-IN-FRAME") thing frame])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#InspectInFrame" chan msg))))

(fn connection.inspect-frame-var [self var-num frame callback]
  "When the debugger is active, inspect variable #{var-num} in the context of frame.
  Note: SWANK protocol expects [frame var-num] order."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK" "INSPECT-FRAME-VAR") frame var-num])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#InspectFrameVar" chan msg))))

connection
