local nvim_err_writeln = vim.api.nvim_err_writeln
local inputlist = vim.fn.inputlist
local conn = require("nvlime.core.connection")
local connections = {}
local next_conn_id = 1
local conn_manager = {}
conn_manager["normalize-conn-id"] = function(id)
  if (type(id) == "table") then
    return id.cb_data.id
  else
    return id
  end
end
conn_manager.new = function(name)
  local conn_name = (name or ("nvlime-" .. next_conn_id))
  local new_conn = conn.new({id = next_conn_id, name = conn_name}, nil)
  connections[next_conn_id] = new_conn
  next_conn_id = (next_conn_id + 1)
  return new_conn
end
conn_manager.close = function(c)
  local conn_id = conn_manager["normalize-conn-id"](c)
  local r_conn = connections[conn_id]
  if r_conn then
    connections[conn_id] = nil
    return conn.close(r_conn)
  else
    return nil
  end
end
conn_manager.rename = function(conn0, new_name)
  local conn_id = conn_manager["normalize-conn-id"](conn0)
  local r_conn = connections[conn_id]
  if r_conn then
    r_conn.cb_data["name"] = new_name
    return nil
  else
    return nil
  end
end
conn_manager.select = function(quiet)
  if not next(connections) then
    if not quiet then
      nvim_err_writeln("Nvlime not connected.")
    else
    end
    return nil
  else
    local cur_conn = vim.b.nvlime_conn
    local cur_conn_id
    if cur_conn then
      cur_conn_id = cur_conn.cb_data.id
    else
      cur_conn_id = -1
    end
    local sorted_ids = {}
    for k, _ in pairs(connections) do
      table.insert(sorted_ids, k)
    end
    table.sort(sorted_ids)
    local display_names = {}
    for _, k in ipairs(sorted_ids) do
      local c = connections[k]
      local disp_name = (k .. ". " .. c.cb_data.name .. " (" .. c.channel.hostname .. ":" .. c.channel.port .. ")")
      if (cur_conn_id == c.cb_data.id) then
        disp_name = (disp_name .. " *")
      else
      end
      table.insert(display_names, disp_name)
    end
    vim.cmd("echohl Question")
    vim.cmd("echom 'Which connection to use?'")
    vim.cmd("echohl None")
    local conn_nr = inputlist(display_names)
    if (conn_nr == 0) then
      if not quiet then
        nvim_err_writeln("Canceled.")
      else
      end
      return nil
    else
      local c = connections[conn_nr]
      if c then
        return c
      else
        if not quiet then
          nvim_err_writeln(("Invalid connection ID: " .. tostring(conn_nr)))
        else
        end
        return nil
      end
    end
  end
end
conn_manager.get = function(quiet)
  local buf_conn = vim.b.nvlime_conn
  if (not vim.b.nvlime_conn or (buf_conn and not conn["is-connected"](buf_conn)) or (not buf_conn and not quiet)) then
    if next(connections) then
      local first_id = nil
      for k, _ in pairs(connections) do
        if (not first_id or (k < first_id)) then
          first_id = k
        else
        end
      end
      vim.b.nvlime_conn = connections[first_id]
    else
      local selected = conn_manager.select(quiet)
      if selected then
        vim.b.nvlime_conn = selected
      elseif quiet then
        vim.b.nvlime_conn = nil
      else
      end
    end
  else
  end
  return vim.b.nvlime_conn
end
local function _16_(self, key)
  return self[string.gsub(key, "_", "-")]
end
setmetatable(conn_manager, {__index = _16_})
return conn_manager
