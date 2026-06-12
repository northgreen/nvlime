"Logger singleton module - thin wrapper around LuaLog.
Provides lazy-initialized logger instance via get().
This module does NOT require plugin.fnl to avoid circular dependencies."

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

{:get get}
