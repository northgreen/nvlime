local window = require("nvlime.window")
local pwin = require("parsley.window")
local opts = require("nvlime.config")
local logger = require("nvlime.logger")
local nvim_exec = vim.api.nvim_exec
local nvim_win_set_buf = vim.api.nvim_win_set_buf
local nvim_set_current_win = vim.api.nvim_set_current_win
local nvim_get_current_win = vim.api.nvim_get_current_win
local nvim_buf_get_name = vim.api.nvim_buf_get_name
local nvim_win_get_buf = vim.api.nvim_win_get_buf
local nvim_set_option_value = vim.api.nvim_set_option_value
local nvim_win_is_valid = vim.api.nvim_win_is_valid
local main_win_pos
do
  local case_1_ = opts.main_window.position
  if (case_1_ == "top") then
    main_win_pos = "topleft"
  elseif (case_1_ == "left") then
    main_win_pos = "vertical topleft"
  elseif (case_1_ == "bottom") then
    main_win_pos = "botright"
  elseif (case_1_ == "right") then
    main_win_pos = "vertical botright"
  else
    local _ = case_1_
    main_win_pos = "vertical botright"
  end
end
local main_win = {pos = main_win_pos, size = opts.main_window.size, ["vert?"] = (nil ~= (main_win_pos and string.find(main_win_pos, "^vertical")))}
main_win.new = function(cmd, size, opposite)
  local self = setmetatable({}, {__index = main_win})
  local vert_3f = main_win["vert?"]
  self["id"] = nil
  self["buffers"] = {}
  local _3_
  if vert_3f then
    _3_ = cmd
  else
    _3_ = ("vertical " .. cmd)
  end
  self["cmd"] = _3_
  local _5_
  if vert_3f then
    _5_ = size
  else
    _5_ = nil
  end
  self["size"] = _5_
  self["opposite"] = opposite
  return self
end
do
  local sldb_height = 0.65
  main_win["sldb"] = main_win.new("", sldb_height, "repl")
  main_win["repl"] = main_win.new("leftabove", (1 - sldb_height), "sldb")
end
main_win["set-id"] = function(self, winid)
  self["id"] = winid
  return nil
end
main_win["set-options"] = function(self)
  window["set-minimal-style-options"](self.id)
  nvim_set_option_value("foldcolumn", "1", {win = self.id})
  return nvim_set_option_value("winhighlight", "FoldColumn:Normal", {win = self.id})
end
main_win["remove-buf"] = function(self, bufnr)
  for i, b in ipairs(self.buffers) do
    if (b == bufnr) then
      table.remove(self.buffers, i)
    else
    end
  end
  return nil
end
main_win["add-buf"] = function(self, bufnr)
  self["remove-buf"](self, bufnr)
  return table.insert(self.buffers, bufnr)
end
main_win["update-opts"] = function(self)
  local winid = nvim_get_current_win()
  self["set-id"](self, winid)
  self["add-buf"](self, nvim_win_get_buf(winid))
  return self["set-options"](self)
end
main_win["split-opposite"] = function(self, bufnr)
  local opposite = main_win[self.opposite]
  nvim_set_current_win(opposite.id)
  local height
  if (self.size and (type(self.size) == "number")) then
    height = math.floor((pwin["get-height"](opposite.id) * self.size))
  else
    height = ""
  end
  nvim_exec((self.cmd .. " " .. height .. "split " .. nvim_buf_get_name(bufnr)), false)
  return self["update-opts"](self)
end
main_win.split = function(self, bufnr)
  local bufname = nvim_buf_get_name(bufnr)
  nvim_exec((main_win.pos .. " " .. main_win.size .. "split " .. bufname), false)
  return self["update-opts"](self)
end
main_win["open-new"] = function(self, bufnr, focus_3f)
  local prev_winid = nvim_get_current_win()
  local opposite = main_win[self.opposite]
  if pwin["visible?"](opposite.id) then
    self["split-opposite"](self, bufnr)
  else
    self:split(bufnr)
  end
  if not focus_3f then
    return nvim_set_current_win(prev_winid)
  else
    return nil
  end
end
main_win["show-buf"] = function(self, bufnr, focus_3f)
  if (nvim_win_get_buf(self.id) ~= bufnr) then
    nvim_win_set_buf(self.id, bufnr)
    self["add-buf"](self, bufnr)
  else
  end
  if focus_3f then
    return nvim_set_current_win(self.id)
  else
    return nil
  end
end
main_win.open = function(self, bufnr, focus_3f)
  if (self.id and not nvim_win_is_valid(self.id)) then
    self["id"] = nil
    self["buffers"] = {}
  else
  end
  if pwin["visible?"](self.id) then
    logger.debug(("main-win.open: show-buf winid=" .. tostring(self.id)))
    self["show-buf"](self, bufnr, focus_3f)
  else
    logger.debug(("main-win.open: open-new bufnr=" .. tostring(bufnr)))
    self["open-new"](self, bufnr, focus_3f)
  end
  return self.id
end
return main_win
