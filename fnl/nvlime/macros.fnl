;; fennel-ls: macro-file
;; Logging macros - expanded at compile time to call the runtime logger.

(fn warn-msg [msg]
  (let [require-sym (sym "require")
        concat-sym (sym "..")
        logger-sym (list require-sym "nvlime.logger")
        call (list logger-sym "warn" (list concat-sym "nvlime: " msg))]
    call))

(fn info-msg [msg]
  (let [require-sym (sym "require")
        concat-sym (sym "..")
        logger-sym (list require-sym "nvlime.logger")
        call (list logger-sym "info" (list concat-sym "nvlime: " msg))]
    call))

{: warn-msg
 : info-msg}
