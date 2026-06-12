;; fennel-ls: macro-file
;; Logging macros - expanded at compile time to call the runtime logger.

(fn warn-msg [msg]
  `((: ((require "nvlime.logger") :get) :warn) ,(.. "nvlime: " msg)))

(fn info-msg [msg]
  `((: ((require "nvlime.logger") :get) :info) ,(.. "nvlime: " msg)))

{: warn-msg
 : info-msg}
