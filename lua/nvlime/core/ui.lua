local nvim_set_current_win = vim.api.nvim_set_current_win
local nvim_set_option_value = vim.api.nvim_set_option_value
local nvim_buf_set_var = vim.api.nvim_buf_set_var
local nvim_buf_get_var = vim.api.nvim_buf_get_var
local nvim_win_set_cursor = vim.api.nvim_win_set_cursor
local nvim_tabpage_get_win = vim.api.nvim_tabpage_get_win
local nvim_list_tabpages = vim.api.nvim_list_tabpages
local bufnr = vim.fn.bufnr
local bufwinid = vim.fn.bufwinid
local win_getid = vim.fn.win_getid
local win_findbuf = vim.fn.win_findbuf
local win_id2win = vim.fn.win_id2win
local getline = vim.fn.getline
local setline = vim.fn.setline
local cursor = vim.fn.cursor
local line = vim.fn.line
local strdisplaywidth = vim.fn.strdisplaywidth
local byte2line = vim.fn.byte2line
local line2byte = vim.fn.line2byte
local matchaddpos = vim.fn.matchaddpos
local matchdelete = vim.fn.matchdelete
local filereadable = vim.fn.filereadable
local search = vim.fn.search
local searchpos = vim.fn.searchpos
local searchpair = vim.fn.searchpair
local getcurpos = vim.fn.getcurpos
local setpos = vim.fn.setpos
local synID = vim.fn.synID
local synIDattr = vim.fn.synIDattr
local synstack = vim.fn.synstack
local matchlist = vim.fn.matchlist
local escape = vim.fn.escape
local copy = vim.fn.copy
local ui = {}
vim.g["nvlime_horiz_sep"] = "\226\148\128"
vim.g["nvlime_vert_sep"] = "\226\148\130"
vim.g["nvlime_default_window_settings"] = {mrepl = {pos = "botright", size = 0, vertical = false}, trace = {pos = "botright", size = 0, vertical = false}}
local ui_instance = nil
ui.new = function()
  local self = {["buffer-package-map"] = {}, ["buffer-thread-map"] = {}}
  setmetatable(self, {__index = ui})
  return self
end
ui["get-ui"] = function()
  if not ui_instance then
    ui_instance = ui.new()
  else
  end
  return ui_instance
end
ui["cur-in-package"] = function()
  return (vim.b.nvlime_cur_pkg() or "")
end
ui["get-current-package"] = function(self, buf)
  local cur_buf = bufnr((buf or "%"))
  local buf_pkg = self["buffer-package-map"][cur_buf]
  if (buf_pkg and (type(buf_pkg) == "table")) then
    return buf_pkg
  else
    local in_pkg = ui["with-buffer"](cur_buf, ui["cur-in-package"])
    if (#in_pkg > 0) then
      local pkg = {in_pkg, in_pkg}
      self["buffer-package-map"][cur_buf] = pkg
      return pkg
    else
      return {"COMMON-LISP-USER", "CL-USER"}
    end
  end
end
ui["set-current-package"] = function(self, pkg, buf)
  self["buffer-package-map"][bufnr((buf or "%"))] = pkg
  return nil
end
ui["get-current-thread"] = function(self, buf)
  return (self["buffer-thread-map"][bufnr((buf or "%"))] or true)
end
ui["set-current-thread"] = function(self, thread, buf)
  self["buffer-thread-map"][bufnr((buf or "%"))] = thread
  return nil
end
ui["sldb-buf-name"] = function(conn, thread)
  return ("nvlime:/" .. conn.cb_data.name .. "/sldb/" .. thread)
end
ui["repl-buf-name"] = function(conn)
  return ("nvlime:/" .. conn.cb_data.name .. "/repl")
end
ui["mrepl-buf-name"] = function(conn, chan_obj)
  return ("nvlime:/" .. conn.cb_data.name .. "/mrepl " .. chan_obj.id)
end
ui["arglist-buf-name"] = function()
  return "nvlime:/arglist"
end
ui["trace-dialog-buf-name"] = function(conn)
  return ("nvlime:/" .. conn.cb_data.name .. "/trace")
end
ui["compiler-notes-buf-name"] = function(conn)
  return ("nvlime:/" .. conn.cb_data.name .. "/compiler-notes")
end
ui["server-buf-name"] = function(server_name)
  return ("nvlime:/" .. server_name)
end
ui["get-window-settings"] = function(win_name)
  local settings = vim.get(vim.g.nvlime_default_window_settings, win_name, nil)
  if not settings then
    error(("nvlime#ui#GetWindowSettings: unknown window " .. vim.inspect(win_name)))
  else
  end
  local settings0 = vim.deepcopy(settings)
  if vim.g.nvlime_window_settings then
    local user_settings = vim.get(vim.g.nvlime_window_settings, win_name, {})
    if (type(user_settings) == "function") then
      user_settings = user_settings()
    else
    end
    for sk, sv in pairs(user_settings) do
      settings0[sk] = sv
    end
  else
  end
  return {vim.get(settings0, "pos", "botright"), vim.get(settings0, "size", 0), vim.get(settings0, "vertical", false)}
end
ui["get-cur-window-layout"] = function()
  local old_win = win_getid()
  local old_ei = vim.o.eventignore
  local layout = {}
  vim.o.eventignore = "all"
  local function _7_()
    vim.cmd("windo call add(g:_nvlime_layout, {'id': win_getid(), 'height': winheight(0), 'width': winwidth(0)})")
    layout = vim.g._nvlime_layout
    vim.g._nvlime_layout = nil
    return nil
  end
  pcall(_7_)
  if win_id2win(old_win) then
    nvim_set_current_win(old_win)
  else
  end
  vim.o.eventignore = old_ei
  return layout
end
ui["restore-window-layout"] = function(layout)
  if not (#layout == vim.fn.winnr("$")) then
  else
  end
  local old_win = win_getid()
  local old_ei = vim.o.eventignore
  vim.o.eventignore = "all"
  local function _10_()
    for _, ws in ipairs(layout) do
      if win_id2win(ws.id) then
        nvim_set_current_win(ws.id)
        vim.cmd(("resize " .. ws.height))
        vim.cmd(("vertical resize " .. ws.width))
      else
      end
    end
    return nil
  end
  pcall(_10_)
  if win_id2win(old_win) then
    nvim_set_current_win(old_win)
  else
  end
  vim.o.eventignore = old_ei
  return nil
end
ui["keep-cur-window"] = function(func)
  local cur_win_id = win_getid()
  pcall(func)
  if win_id2win(cur_win_id) then
    return nvim_set_current_win(cur_win_id)
  else
    return nil
  end
end
local function win_getid_safe()
  return win_getid()
end
ui["with-buffer"] = function(buf, func, ev_ignore)
  local buf_win = bufwinid(buf)
  local buf_visible = (buf_win >= 0)
  local old_win = win_getid_safe()
  local old_lazyredraw = vim.o.lazyredraw
  local old_ei = vim.o.eventignore
  local ev_ignore0 = (ev_ignore or "all")
  vim.o.lazyredraw = true
  vim.o.eventignore = ev_ignore0
  local result
  local function _14_()
    if buf_visible then
      return ui["with-buffer-visible"](buf_win, func, old_ei)
    else
      return ui["with-buffer-hidden"](buf, func, old_ei, ev_ignore0)
    end
  end
  result = pcall(_14_)
  if win_id2win(old_win) then
    nvim_set_current_win(old_win)
  else
  end
  vim.o.lazyredraw = old_lazyredraw
  vim.o.eventignore = old_ei
  if result[1] then
    return result[2]
  else
    return error(result[2])
  end
end
ui["with-buffer-visible"] = function(buf_win, func, old_ei)
  nvim_set_current_win(buf_win)
  local saved_ei = vim.o.eventignore
  vim.o.eventignore = old_ei
  local result = func()
  vim.o.eventignore = saved_ei
  return result
end
ui["with-buffer-hidden"] = function(buf, func, old_ei, ev_ignore)
  local old_layout = ui["get-cur-window-layout"]()
  local function _18_()
    ui["open-buffer"](buf, false)
    local tmp_win_id = win_getid()
    local saved_ei = vim.o.eventignore
    vim.o.eventignore = old_ei
    local result = func()
    vim.o.eventignore = saved_ei
    vim.o.eventignore = ev_ignore
    do
      local win_num = win_id2win(tmp_win_id)
      if (win_num > 0) then
        vim.cmd((win_num .. "wincmd c"))
      else
      end
    end
    return result
  end
  pcall(_18_)
  vim.o.eventignore = ev_ignore
  return ui["restore-window-layout"](old_layout)
end
ui["open-buffer"] = function(name, create, pos, vertical, initial_size)
  local buf = bufnr(name, (create or false))
  if (buf <= 0) then
  else
  end
  if (bufwinid(buf) < 0) then
    local split_cmd = ("split #" .. buf)
    local split_cmd0
    if vertical then
      split_cmd0 = ("vertical " .. split_cmd)
    else
      split_cmd0 = split_cmd
    end
    local split_cmd1
    if ((initial_size or 0) > 0) then
      split_cmd1 = (initial_size .. split_cmd0)
    else
      split_cmd1 = split_cmd0
    end
    local pos0 = (pos or "")
    if (#pos0 > 0) then
      pcall(vim.cmd, (pos0 .. " " .. split_cmd1))
    else
      pcall(vim.cmd, split_cmd1)
    end
  else
  end
  if (bufwinid(buf) > 0) then
    nvim_set_current_win(bufwinid(buf))
  else
  end
  return buf
end
ui["open-buffer-with-win-settings"] = function(buf_name, buf_create, win_name)
  local win_pos, win_size, win_vert = ui["get-window-settings"](win_name)
  return ui["open-buffer"](buf_name, buf_create, win_pos, win_vert, win_size)
end
ui["close-buffer"] = function(buf)
  local win_id_list = win_findbuf(buf)
  if (#win_id_list <= 0) then
  else
  end
  local cur_win_id = win_getid()
  local old_lazyredraw = vim.o.lazyredraw
  local close_cur_win = false
  vim.o.lazyredraw = true
  local function _27_()
    for _, win_id in ipairs(win_id_list) do
      if (win_id == cur_win_id) then
        close_cur_win = true
      else
        if win_id2win(win_id) then
          nvim_set_current_win(win_id)
          vim.cmd("wincmd c")
        else
        end
      end
    end
    return nil
  end
  pcall(_27_)
  if (win_id2win(cur_win_id) and close_cur_win) then
    vim.cmd("wincmd c")
  else
  end
  vim.o.lazyredraw = old_lazyredraw
  return nil
end
ui["append-string"] = function(str, target_line)
  local last_line_nr = line("$")
  local to_append = (target_line or last_line_nr)
  local new_lines = vim.split(str, "\n", {trimempty = false})
  local sidx = 0
  local eidx = -1
  if (to_append > 0) then
    local line_to_append = getline(to_append)
    setline(to_append, (line_to_append .. new_lines[1]))
    sidx = 1
  else
  end
  if ((to_append < last_line_nr) and (#new_lines > 1)) then
    do
      local line_after = getline((to_append + 1))
      setline((to_append + 1), (new_lines[#new_lines] .. line_after))
    end
    eidx = -2
  else
  end
  do
    local start = (to_append + 1)
    local _end = (to_append + eidx)
    if (start <= _end) then
      local lines_to_add = {}
      for i = (sidx + 1), (eidx + 1) do
        lines_to_add[(i - 1)] = new_lines[i]
      end
      vim.api.nvim_buf_set_lines(0, start, _end, false, lines_to_add)
    else
    end
  end
  if not target_line then
    cursor(line("$"), 1)
  else
  end
  return (#new_lines + eidx + ( - sidx) + 1)
end
ui["replace-content"] = function(str, first_line, last_line)
  local first_line0 = (first_line or 1)
  local last_line0 = (last_line or "$")
  pcall(vim.cmd, (first_line0 .. "," .. last_line0 .. "delete _"))
  local str0
  if (first_line0 > 1) then
    str0 = ("\n" .. str)
  else
    str0 = str
  end
  ui["append-string"](str0, (first_line0 - 1))
  return cursor({first_line0, 1, 0, 1})
end
ui["indent-cur-line"] = function(indent)
  local indent_str
  if vim.o.expandtab then
    indent_str = string.rep(" ", indent)
  else
    local tabs = math.floor((indent / vim.o.tabstop))
    local remainder = (indent % vim.o.tabstop)
    indent_str = (string.rep("\t", tabs) .. string.rep(" ", remainder))
  end
  local current_line = getline(".")
  local new_line = string.gsub(current_line, "^%s*", indent_str)
  setline(".", new_line)
  local spaces = ui["calc-leading-spaces"](new_line)
  return vim.fn.setpos(".", {0, line("."), (spaces + 1), 0, indent})
end
ui["calc-leading-spaces"] = function(str, expand_tab)
  local n_str
  if expand_tab then
    n_str = string.gsub(str, "\t", string.rep(" ", vim.o.tabstop))
  else
    n_str = str
  end
  local spaces = string.find(n_str, "[^%s]")
  if spaces then
    return (spaces - 1)
  else
    return #n_str
  end
end
ui["cur-buffer-content"] = function(raw)
  local lines = getline(1, "$")
  if not raw then
    local filtered = {}
    for _, l in ipairs(lines) do
      if not string.find(l, "^%s*;") then
        filtered[#filtered] = l
      else
      end
    end
    lines = filtered
  else
  end
  return table.concat(lines, "\n")
end
ui["get-text"] = function(from_pos, to_pos)
  local s_line = from_pos[1]
  local s_col = from_pos[2]
  local e_line = to_pos[1]
  local e_col = to_pos[2]
  local lines = getline(s_line, e_line)
  if (#lines == 1) then
    lines[1] = string.sub(lines[1], s_col, (e_col - s_col - -1))
    return lines[1]
  else
    lines[1] = string.sub(lines[1], s_col)
    do
      local last_idx = #lines
      lines[last_idx] = string.sub(lines[last_idx], 1, e_col)
    end
    return table.concat(lines, "\n")
  end
end
ui["get-end-of-file-coord"] = function()
  local last_line_nr = line("$")
  local last_line = getline(last_line_nr)
  local last_col = #last_line
  local function _42_()
    if (last_col <= 0) then
      return 1
    else
      return last_col
    end
  end
  return {last_line_nr, _42_()}
end
ui["get-filetype-window-list"] = function(ft)
  local old_win_id = win_getid()
  local winid_list = {}
  local function _43_()
    vim.cmd("windo if &filetype == '", ft, "| call add(g:_nvlime_ft_wins, [win_getid(), bufname('%')])", "| endif")
    winid_list = (vim.g._nvlime_ft_wins or {})
    vim.g._nvlime_ft_wins = nil
    return nil
  end
  pcall(_43_)
  if win_id2win(old_win_id) then
    nvim_set_current_win(old_win_id)
  else
  end
  return winid_list
end
ui["choose-window-with-count"] = function(default_win)
  local count_specified = false
  local win_to_go
  if (vim.v.count > 0) then
    count_specified = true
    local wid = vim.fn.win_getid(vim.v.count)
    if (wid <= 0) then
      ui["err-msg"](("Invalid window number: " .. vim.v.count))
    else
    end
    win_to_go = wid
  else
    if (default_win and (win_id2win(default_win) > 0)) then
      win_to_go = default_win
    else
      local win_list = ui["get-filetype-window-list"]("lisp")
      if (#win_list > 0) then
        win_to_go = win_list[1][1]
      else
        win_to_go = 0
      end
    end
  end
  return {win_to_go, count_specified}
end
ui["is-yes-string"] = function(str)
  return not not string.find(str, "^[yY][eE][sS]?$")
end
ui["set-nvlime-buffer-opts"] = function(buf, conn)
  nvim_set_option_value("buftype", "nofile", {buf = buf})
  nvim_set_option_value("bufhidden", "hide", {buf = buf})
  nvim_set_option_value("swapfile", false, {buf = buf})
  nvim_set_option_value("buflisted", true, {buf = buf})
  return nvim_buf_set_var(buf, "nvlime_conn", conn)
end
ui["nvlime-buffer-initialized"] = function(buf)
  local val = pcall(nvim_buf_get_var, buf, "nvlime_conn")
  if val[1] then
    return not not val[2]
  else
    return false
  end
end
ui["err-msg"] = function(msg)
  vim.cmd("redraw")
  vim.cmd("echohl ErrorMsg")
  do
    local escaped = string.gsub(string.gsub(msg, "\\", "\\\\"), "\"", "\\\"")
    vim.cmd(("echom \"" .. escaped .. "\""))
  end
  return vim.cmd("echohl None")
end
ui["show-disassemble-form"] = function(conn, content)
  if not content then
    ui["err-msg"]("Blank disassemble.")
  else
  end
  return vim.fn.luaeval("require(\"nvlime.window.disassembly\").open(_A)", content)
end
ui["show-arglist"] = function(conn, content)
  return vim.fn.luaeval("require(\"nvlime.window.arglist\").show(_A)", content)
end
ui.pad = function(prefix, sep, max_len)
  return (prefix .. sep .. string.rep(" ", ((max_len - strdisplaywidth(prefix)) + 1)))
end
ui["match-coord"] = function(coord, cur_line, cur_col)
  local c_begin = coord.begin
  local c_end = coord["end"]
  local _51_
  if (not c_begin or not c_end) then
    local function _52_()
      return f
    end
    _51_ = _52_
  else
    _51_ = nil
  end
  local or_54_ = _51_
  if not or_54_ then
    if ((c_begin[1] == c_end[1]) and (cur_line == c_begin[1]) and (cur_col >= c_begin[2]) and (cur_col <= c_end[2])) then
      or_54_ = true
    else
      or_54_ = nil
    end
  end
  if not or_54_ then
    if (c_begin[1] < c_end[1]) then
      local _56_
      if ((cur_line == c_begin[1]) and (cur_col >= c_begin[2])) then
        _56_ = true
      else
        _56_ = nil
      end
      local or_58_ = _56_
      if not or_58_ then
        if ((cur_line == c_end[1]) and (cur_col <= c_end[2])) then
          or_58_ = true
        else
          or_58_ = nil
        end
      end
      if not or_58_ then
        if ((cur_line > c_begin[1]) and (cur_line < c_end[1])) then
          or_58_ = true
        else
          or_58_ = nil
        end
      end
      or_54_ = or_58_
    else
      or_54_ = nil
    end
  end
  if not or_54_ then
    local function _62_()
      return f
    end
    or_54_ = _62_
  end
  return or_54_
end
ui["compare-coords-forward"] = function(c1, c2)
  if (c1.begin[1] > c2.begin[1]) then
    return false
  elseif (c1.begin[1] < c2.begin[1]) then
    return true
  elseif (c1.begin[2] > c2.begin[2]) then
    return false
  elseif (c1.begin[2] < c2.begin[2]) then
    return true
  else
    return false
  end
end
ui["compare-coords-backward"] = function(c1, c2)
  if (c1.begin[1] > c2.begin[1]) then
    return true
  elseif (c1.begin[1] < c2.begin[1]) then
    return false
  elseif (c1.begin[2] > c2.begin[2]) then
    return true
  elseif (c1.begin[2] < c2.begin[2]) then
    return false
  else
    return false
  end
end
ui["sort-coords"] = function(coords, forward)
  local sorted = copy(coords)
  local function _65_()
    if forward then
      return ui["compare-coords-forward"]
    else
      return ui["compare-coords-backward"]
    end
  end
  table.sort(sorted, _65_())
  return sorted
end
ui["find-next-coord"] = function(cur_pos, sorted_coords, forward)
  local found = nil
  for i = 1, #sorted_coords do
    if not found then
      local c = sorted_coords[i]
      local c_begin = c.begin
      local matches
      if forward then
        matches = ((c_begin[1] > cur_pos[1]) or ((c_begin[1] == cur_pos[1]) and (c_begin[2] > cur_pos[2])))
      else
        matches = ((c_begin[1] < cur_pos[1]) or ((c_begin[1] == cur_pos[1]) and (c_begin[2] < cur_pos[2])))
      end
      if matches then
        found = c
      else
      end
    else
    end
  end
  return found
end
ui["coords-to-match-pos"] = function(coords)
  local pos_list = {}
  for _, co in ipairs(coords) do
    local cb = co.begin
    local ce = co["end"]
    if (cb[1] == ce[1]) then
      local cline = cb[1]
      local col = cb[2]
      local len = ((ce[2] - cb[2]) + 1)
      table.insert(pos_list, {cline, col, len})
    else
      for ln = cb[1], (ce[1] + 1) do
        if (ln == cb[1]) then
          local col = cb[2]
          local len = ((#getline(ln) - cb[2]) + 1)
          table.insert(pos_list, {ln, col, len})
        elseif (ln == ce[1]) then
          local col = 1
          local len = ce[2]
          table.insert(pos_list, {ln, col, len})
        else
          table.insert(pos_list, ln)
        end
      end
    end
  end
  return pos_list
end
ui["match-add-coords"] = function(group, coords)
  local pos_list = ui["coords-to-match-pos"](coords)
  local match_list = {}
  local stride = 8
  local total_len = #pos_list
  for i = 0, (total_len - 1), stride do
    local slice = {}
    local _end = min((i + stride), total_len)
    for j = (i + 1), _end do
      table.insert(slice, pos_list[j])
    end
    if (group == "nvlime_replCoord") then
      table.insert(match_list, matchaddpos(group, slice, -1))
    else
      table.insert(match_list, matchaddpos(group, slice))
    end
  end
  return match_list
end
ui["match-delete-list"] = function(match_list)
  for _, m in ipairs(match_list) do
    pcall(matchdelete, m)
  end
  return nil
end
ui["in-comment"] = function(cur_pos)
  local has_syntax = (synstack(cur_pos[2], cur_pos[3]) > 0)
  local syn_name
  if has_syntax then
    syn_name = synIDattr(synstack(cur_pos[2], cur_pos[3])[1], "name")
  else
    syn_name = nil
  end
  if (has_syntax and syn_name) then
    return not not string.find(syn_name, "[Cc]omment")
  else
    if (searchpair("#|", "", "|#", "bnW") > 0) then
      return true
    else
      return nil
    end
  end
end
ui["in-string"] = function(cur_pos)
  local has_syntax = (synstack(cur_pos[2], cur_pos[3]) > 0)
  local syn_name
  if has_syntax then
    syn_name = synIDattr(synstack(cur_pos[2], cur_pos[3])[1], "name")
  else
    syn_name = nil
  end
  if (has_syntax and syn_name) then
    return not not string.find(syn_name, "[Ss]tring")
  else
    local pattern = "\\v((^|[^\\\\])@<=\")|(((^|[^\\\\])((\\\\\\\\)+))@<=\")"
    local old_pos = getcurpos()
    local quote_count = 0
    local quote_pos = searchpos(pattern, "bW")
    while ((quote_pos[1] > 0) and (quote_pos[2] > 0)) do
      quote_count = (quote_count + 1)
      quote_pos = searchpos(pattern, "bW")
    end
    setpos(".", old_pos)
    return (math.fmod(quote_count, 2) > 0)
  end
end
ui["normalize-package-name"] = function(name)
  local matches = matchlist(name, "^%(#[%:]?%:%)%(%.%+%)")
  if (#matches > 3) then
    return string.upper(matches[3])
  else
    local matches2 = matchlist(name, "^\"%(%.%+%)\"")
    if (#matches2 > 1) then
      return string.upper(matches2[1])
    else
      return ""
    end
  end
end
ui["jump-to-or-open-file"] = function(file_path, byte_pos, snippet, edit_cmd, force_open)
  local buf_exists = false
  if not force_open then
    local file_buf = bufnr(file_path)
    if (file_buf > 0) then
      local buf_win = bufwinid(file_buf)
      if (buf_win > 0) then
        nvim_set_current_win(buf_win)
        buf_exists = true
      else
        local win_list = win_findbuf(file_buf)
        if (#win_list > 0) then
          nvim_set_current_win(win_list[1])
          buf_exists = true
        else
        end
      end
    else
    end
  else
  end
  if buf_exists then
    return vim.cmd("normal! m'")
  else
    vim.cmd("normal! m'")
    if (type(file_path) == "number") then
      local existing_buf = bufnr(file_path, true)
      if (existing_buf > 0) then
        local pcall_result = pcall(vim.cmd, (edit_cmd .. " #" .. file_path))
        if not pcall_result[1] then
          local cur_buf = bufnr("%")
          if (cur_buf ~= file_path) then
            return error(pcall_result[2])
          else
            return nil
          end
        else
          return nil
        end
      else
        ui["err-msg"](("Buffer " .. file_path .. " does not exist."))
        return 
      end
    else
      if (string.sub(file_path, 1, 7) == "sftp://") then
        local esc_path = escape(file_path, " \\")
        return vim.cmd((edit_cmd .. " " .. esc_path))
      else
        if filereadable(file_path) then
          local esc_path = escape(file_path, " \\")
          return vim.cmd((edit_cmd .. " " .. esc_path))
        else
          ui["err-msg"](("Not readable: " .. file_path))
          return 
        end
      end
    end
  end
end
if __fnl_global__byte_2dpos then
  local src_line = byte2line(__fnl_global__byte_2dpos)
  setpos(".", {0, src_line, 1, 0, 1})
  do
    local cur_byte = (line2byte(".") + vim.fn.col(".") + -1)
    if ((__fnl_global__byte_2dpos - cur_byte) > 0) then
      setpos(".", {0, src_line, ((__fnl_global__byte_2dpos - cur_byte) + 1), 0})
    else
    end
  end
  if snippet then
    local first_line = string.match(snippet, "[^\n]*")
    local escaped = string.gsub(first_line, "\\", "\\\\")
    local to_search = ("\\V" .. escaped)
    setpos(".", {src_line, 1, 0, 1})
    search(to_search, "cW")
  else
  end
  vim.cmd("redraw")
else
end
ui["show-source"] = function(conn, loc, edit_cmd, force_open)
  local edit_cmd0 = (edit_cmd or "hide edit")
  local force_open0 = (force_open or false)
  local file_name = loc[1]
  local byte_pos = loc[2]
  local snippet = loc[3]
  if not file_name then
    return vim.fn.luaeval("require\"nvlime.window.documentation\".open(_A)", ("Source form:\n\n" .. snippet))
  else
    return ui["jump-to-or-open-file"](file_name, byte_pos, snippet, edit_cmd0, force_open0)
  end
end
local function _94_(self, key)
  return self[string.gsub(key, "_", "-")]
end
setmetatable(ui, {__index = _94_})
return ui
