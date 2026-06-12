"Logger singleton module - thin wrapper around LuaLog.
Provides lazy-initialized logger and top-level debug/warn/info/error functions.
Uses let-binding to avoid Fennel's double-call bug with (: obj :method) on
function call results: (get():method())(msg) crashes since method returns nil."

(local log (require "nvlime.lib.log"))
(local nvim-outputter (require "nvlime.lib.outputters.nvim_outputter"))
(local config (require "nvlime.config"))

(var instance nil)

(fn get []
  "Returns the NVLime logger instance, initializing on first call."
  (when (not instance)
    (let [log-level (if (. config :log_level) (. config :log_level) "DEBUG")]
      (log.setup {:log_level log-level
                  :rotes {:root {:name "nvlime"
                                 :level 0
                                 :output (nvim-outputter log)
                                 :output_opt {:formatter log.formatters.simple_formatter
                                              :formatter_opt {:show_debug_trace false}}}}})
      (set instance (log.getLogger "nvlime"))))
  instance)

;; Top-level convenience functions.
;; Fennel (: obj :method arg) compiles to obj:method()(arg) — double-call.
;; When obj is a function call like (get), this crashes: get():method()(arg).
;; Solution: bind to local first, then use (local:method arg) which compiles
;; to the correct local:method(arg).
(fn debug [msg]
  (let [logger (get)]
    (logger:debug msg)))

(fn warn [msg]
  (let [logger (get)]
    (logger:warn msg)))

(fn info [msg]
  (let [logger (get)]
    (logger:info msg)))

(fn error [msg]
  (let [logger (get)]
    (logger:error msg)))

{:get get
 :debug debug
 :warn warn
 :info info
 :error error}
