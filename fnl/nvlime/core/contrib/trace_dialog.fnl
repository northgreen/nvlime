;;; nvlime.core.contrib.trace_dialog --- SWANK-TRACE-DIALOG contrib module
;;; Provides trace tree management, toggle, inspect, and reporting.

(local connection (require "nvlime.core.connection"))

;;; Private helpers

(fn translate-function-spec [spec]
  "Convert a string spec to a SWANK:FROM-STRING form, otherwise return as-is."
  (if (= (type spec) "string")
      [(connection.sym "SWANK" "FROM-STRING") spec]
      spec))

(fn get-current-package [conn]
  "Get the current package name, defaulting to COMMON-LISP-USER."
  (let [pkg (conn:GetCurrentPackage)]
    (if (= pkg nil)
        "COMMON-LISP-USER"
        (. pkg 1))))

;;; Public methods (added to connection)

(fn connection.clear-trace-tree [self ?callback]
  "Clear all trace entries in SWANK-TRACE-DIALOG."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-TRACE-DIALOG" "CLEAR-TRACE-TREE")])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#trace_dialog#ClearTraceTree" chan msg))))

(fn connection.dialog-toggle-trace [self name ?callback]
  "Toggle the traced state of a function in SWANK-TRACE-DIALOG.
   NAME can be a plain string or a raw spec object."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-TRACE-DIALOG" "DIALOG-TOGGLE-TRACE")
                (translate-function-spec name)])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#trace_dialog#DialogToggleTrace" chan msg))))

(fn connection.dialog-trace [self name ?callback]
  "Trace a function in SWANK-TRACE-DIALOG."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-TRACE-DIALOG" "DIALOG-TRACE")
                (translate-function-spec name)])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#trace_dialog#DialogTrace" chan msg))))

(fn connection.dialog-untrace [self name ?callback]
  "Untrace a function in SWANK-TRACE-DIALOG."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-TRACE-DIALOG" "DIALOG-UNTRACE")
                (translate-function-spec name)])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#trace_dialog#DialogUntrace" chan msg))))

(fn connection.dialog-untrace-all [self ?callback]
  "Untrace all functions in SWANK-TRACE-DIALOG."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-TRACE-DIALOG" "DIALOG-UNTRACE-ALL")])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#trace_dialog#DialogUntraceAll" chan msg))))

(fn connection.find-trace [self id ?callback]
  "Retrieve a trace entry by ID."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-TRACE-DIALOG" "FIND-TRACE") id])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#trace_dialog#FindTrace" chan msg))))

(fn connection.find-trace-part [self id part-id type ?callback]
  "Retrieve an argument or return value saved in a trace entry.
   TYPE can be :ARG or :RETVAL."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-TRACE-DIALOG" "FIND-TRACE-PART")
                id part-id (connection.kw type)])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#trace_dialog#FindTracePart" chan msg))))

(fn connection.inspect-trace-part [self id part-id type ?callback]
  "Inspect an argument or return value saved in a trace entry."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-TRACE-DIALOG" "INSPECT-TRACE-PART")
                id part-id (connection.kw type)])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#trace_dialog#InspectTracePart" chan msg))))

(fn connection.report-partial-tree [self key ?callback]
  "Retrieve at most SWANK-TRACE-DIALOG:*TRACES-PER-REPORT* trace entries.
   KEY should be a unique number or string to identify the requesting entity."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-TRACE-DIALOG" "REPORT-PARTIAL-TREE") key])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#trace_dialog#ReportPartialTree" chan msg))))

(fn connection.report-specs [self ?callback]
  "Retrieve traced function specs from SWANK-TRACE-DIALOG."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-TRACE-DIALOG" "REPORT-SPECS")])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#trace_dialog#ReportSpecs" chan msg))))

(fn connection.report-total [self callback]
  "Retrieve the total count of trace entries."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-TRACE-DIALOG" "REPORT-TOTAL")])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#trace_dialog#ReportTotal" chan msg))))

(fn connection.report-trace-detail [self id callback]
  "Retrieve the details of a trace entry by ID."
  (self:send (self:emacs-rex
               [(connection.sym "SWANK-TRACE-DIALOG" "REPORT-TRACE-DETAIL") id])
             (fn [chan msg]
               (self:simple-send-cb callback "nvlime#contrib#trace_dialog#ReportTraceDetail" chan msg))))

;;; Init

(fn connection.init-trace-dialog [self]
  "Register SWANK-TRACE-DIALOG methods on connection object."
  (tset self :ClearTraceTree connection.clear-trace-tree)
  (tset self :DialogToggleTrace connection.dialog-toggle-trace)
  (tset self :DialogTrace connection.dialog-trace)
  (tset self :DialogUntrace connection.dialog-untrace)
  (tset self :DialogUntraceAll connection.dialog-untrace-all)
  (tset self :FindTrace connection.find-trace)
  (tset self :FindTracePart connection.find-trace-part)
  (tset self :InspectTracePart connection.inspect-trace-part)
  (tset self :ReportPartialTree connection.report-partial-tree)
  (tset self :ReportSpecs connection.report-specs)
  (tset self :ReportTotal connection.report-total)
  (tset self :ReportTraceDetail connection.report-trace-detail)
  self)

connection
