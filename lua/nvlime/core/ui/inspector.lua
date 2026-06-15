local nvim_win_close = vim.api.nvim_win_close
local getcurpos = vim.fn.getcurpos
local setpos = vim.fn.setpos
local ui = require("nvlime.core.ui")
local events = require("nvlime.core.connection.events")
local inspector = {}
inspector["get-cur-coord"] = function()
  local cur_pos = getcurpos()
  local line = cur_pos[2]
  local col = cur_pos[3]
  local coord = nil
  for _, c in ipairs(vim.b.nvlime_inspector_coords) do
    if ui["match-coord"](c, line, col) then
      coord = c
    else
    end
  end
  return coord
end
inspector["on-inspector-pop-complete"] = function(which, conn, result)
  if not result then
    return ui["err-msg"](("No " .. which .. " object."))
  else
    return conn:ui().OnInspect(conn, result, nil, nil)
  end
end
inspector["inspector-fetch-all-cb"] = function(acc, conn, result)
  do
    local new_items = result[1]
    if new_items then
      for _, item in ipairs(new_items) do
        table.insert(acc.content[1], item)
      end
    else
    end
  end
  local content = acc.content
  local total_count = result[2]
  local cur_start = result[3]
  local fetched_end = result[4]
  if (total_count > fetched_end) then
    local range_size = (fetched_end - cur_start)
    local function _4_(c, r)
      return inspector["inspector-fetch-all-cb"](acc, c, r)
    end
    return conn:InspectorRange(fetched_end, (fetched_end + range_size), _4_)
  else
    content[2] = #content[1]
    content[4] = content[2]
    local full_content = {{name = "TITLE", package = "KEYWORD"}, acc.title, {name = "CONTENT", package = "KEYWORD"}, content}
    conn:ui().OnInspect(conn, full_content, nil, nil)
    return vim.cmd("echom 'Done fetching inspector content.'")
  end
end
inspector["find-source-cb"] = function(edit_cmd, conn, msg)
  local pcall_result
  local function _6_()
    local loc = events["parse-source-location"](nil, msg)
    return events["get-valid-source-location"](nil, loc)
  end
  pcall_result = pcall(_6_)
  local valid_loc
  if pcall_result[1] then
    valid_loc = pcall_result[2]
  else
    valid_loc = {}
  end
  if valid_loc[2] then
    nvim_win_close(0, true)
    return ui["show-source"](conn, valid_loc, edit_cmd, false)
  else
    if (msg and (msg[1].name == "ERROR")) then
      return ui["err-msg"](msg[2])
    else
      return ui["err-msg"]("No source available.")
    end
  end
end
inspector["inspector-select"] = function()
  local coord = inspector["get-cur-coord"]()
  if not coord then
  else
  end
  local case_11_ = coord.type
  if (case_11_ == "ACTION") then
    local function _12_(c, r)
      return c:ui().OnInspect(c, r, nil, nil)
    end
    return vim.b.nvlime_conn:InspectorCallNthAction(coord.id, _12_)
  elseif (case_11_ == "VALUE") then
    local function _13_(c, r)
      return c:ui().OnInspect(c, r, nil, nil)
    end
    return vim.b.nvlime_conn:InspectNthPart(coord.id, _13_)
  elseif (case_11_ == "RANGE") then
    local range_size = (vim.b.nvlime_inspector_content_end - vim.b.nvlime_inspector_content_start)
    local build_content
    local function _14_(content)
      return {{name = "TITLE", package = "KEYWORD"}, vim.b.nvlime_inspector_title, {name = "CONTENT", package = "KEYWORD"}, content}
    end
    build_content = _14_
    if (coord.id > 0) then
      local next_start = vim.b.nvlime_inspector_content_end
      local next_end = (vim.b.nvlime_inspector_content_end + range_size)
      local function _15_(c, r)
        return c:ui().OnInspect(c, build_content(r), nil, nil)
      end
      return vim.b.nvlime_conn:InspectorRange(next_start, next_end, _15_)
    elseif (coord.id < 0) then
      local next_start = vim.fn.max({0, (vim.b.nvlime_inspector_content_start - range_size)})
      local next_end = vim.b.nvlime_inspector_content_start
      local function _16_(c, r)
        return c:ui().OnInspect(c, build_content(r), nil, nil)
      end
      return vim.b.nvlime_conn:InspectorRange(next_start, next_end, _16_)
    else
      vim.cmd("echom 'Fetching all inspector content, please wait...'")
      local acc = {title = vim.b.nvlime_inspector_title, content = {{}, 0, 0, 0}}
      local function _17_(c, r)
        return inspector["inspector-fetch-all-cb"](acc, c, r)
      end
      return vim.b.nvlime_conn:InspectorRange(0, range_size, _17_)
    end
  else
    local _ = case_11_
    return nil
  end
end
inspector["send-cur-value-to-repl"] = function()
  local coord = inspector["get-cur-coord"]()
  if (not coord or __fnl_global___21_3d(coord.type, "VALUE")) then
  else
  end
  local conn = vim.b.nvlime_conn
  conn:ui().OnWriteString(conn, "--\n", {name = "REPL-SEP", package = "KEYWORD"})
  local function _21_()
    return conn.ListenerEval(("(nth-value 0 (swank:inspector-nth-part " .. coord.id .. "))"), nil)
  end
  return conn:WithThread({name = "REPL-THREAD", package = "KEYWORD"}, _21_)
end
inspector["send-cur-inspectee-to-repl"] = function()
  local conn = vim.b.nvlime_conn
  conn:ui().OnWriteString(conn, "--\n", {name = "REPL-SEP", package = "KEYWORD"})
  local function _22_()
    return conn.ListenerEval("(swank::istate.object swank::*istate*)", nil)
  end
  return conn:WithThread({name = "REPL-THREAD", package = "KEYWORD"}, _22_)
end
inspector["find-source"] = function(type, ...)
  local edit_cmd = (select(1, ...) or "hide edit")
  local conn = vim.b.nvlime_conn
  if (type == "inspectee") then
    local function _23_(c, msg)
      return inspector["find-source-cb"](edit_cmd, c, msg)
    end
    return conn:FindSourceLocationForEmacs({"INSPECTOR", 0}, _23_)
  elseif (type == "part") then
    local coord = inspector["get-cur-coord"]()
    if (not coord or __fnl_global___21_3d(coord.type, "VALUE")) then
    else
    end
    local function _25_(c, msg)
      return inspector["find-source-cb"](edit_cmd, c, msg)
    end
    return conn:FindSourceLocationForEmacs({"INSPECTOR", coord.id}, _25_)
  else
    return ui["err-msg"](("Unknown source type: " .. type))
  end
end
inspector["next-field"] = function(forward)
  if (#vim.b.nvlime_inspector_coords <= 0) then
  else
  end
  local cur_pos = getcurpos()
  local sorted_coords = ui["sort-coords"](vim.b.nvlime_inspector_coords, forward)
  local next_coord = ui["find-next-coord"]({cur_pos[2], cur_pos[3]}, sorted_coords, forward)
  next_coord = (next_coord or sorted_coords[1])
  local begin = next_coord.begin
  return setpos(".", {0, begin[1], begin[2], 0, begin[2]})
end
inspector["inspector-pop"] = function()
  local function _28_(conn, result)
    return inspector["on-inspector-pop-complete"]("previous", conn, result)
  end
  return vim.b.nvlime_conn:InspectorPop(_28_)
end
inspector["inspector-next"] = function()
  local function _29_(conn, result)
    return inspector["on-inspector-pop-complete"]("next", conn, result)
  end
  return vim.b.nvlime_conn:InspectorNext(_29_)
end
inspector.reinspect = function()
  local conn = (vim.b.nvlime_conn or require("nvlime.core.conn_manager").get[false])
  if conn then
    local function _30_(c, r)
      return c.ui["on-inspect"](c.ui, c, r, nil, nil)
    end
    return conn["inspector-reinspect"](conn, _30_)
  else
    return nil
  end
end
return inspector
