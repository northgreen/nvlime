local bufnr = vim.fn.bufnr
local setbufvar = vim.fn.setbufvar
local getbufvar = vim.fn.getbufvar
local getcurpos = vim.fn.getcurpos
local setpos = vim.fn.setpos
local win_gotoid = vim.fn.win_gotoid
local ui = require("nvlime.core.ui")
__fnl_global__compiler_2dnotes({})
__fnl_global__compiler_2dnotes["init-buffer"] = function(conn, orig_win)
  local buf_name = ui["compiler-notes-buf-name"](conn)
  local buf = bufnr(buf_name, true)
  if not ui["nvlime-buffer-initialized"](buf) then
    ui["set-nvlime-buffer-opts"](buf, conn)
    setbufvar(buf, "filetype", "nvlime_notes")
  else
  end
  setbufvar(buf, "nvlime_notes_orig_win", orig_win)
  return buf
end
__fnl_global__compiler_2dnotes["fill-buffer"] = function(note_list)
  vim.cmd("setlocal modifiable")
  if not note_list then
    ui["replace-content"]("No message from the compiler.")
    vim.b.nvlime_compiler_note_coords = {}
    vim.b.nvlime_compiler_note_list = {}
    __fnl_global__return()
  else
  end
  local coords = {}
  local nlist = {}
  vim.fn["nvlime#ClearCurrentBuffer"]()
  local idx = 0
  local note_count = #note_list
  for _ = note, ipairs(note_list) do
    local note_dict = vim.fn["nvlime#PListToDict"](note)
    table.insert(nlist, note_dict)
    do
      local begin_pos = getcurpos()
      ui["append-string"]((note_dict.SEVERITY.name .. ": " .. note_dict.MESSAGE), nil)
      local eof_coord = ui["get-end-of-file-coord"]()
      if (idx < (note_count - 1)) then
        ui["append-string"]("\n--\n", nil)
      else
      end
      table.insert(coords, {begin = {begin_pos[1], begin_pos[2]}, ["end"] = eof_coord, type = "NOTE", id = idx})
    end
    idx = (idx + 1)
  end
  setpos(".", {0, 1, 1, 0, 1})
  vim.cmd("setlocal nomodifiable")
  vim.b.nvlime_compiler_note_coords = coords
  vim.b.nvlime_compiler_note_list = nlist
  return nil
end
__fnl_global__compiler_2dnotes["open-cur-note"] = function(edit_cmd)
  local note_coord = nil
  local edit_cmd0 = (edit_cmd or "hide edit")
  local cur_pos = getcurpos()
  for _, c in ipairs(vim.b.nvlime_compiler_note_coords) do
    if vim.fn["nvlime#ui#MatchCoord"](c, cur_pos[1], cur_pos[2]) then
      note_coord = c
      __fnl_global__return()
    else
    end
  end
  if not note_coord then
    __fnl_global__return()
  else
  end
  local raw_note_loc = vim.fn["nvlime#Get"](vim.b.nvlime_compiler_note_list[note_coord.id], "LOCATION", nil)
  local pcall_result
  local function _6_()
    local note_loc = vim.fn["nvlime#ParseSourceLocation"](raw_note_loc)
    return vim.fn["nvlime#GetValidSourceLocation"](note_loc)
  end
  pcall_result = pcall(_6_)
  local valid_loc
  if pcall_result[1] then
    valid_loc = pcall_result[2]
  else
    valid_loc = {}
  end
  if ((#valid_loc > 0) and valid_loc[1] and (valid_loc[1] ~= nil)) then
    local orig_win = getbufvar("%", "nvlime_notes_orig_win", nil)
    local _let_8_ = ui["choose-window-with-count"](orig_win)
    local win_to_go = _let_8_[1]
    local count_specified = _let_8_[2]
    if (win_to_go > 0) then
      win_gotoid(win_to_go)
    else
    end
    if ((win_to_go <= 0) and count_specified) then
      __fnl_global__return()
    else
    end
    return ui["show-source"](vim.b.nvlime_conn, valid_loc, edit_cmd0, count_specified)
  else
    if (raw_note_loc and (raw_note_loc[0].name == "ERROR")) then
      return ui["err-msg"](raw_note_loc[1])
    else
      return ui["err-msg"]("No source available.")
    end
  end
end
return __fnl_global__compiler_2dnotes
