local search = require("nvlime.search")
local ui_cursors = {}
local function cur_char()
  return vim.fn.matchstr(vim.fn.getline("."), ("\\%" .. vim.fn.col(".") .. "c."))
end
local function cur_atom()
  local old_kw = vim.o.iskeyword
  vim.o.iskeyword = (old_kw .. ",+,-,*,/,%,<,=,>,:,$,?,!,@-@,94,~,#,|,&,.,{,},[,]")
  local result = vim.fn.expand("<cword>")
  vim.o.iskeyword = old_kw
  return result
end
local function cur_symbol()
  local sym = cur_atom()
  if (#sym > 0) then
    return ("'" .. sym)
  else
    return ""
  end
end
local function get_text(from_pos, to_pos)
  local s_line = from_pos[1]
  local s_col = from_pos[2]
  local e_line = to_pos[1]
  local e_col = to_pos[2]
  local lines = vim.fn.getline(s_line, e_line)
  if (#lines == 1) then
    lines[1] = vim.fn.strpart(lines[1], (s_col - 1), ((e_col - s_col) + 1))
  elseif (#lines > 1) then
    lines[1] = vim.fn.strpart(lines[1], (s_col - 1))
    lines[#lines] = vim.fn.strpart(lines[#lines], 0, e_col)
  else
  end
  return table.concat(lines, "\n")
end
local function in_skip_region_3f(line, col)
  if (vim.b.current_syntax ~= nil) then
    local skip_groups = {"string", "character", "comment", "singlequote", "escape", "symbol"}
    local synstack = vim.fn.synstack(line, col)
    local len = #synstack
    local ids = {synstack[len], synstack[math.max(1, (len - 1))], synstack[math.max(1, (len - 2))]}
    local found = false
    for _, synid in ipairs(ids) do
      if found then break end
      local name = string.lower(vim.fn.synIDattr(synid, "name"))
      for _0, pattern in ipairs(skip_groups) do
        if found then break end
        if string.find(name, pattern, 1, true) then
          found = true
        else
        end
      end
    end
    return found
  else
    return nil
  end
end
local cur_expr_pos_search_flags = {begin = {"cbnW", "bnW", "bnW"}, ["end"] = {"nW", "cnW", "nW"}}
local function cur_expr_pos(cur_char_val, side)
  local side0 = (side or "begin")
  local flags
  if (cur_char_val == "(") then
    flags = cur_expr_pos_search_flags[side0][1]
  elseif (cur_char_val == ")") then
    flags = cur_expr_pos_search_flags[side0][2]
  else
    flags = cur_expr_pos_search_flags[side0][3]
  end
  return vim.fn.searchpairpos("(", "", ")", flags, "0")
end
local function cur_expr(return_pos)
  local return_pos0 = (return_pos or false)
  local cur_ch = cur_char()
  local from_pos = cur_expr_pos(cur_ch, "begin")
  local to_pos = cur_expr_pos(cur_ch, "end")
  local expr = get_text(from_pos, to_pos)
  if return_pos0 then
    return expr, from_pos, to_pos
  else
    return expr
  end
end
local function cur_top_expr_pos(side)
  local side0 = (side or "begin")
  local search_flags
  if (side0 == "begin") then
    search_flags = "bW"
  else
    search_flags = "W"
  end
  local old_cur_pos = vim.fn.getcurpos()
  local last_pos = {0, 0}
  local cur_level = 1
  while true do
    local cur_pos = vim.fn.searchpairpos("(", "", ")", search_flags, "0")
    if ((cur_pos[1] <= 0) or (cur_pos[2] <= 0)) then
      break
    else
    end
    if not in_skip_region_3f(cur_pos[1], cur_pos[2]) then
      last_pos = cur_pos
      cur_level = (cur_level + 1)
    else
    end
    if (cur_level > 1000) then
      break
    else
    end
  end
  vim.fn.setpos(".", old_cur_pos)
  if ((last_pos[1] > 0) and (last_pos[2] > 0)) then
    return last_pos
  else
    local ch = cur_char()
    if ((ch == "(") or (ch == ")")) then
      return vim.fn.searchpairpos("(", "", ")", (search_flags .. "c"), "0")
    else
      return {0, 0}
    end
  end
end
local function cur_top_expr(return_pos)
  local return_pos0 = (return_pos or false)
  local top_pos = cur_top_expr_pos("begin")
  local s_line = top_pos[1]
  local s_col = top_pos[2]
  if ((s_line > 0) and (s_col > 0)) then
    local old_cur_pos = vim.fn.getcurpos()
    vim.fn.setpos(".", {0, s_line, s_col, 0})
    local result
    if return_pos0 then
      local expr, from_pos, to_pos = cur_expr(true)
      result = {expr, from_pos, to_pos}
    else
      result = cur_expr()
    end
    vim.fn.setpos(".", old_cur_pos)
    return result
  else
    if return_pos0 then
      return "", {0, 0}, {0, 0}
    else
      return ""
    end
  end
end
local function cur_expr_or_atom()
  local str = cur_expr()
  if (#str > 0) then
    return str
  else
    return cur_atom()
  end
end
local function cur_selection(return_pos)
  local return_pos0 = (return_pos or false)
  local sel_start = vim.fn.getpos("'<")
  local sel_end = vim.fn.getpos("'>")
  local lines = vim.fn.getline(sel_start[1], sel_end[1])
  if (sel_start[1] == sel_end[1]) then
    lines[1] = vim.fn.strpart(lines[1], (sel_start[2] - 1), ((sel_end[2] - sel_start[2]) + 1))
  else
    lines[1] = vim.fn.strpart(lines[1], (sel_start[2] - 1))
    local last_idx = #lines
    lines[last_idx] = vim.fn.strpart(lines[last_idx], 0, sel_end[2])
  end
  if return_pos0 then
    return table.concat(lines, "\n"), {sel_start[1], sel_start[2]}, {sel_end[1], sel_end[2]}
  else
    return table.concat(lines, "\n")
  end
end
local function cur_operator()
  local cur_pos = vim.fn.getcurpos()
  local line = cur_pos[1]
  local col = cur_pos[2]
  local result = search.pair_paren(line, col, {backward = true, ["same-column?"] = true})
  local s_line = result[1]
  local s_col = result[2]
  if ((s_line > 0) and (s_col > 0)) then
    local full_line = vim.fn.getline(s_line)
    local rest = string.sub(full_line, s_col)
    local m = string.match(rest, "^%(%s*(%S+)")
    return (m or "")
  else
    return ""
  end
end
local function surrounding_operator()
  local cur_pos = vim.fn.getcurpos()
  local line = cur_pos[1]
  local col = cur_pos[2]
  local result = search.pair_paren(line, col, {backward = true})
  local s_line = result[1]
  local s_col = result[2]
  if ((s_line > 0) and (s_col > 0)) then
    local full_line = vim.fn.getline(s_line)
    local rest = string.sub(full_line, s_col)
    local m = string.match(rest, "^%(%s*(%S+)")
    return (m or "")
  else
    return ""
  end
end
ui_cursors["cur_char"] = cur_char
ui_cursors["cur_atom"] = cur_atom
ui_cursors["cur_symbol"] = cur_symbol
ui_cursors["get_text"] = get_text
ui_cursors["cur_expr_pos"] = cur_expr_pos
ui_cursors["cur_expr"] = cur_expr
ui_cursors["cur_top_expr_pos"] = cur_top_expr_pos
ui_cursors["cur_top_expr"] = cur_top_expr
ui_cursors["cur_expr_or_atom"] = cur_expr_or_atom
ui_cursors["cur_selection"] = cur_selection
ui_cursors["cur_operator"] = cur_operator
ui_cursors["surrounding_operator"] = surrounding_operator
return ui_cursors
