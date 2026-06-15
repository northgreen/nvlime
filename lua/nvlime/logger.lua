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
local function debug(msg)
  local logger = get()
  return logger:debug(msg)
end
local function warn(msg)
  local logger = get()
  return logger:warn(msg)
end
local function info(msg)
  local logger = get()
  return logger:info(msg)
end
local function error(msg)
  local logger = get()
  return logger:error(msg)
end
return {get = get, debug = debug, warn = warn, info = info, error = error}
