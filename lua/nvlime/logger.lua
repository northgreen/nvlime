local log = require("nvlime.lib.log")
local nvim_outputter = require("nvlime.lib.outputters.nvim_outputter")
local config = require("nvlime.config")
local instance = nil
local function get()
  if not instance then
    local log_level
    if config.log_level then
      log_level = config.log_level
    else
      log_level = "DEBUG"
    end
    log.setup({log_level = log_level, rotes = {root = {name = "nvlime", level = 0, output = nvim_outputter(log), output_opt = {formatter = log.formatters.simple_formatter, formatter_opt = {show_debug_trace = false}}}}})
    instance = log.getLogger("nvlime")
  else
  end
  return instance
end
return {get = get}
