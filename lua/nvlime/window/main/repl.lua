local buffer = require("nvlime.buffer")
local logger = require("nvlime.logger")
local main = require("nvlime.window.main")
local ut = require("nvlime.utilities")
local presentations = require("nvlime.contrib.presentations")
local nvim_win_set_cursor = vim.api.nvim_win_set_cursor
local nvim_buf_clear_namespace = vim.api.nvim_buf_clear_namespace
local nvim_buf_line_count = vim.api.nvim_buf_line_count
local nvim_get_current_buf = vim.api.nvim_get_current_buf
local repl = {}
local _2bfiletype_2b = buffer["gen-filetype"](buffer.names.repl)
local function repl_banner(conn)
  local data = conn.cb_data
  local banner
  local _1_
  if data.version then
    _1_ = ("version " .. data.version .. ", ")
  else
    _1_ = ""
  end
  local _3_
  if data.pid then
    _3_ = ("pid " .. data.pid .. ", ")
  else
    _3_ = nil
  end
  banner = ("SWANK " .. _1_ .. _3_ .. "remote " .. (data.remote_host or "unknown") .. ":" .. (data.remote_port or "?"))
  local border = string.rep("=", #banner)
  return {banner, border, ""}
end
local function clear_repl_2a(bufnr, conn)
  logger.debug(("clear-repl: bufnr=" .. tostring(bufnr)))
  presentations["coords"] = {}
  buffer["fill!"](bufnr, repl_banner(conn))
  return nvim_buf_clear_namespace(bufnr, presentations.namespace, 0, -1)
end
local function buf_callback(bufnr)
  buffer["set-opts"](bufnr, {filetype = _2bfiletype_2b})
  presentations["coords"] = {}
  local conn_manager = require("nvlime.core.conn_manager")
  local active_conn = (buffer["get-conn-var!"](bufnr) or conn_manager.get(true))
  if active_conn then
    logger.debug(("buf-callback: initialized bufnr=" .. tostring(bufnr) .. " conn=" .. tostring(active_conn.cb_data.name)))
    active_conn["set-current-thread"](active_conn, {name = "REPL-THREAD", package = "KEYWORD"})
    return clear_repl_2a(bufnr, active_conn)
  else
    return nil
  end
end
repl.open = function(content, config)
  local lines = ut["text->lines"](content)
  local bufnr
  local function _6_(_241)
    return buf_callback(_241)
  end
  bufnr = buffer["create-if-not-exists"](buffer["gen-repl-name"](config["conn-name"]), false, _6_)
  buffer["append!"](bufnr, lines)
  logger.debug(("REPL_OPEN: buf=" .. bufnr .. " lines_count=" .. tostring(#lines)))
  local winid = main.repl:open(bufnr, config["focus?"])
  nvim_win_set_cursor(winid, {nvim_buf_line_count(bufnr), 0})
  return {winid, bufnr}
end
repl.clear = function()
  logger.debug("repl.clear: called")
  local cur_bufnr = nvim_get_current_buf()
  local conn = buffer["get-conn-var!"](cur_bufnr)
  if conn then
    local _let_7_ = repl.open("", {["conn-name"] = conn.cb_data.name})
    local _ = _let_7_[1]
    local bufnr = _let_7_[2]
    clear_repl_2a(bufnr, conn)
    return nvim_win_set_cursor(main.repl.id, {3, 0})
  else
    return nil
  end
end
return repl
