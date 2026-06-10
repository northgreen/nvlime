local nvim_win_close = vim.api.nvim_win_close
local luaeval = vim.fn.luaeval
local setbufvar = vim.fn.setbufvar
local float2nr = vim.fn.float2nr
local line = vim.fn.line
local ui = require("nvlime.core.ui")
local xref = {}
xref["open-xref-buf"] = function(conn, xref_list)
  local _let_1_ = luaeval("require(\"nvlime.window.xref\").open(_A[1], _A[2])", {xref_list, {["conn-name"] = conn.cb_data.name}})
  local _ = _let_1_[1]
  local bufnr = _let_1_[2]
  setbufvar(bufnr, "nvlime_conn", conn)
  return setbufvar(bufnr, "xref_list", xref_list)
end
xref["open-cur-xref"] = function(edit_cmd)
  local edit_cmd0 = (edit_cmd or "hide edit")
  local idx = (float2nr(math.floor(((line(".") + 1) / 2))) - 1)
  local raw_xref_loc = vim.b.xref_list[idx][2]
  nvim_win_close(0, true)
  local function _2_()
    local xref_loc = vim.fn["nvlime#ParseSourceLocation"](raw_xref_loc)
    local valid_loc = vim.fn["nvlime#GetValidSourceLocation"](xref_loc)
    if ((#valid_loc > 0) and __fnl_global___21_3d(valid_loc[2], nil)) then
      local path = valid_loc[1]
      if ((type(path) == "string") and not string.find(path, "^sftp://") and not vim.fn.filereadable(path)) then
        return ui["err-msg"](("Not readable: " .. path))
      else
        return vim.fn["nvlime#ui#ShowSource"](vim.b.nvlime_conn, valid_loc, edit_cmd0)
      end
    else
      if (__fnl_global___21_3d(raw_xref_loc, nil) and (raw_xref_loc[1].name == "ERROR")) then
        return ui["err-msg"](raw_xref_loc[2])
      else
        return ui["err-msg"]("No source available.")
      end
    end
  end
  return pcall(_2_)
end
return xref
