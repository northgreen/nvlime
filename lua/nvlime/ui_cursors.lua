local search = require("nvlime.search")

local ui_cursors = {}

-- ============================================================================
-- Cursor/Expression helpers migrated from autoload/nvlime/ui.vim (lines 480-934)
-- ============================================================================

--- Get character under cursor
local function cur_char()
  return vim.fn.matchstr(vim.fn.getline("."), "\\%" .. vim.fn.col(".") .. "c.")
end

--- Get atom under cursor (with expanded iskeyword for Lisp operators)
local function cur_atom()
  local old_kw = vim.o.iskeyword
  vim.o.iskeyword = old_kw .. ",+,-,*,/,%,<,=,>,:,$,?,!,@-@,94,~,#,|,&,.,{,},[,]"
  local result = vim.fn.expand("<cword>")
  vim.o.iskeyword = old_kw
  return result
end

--- Get symbol at cursor (quote + atom)
local function cur_symbol()
  local sym = cur_atom()
  if #sym > 0 then
    return "'" .. sym
  end
end

--- Get text between two positions [line, col]
local function get_text(from_pos, to_pos)
  local s_line, s_col = from_pos[1], from_pos[2]
  local e_line, e_col = to_pos[1], to_pos[2]
  local lines = vim.fn.getline(s_line, e_line)
  if #lines == 1 then
    lines[1] = vim.fn.strpart(lines[1], s_col - 1, e_col - s_col + 1)
  elseif #lines > 1 then
    lines[1] = vim.fn.strpart(lines[1], s_col - 1)
    lines[#lines] = vim.fn.strpart(lines[#lines], 0, e_col)
  end
  return table.concat(lines, "\n")
end

--- Check if cursor is inside a skip region (string, comment, etc.)
local function in_skip_region_3f(line, col)
  if not (vim.b.current_syntax ~= nil) then
    return false
  end
  local skip_groups = {"string", "character", "comment", "singlequote", "escape", "symbol"}
  local synstack = vim.fn.synstack(line, col)
  local len = #synstack
  for _, synid in ipairs({synstack[len], synstack[math.max(1, len - 1)], synstack[math.max(1, len - 2)]}) do
    local name = string.lower(vim.fn.synIDattr(synid, "name"))
    for _, pattern in ipairs(skip_groups) do
      if string.find(name, pattern, 1, true) then
        return true
      end
    end
  end
  return false
end

local cur_expr_pos_search_flags = {
  begin = {"cbnW", "bnW", "bnW"},
  ["end"] = {"nW", "cnW", "nW"},
}

--- Find expression position (begin or end)
local function cur_expr_pos(cur_char_val, side)
  side = side or "begin"

  local flags
  if cur_char_val == "(" then
    flags = cur_expr_pos_search_flags[side][1]
  elseif cur_char_val == ")" then
    flags = cur_expr_pos_search_flags[side][2]
  else
    flags = cur_expr_pos_search_flags[side][3]
  end

  -- No skip expression needed when cursor is already in a skip region
  -- searchpairpos will handle the matching; we rely on in_skip_region_3f for validation
  return vim.fn.searchpairpos("(", "", ")", flags, "0")
end

--- Get expression under cursor
local function cur_expr(return_pos)
  return_pos = return_pos or false
  local cur_ch = cur_char()
  local from_pos = cur_expr_pos(cur_ch, "begin")
  local to_pos = cur_expr_pos(cur_ch, "end")
  local expr = get_text(from_pos, to_pos)
  if return_pos then
    return expr, from_pos, to_pos
  end
  return expr
end

--- Get top-level expression position
local function cur_top_expr_pos(side)
  side = side or "begin"
  local search_flags = side == "begin" and "bW" or "W"

  local last_pos = {0, 0}
  local old_cur_pos = vim.fn.getcurpos()
  local cur_level = 1

  -- Helper: search for paren position using search pair logic
  local function search_paren_pos(flags)
    local s_skip = "0"
    return vim.fn.searchpairpos("(", "", ")", flags, s_skip)
  end

  while true do
    local cur_pos = search_paren_pos(search_flags)
    if cur_pos[1] <= 0 or cur_pos[2] <= 0 then
      break
    end
    -- Check not in comment or string
    local at_line, at_col = cur_pos[1], cur_pos[2]
    if not in_skip_region_3f(at_line, at_col) then
      last_pos = cur_pos
      cur_level = cur_level + 1
    end
    -- Safety: limit iterations to avoid infinite loops
    if cur_level > 1000 then
      break
    end
  end

  -- Restore cursor position
  vim.fn.setpos(".", old_cur_pos)

  if last_pos[1] > 0 and last_pos[2] > 0 then
    return last_pos
  else
    local ch = cur_char()
    if ch == "(" or ch == ")" then
      return vim.fn.searchpairpos("(", "", ")", search_flags .. "c", "0")
    else
      return {0, 0}
    end
  end
end

--- Get top-level expression under cursor
local function cur_top_expr(return_pos)
  return_pos = return_pos or false
  local top_pos = cur_top_expr_pos("begin")
  local s_line, s_col = top_pos[1], top_pos[2]

  if s_line > 0 and s_col > 0 then
    local old_cur_pos = vim.fn.getcurpos()
    vim.fn.setpos(".", {0, s_line, s_col, 0})
    local result
    if return_pos then
      local expr, from_pos, to_pos = cur_expr(true)
      result = {expr, from_pos, to_pos}
    else
      result = cur_expr()
    end
    vim.fn.setpos(".", old_cur_pos)
    return result
  else
    if return_pos then
      return "", {0, 0}, {0, 0}
    end
    return ""
  end
end

--- Get expression or fall back to atom
local function cur_expr_or_atom()
  local str = cur_expr()
  if #str <= 0 then
    str = cur_atom()
  end
  return str
end

--- Get visual selection text
local function cur_selection(return_pos)
  return_pos = return_pos or false
  local sel_start = vim.fn.getpos("'<")
  local sel_end = vim.fn.getpos("'>")
  local lines = vim.fn.getline(sel_start[1], sel_end[1])
  if sel_start[1] == sel_end[1] then
    lines[1] = vim.fn.strpart(lines[1], sel_start[2] - 1, sel_end[2] - sel_start[2] + 1)
  else
    lines[1] = vim.fn.strpart(lines[1], sel_start[2] - 1)
    local last_idx = #lines
    lines[last_idx] = vim.fn.strpart(lines[last_idx], 0, sel_end[2])
  end

  if return_pos then
    return table.concat(lines, "\n"), {sel_start[1], sel_start[2]}, {sel_end[1], sel_end[2]}
  else
    return table.concat(lines, "\n")
  end
end

--- Get operator at cursor (same-column constraint)
local function cur_operator()
  local line, col = vim.fn.getcurpos()[1], vim.fn.getcurpos()[2]
  local result = search.pair_paren(line, col, {backward = true, ["same-column?"] = true})
  local s_line, s_col = result[1], result[2]
  if s_line > 0 and s_col > 0 then
    local full_line = vim.fn.getline(s_line)
    local rest = string.sub(full_line, s_col)
    -- Match: ( followed by optional whitespace, then keyword chars
    local m = rest:match("^%(%s*(%S+)")
    if m then
      return m
    end
  end
  return ""
end

--- Get surrounding operator (no same-column constraint)
local function surrounding_operator()
  local line, col = vim.fn.getcurpos()[1], vim.fn.getcurpos()[2]
  local result = search.pair_paren(line, col, {backward = true})
  local s_line, s_col = result[1], result[2]
  if s_line > 0 and s_col > 0 then
    local full_line = vim.fn.getline(s_line)
    local rest = string.sub(full_line, s_col)
    local m = rest:match("^%(%s*(%S+)")
    if m then
      return m
    end
  end
  return ""
end

-- ============================================================================
-- Public API
-- ============================================================================

ui_cursors.cur_char = cur_char
ui_cursors.cur_atom = cur_atom
ui_cursors.cur_symbol = cur_symbol
ui_cursors.get_text = get_text
ui_cursors.cur_expr_pos = cur_expr_pos
ui_cursors.cur_expr = cur_expr
ui_cursors.cur_top_expr_pos = cur_top_expr_pos
ui_cursors.cur_top_expr = cur_top_expr
ui_cursors.cur_expr_or_atom = cur_expr_or_atom
ui_cursors.cur_selection = cur_selection
ui_cursors.cur_operator = cur_operator
ui_cursors.surrounding_operator = surrounding_operator

return ui_cursors
