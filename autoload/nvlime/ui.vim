" nvlime/ui.vim — VimScript shim forwarding to Fennel core modules.
" Replaces the original 1520-line ui.vim with a thin forwarding layer.
"
" Private helpers (s:*) and cursor/coord functions not yet in Fennel
" remain in VimScript. Public functions that exist in Fennel forward
" via luaeval().

" ============================================================================
" Global variables — kept for transition compatibility
" ============================================================================

let g:nvlime_horiz_sep = '─'
let g:nvlime_vert_sep = '│'

let g:nvlime_default_window_settings = {
      \ 'mrepl': {'pos': 'botright', 'size': 0, 'vertical': v:false},
      \ 'trace': {'pos': 'botright', 'size': 0, 'vertical': v:false},
      \ }

" ============================================================================
" UI singleton
" ============================================================================

function! nvlime#ui#New()
  let s:lua_ui = luaeval('require("nvlime.core.ui")')
  return {
        \ '_lua_ui': s:lua_ui,
        \ 'buffer_package_map': {},
        \ 'buffer_thread_map': {},
        \ 'GetCurrentPackage': function('nvlime#ui#GetCurrentPackage'),
        \ 'SetCurrentPackage': function('nvlime#ui#SetCurrentPackage'),
        \ 'GetCurrentThread': function('nvlime#ui#GetCurrentThread'),
        \ 'SetCurrentThread': function('nvlime#ui#SetCurrentThread'),
        \ 'OnDebug': function('nvlime#ui#OnDebug'),
        \ 'OnDebugActivate': function('nvlime#ui#OnDebugActivate'),
        \ 'OnDebugReturn': function('nvlime#ui#OnDebugReturn'),
        \ 'OnWriteString': function('nvlime#ui#OnWriteString'),
        \ 'OnReadString': function('nvlime#ui#OnReadString'),
        \ 'OnReadFromMiniBuffer': function('nvlime#ui#OnReadFromMiniBuffer'),
        \ 'OnIndentationUpdate': function('nvlime#ui#OnIndentationUpdate'),
        \ 'OnNewFeatures': function('nvlime#ui#OnNewFeatures'),
        \ 'OnInvalidRPC': function('nvlime#ui#OnInvalidRPC'),
        \ 'OnInspect': function('nvlime#ui#OnInspect'),
        \ 'OnTraceDialog': function('nvlime#ui#OnTraceDialog'),
        \ 'OnXRef': function('nvlime#ui#OnXRef'),
        \ 'OnCompilerNotes': function('nvlime#ui#OnCompilerNotes'),
        \ 'OnThreads': function('nvlime#ui#OnThreads'),
        \ }
endfunction

function! nvlime#ui#GetUI()
  if !exists('g:nvlime_ui')
    let g:nvlime_ui = nvlime#ui#New()
  endif
  return g:nvlime_ui
endfunction

" ============================================================================
" UI dict methods — context (package/thread) getters/setters
" ============================================================================

function! nvlime#ui#GetCurrentPackage(buf = '%') dict
  let lua_ui = self._lua_ui
  return luaeval('local ui = _A[1] return ui["get-current-package"](ui, _A[2])',
        \ [lua_ui, a:buf])
endfunction

function! nvlime#ui#SetCurrentPackage(pkg, buf = '%') dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["set-current-package"](_A[1], _A[2], _A[3])',
        \ [lua_ui, a:pkg, a:buf])
endfunction

function! nvlime#ui#GetCurrentThread(buf = '%') dict
  let lua_ui = self._lua_ui
  return luaeval('local ui = _A[1] return ui["get-current-thread"](ui, _A[2])',
        \ [lua_ui, a:buf])
endfunction

function! nvlime#ui#SetCurrentThread(thread, buf = '%') dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["set-current-thread"](_A[1], _A[2], _A[3])',
        \ [lua_ui, a:thread, a:buf])
endfunction

" ============================================================================
" UI dict methods — event handlers (forward to Fennel ui_events)
" ============================================================================

function! nvlime#ui#OnDebug(conn, thread, level, condition, restarts, frames, conts) dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["on-debug"](_A[1], _A[2], _A[3], _A[4], _A[5], _A[6], _A[7], _A[8])',
        \ [lua_ui, a:conn, a:thread, a:level, a:condition, a:restarts, a:frames, a:conts])
endfunction

function! nvlime#ui#OnDebugActivate(conn, thread, level, select) dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["on-debug-activate"](_A[1], _A[2], _A[3], _A[4], _A[5])',
        \ [lua_ui, a:conn, a:thread, a:level, a:select])
endfunction

function! nvlime#ui#OnDebugReturn(conn, thread, level, stepping) dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["on-debug-return"](_A[1], _A[2], _A[3], _A[4], _A[5])',
        \ [lua_ui, a:conn, a:thread, a:level, a:stepping])
endfunction

function! nvlime#ui#OnWriteString(conn, str, str_type, thread = v:null) dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["on-write-string"](_A[1], _A[2], _A[3], _A[4], _A[5])',
        \ [lua_ui, a:conn, a:str, a:str_type, a:thread])
endfunction

" OnReadString and OnReadFromMiniBuffer: keep VimScript implementations
" because the Fennel ui_events references undefined callbacks.

function! nvlime#ui#OnReadString(conn, thread, ttag) dict
  call luaeval("require('nvlime.core.ui.input').from_buffer(_A[1], _A[2], _A[3], function() require('nvlime.core.ui_events')['return-mini-buffer-content'](_A[1], _A[2]) end)",
        \ [a:conn, a:thread, a:ttag])
endfunction

function! nvlime#ui#OnReadFromMiniBuffer(conn, thread, ttag, prompt, init_val) dict
  call luaeval("require('nvlime.core.ui.input').from_buffer(_A[1], _A[2], _A[3], function() require('nvlime.core.ui_events')['return-string-input-complete'](_A[1], _A[2]) end)",
        \ [a:conn, a:thread, a:ttag])
endfunction

function! nvlime#ui#OnIndentationUpdate(conn, indent_info) dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["on-indentation-update"](_A[1], _A[2], _A[3])',
        \ [lua_ui, a:conn, a:indent_info])
endfunction

function! nvlime#ui#OnNewFeatures(conn, new_features)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  call luaeval('_A[1]["on-new-features"](_A[1], _A[2], _A[3])',
        \ [lua_ui, a:conn, a:new_features])
endfunction

function! nvlime#ui#OnInvalidRPC(conn, rpc_id, err_msg) dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["on-invalid-rpc"](_A[1], _A[2], _A[3], _A[4])',
        \ [lua_ui, a:conn, a:rpc_id, a:err_msg])
endfunction

function! nvlime#ui#OnInspect(conn, content, thread, tag) dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["on-inspect"](_A[1], _A[2], _A[3], _A[4], _A[5])',
        \ [lua_ui, a:conn, a:content, a:thread, a:tag])
endfunction

function! nvlime#ui#OnTraceDialog(conn, spec_list, trace_count) dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["on-trace-dialog"](_A[1], _A[2], _A[3], _A[4])',
        \ [lua_ui, a:conn, a:spec_list, a:trace_count])
endfunction

function! nvlime#ui#OnXRef(conn, xref_list) dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["on-xref"](_A[1], _A[2], _A[3])',
        \ [lua_ui, a:conn, a:xref_list])
endfunction

function! nvlime#ui#OnCompilerNotes(conn, note_list, orig_win) dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["on-compiler-notes"](_A[1], _A[2], _A[3], _A[4])',
        \ [lua_ui, a:conn, a:note_list, a:orig_win])
endfunction

function! nvlime#ui#OnThreads(conn, thread_list) dict
  let lua_ui = self._lua_ui
  call luaeval('_A[1]["on-threads"](_A[1], _A[2], _A[3])',
        \ [lua_ui, a:conn, a:thread_list])
endfunction

" ============================================================================
" Standalone functions — forwarded to Fennel ui module
" ============================================================================

" --- Window settings ---

function! nvlime#ui#GetWindowSettings(win_name)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  return luaeval('local ui = _A[1] return ui["get-window-settings"](ui, _A[2])',
        \ [lua_ui, a:win_name])
endfunction

" --- Window layout ---

function! nvlime#ui#GetCurWindowLayout()
  let lua_ui = luaeval('require("nvlime.core.ui")')
  return luaeval('local ui = _A[1] return ui["get-cur-window-layout"](ui)',
        \ [lua_ui])
endfunction

function! nvlime#ui#RestoreWindowLayout(layout)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  call luaeval('local ui = _A[1] return ui["restore-window-layout"](ui, _A[2])',
        \ [lua_ui, a:layout])
endfunction

function! nvlime#ui#KeepCurWindow(Func)
  let cur_win_id = win_getid()
  try
    return a:Func()
  finally
    call win_gotoid(cur_win_id)
  endtry
endfunction

function! nvlime#ui#WithBuffer(buf, Func, ev_ignore = 'all')
  let buf_win = bufwinid(a:buf)
  let buf_visible = (buf_win >= 0) ? v:true : v:false

  let old_win = win_getid()

  let old_lazyredraw = &lazyredraw
  let &lazyredraw = 1

  let old_ei = &eventignore
  let &eventignore = a:ev_ignore

  try
    if buf_visible
      call win_gotoid(buf_win)
      try
        let &eventignore = old_ei
        return a:Func()
      finally
        let &eventignore = a:ev_ignore
      endtry
    else
      let old_layout = nvlime#ui#GetCurWindowLayout()
      try
        silent call nvlime#ui#OpenBuffer(a:buf, v:false)
        let tmp_win_id = win_getid()
        try
          let &eventignore = old_ei
          return a:Func()
        finally
          let &eventignore = a:ev_ignore
          execute win_id2win(tmp_win_id) . 'wincmd c'
        endtry
      finally
        call nvlime#ui#RestoreWindowLayout(old_layout)
      endtry
    endif
  finally
    call win_gotoid(old_win)
    let &lazyredraw = old_lazyredraw
    let &eventignore = old_ei
  endtry
endfunction

" --- Buffer opening/closing ---

function! nvlime#ui#OpenBuffer(name, create, pos = '', vertical = v:false, initial_size = 0)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  return luaeval('local ui = _A[1] return ui["open-buffer"](ui, _A[2], _A[3], _A[4], _A[5], _A[6])',
        \ [lua_ui, a:name, a:create, a:pos, a:vertical, a:initial_size])
endfunction

function! nvlime#ui#OpenBufferWithWinSettings(buf_name, buf_create, win_name)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  return luaeval('local ui = _A[1] return ui["open-buffer-with-win-settings"](ui, _A[2], _A[3], _A[4])',
        \ [lua_ui, a:buf_name, a:buf_create, a:win_name])
endfunction

function! nvlime#ui#CloseBuffer(buf)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  call luaeval('local ui = _A[1] ui["close-buffer"](ui, _A[2])',
        \ [lua_ui, a:buf])
endfunction

" --- Text manipulation ---

function! nvlime#ui#AppendString(str, line = v:null)
  let last_line_nr = line('$')
  let to_append = a:line is v:null ? last_line_nr : a:line

  let new_lines = split(a:str, "\n", v:true)
  let sidx = 0
  let eidx = -1

  if to_append > 0
    let line_to_append = getline(to_append)
    call setline(to_append, line_to_append .. new_lines[0])
    let sidx = 1
  endif

  if to_append < last_line_nr && len(new_lines) > 1
    let line_after_append = getline(to_append + 1)
    call setline(to_append + 1, new_lines[-1] .. line_after_append)
    let eidx = -2
  endif

  call append(to_append, new_lines[sidx:eidx])

  if a:line is v:null
    call cursor(line('$'), 1)
  endif

  return len(new_lines) + eidx - sidx + 1
endfunction

function! nvlime#ui#ReplaceContent(str, first_line = 1, last_line = '$')
  execute a:first_line .. ',' .. a:last_line .. 'delete _'

  if a:first_line > 1
    let str = "\n" .. a:str
  else
    let str = a:str
  endif
  let ret = nvlime#ui#AppendString(str, a:first_line - 1)
  call cursor([a:first_line, 1, 0, 1])
  return ret
endfunction

function! nvlime#ui#IndentCurLine(indent)
  if &expandtab
    let indent_str = repeat(' ', a:indent)
  else
    let indent_str = repeat("\<tab>", a:indent / &tabstop)
    let indent_str .= repeat(' ', a:indent % &tabstop)
  endif
  let line = getline('.')
  let new_line = substitute(line, '^\(\s*\)', indent_str, '')
  call setline('.', new_line)
  let spaces = nvlime#ui#CalcLeadingSpaces(new_line)
  call setpos('.', [0, line('.'), spaces + 1, 0, a:indent + 1])
endfunction

function! nvlime#ui#CalcLeadingSpaces(str, expand_tab = v:false)
  if a:expand_tab
    let n_str = substitute(a:str, "\t", repeat(' ', &tabstop), 'g')
  else
    let n_str = a:str
  endif
  let spaces = match(n_str, '[^[:blank:]]')
  if spaces < 0
    let spaces = len(n_str)
  endif
  return spaces
endfunction

" --- Text extraction ---

function! nvlime#ui#CurBufferContent(raw = v:false)
  let lines = getline(1, '$')
  if !a:raw
    let lines = filter(lines, { _, line -> line !~ '^\s*;' })
  endif

  return join(lines, "\n")
endfunction

function! nvlime#ui#GetText(from_pos, to_pos)
  let [s_line, s_col] = a:from_pos
  let [e_line, e_col] = a:to_pos

  let lines = getline(s_line, e_line)
  if len(lines) == 1
    let lines[0] = strpart(lines[0], s_col - 1, e_col - s_col + 1)
  elseif len(lines) > 1
    let lines[0] = strpart(lines[0], s_col - 1)
    let lines[-1] = strpart(lines[-1], 0, e_col)
  endif

  return join(lines, "\n")
endfunction

function! nvlime#ui#GetEndOfFileCoord()
  let lua_ui = luaeval('require("nvlime.core.ui")')
  return luaeval('local ui = _A[1] return ui["get-end-of-file-coord"](ui)',
        \ [lua_ui])
endfunction

" --- Window/file utilities ---

function! nvlime#ui#GetFiletypeWindowList(ft)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  return luaeval('local ui = _A[1] return ui["get-filetype-window-list"](ui, _A[2])',
        \ [lua_ui, a:ft])
endfunction

function! nvlime#ui#ChooseWindowWithCount(default_win)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  return luaeval('local ui = _A[1] return ui["choose-window-with-count"](ui, _A[2])',
        \ [lua_ui, a:default_win])
endfunction

function! nvlime#ui#IsYesString(str)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  return luaeval('local ui = _A[1] return ui["is-yes-string"](ui, _A[2])',
        \ [lua_ui, a:str])
endfunction

" --- Buffer options ---

function! nvlime#ui#SetNvlimeBufferOpts(buf, conn)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  call luaeval('local ui = _A[1] ui["set-nvlime-buffer-opts"](ui, _A[2], _A[3])',
        \ [lua_ui, a:buf, a:conn])
endfunction

function! nvlime#ui#NvlimeBufferInitialized(buf)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  return luaeval('local ui = _A[1] return ui["nvlime-buffer-initialized"](ui, _A[2])',
        \ [lua_ui, a:buf])
endfunction

" --- Error display ---

function! nvlime#ui#ErrMsg(msg)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  call luaeval('local ui = _A[1] ui["err-msg"](ui, _A[2])',
        \ [lua_ui, a:msg])
endfunction

" --- Window display ---

function! nvlime#ui#ShowDisassembleForm(conn, content)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  call luaeval('local ui = _A[1] ui["show-disassemble-form"](ui, _A[2], _A[3])',
        \ [lua_ui, a:conn, a:content])
endfunction

function! nvlime#ui#ShowArgList(conn, content)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  call luaeval('local ui = _A[1] ui["show-arglist"](ui, _A[2], _A[3])',
        \ [lua_ui, a:conn, a:content])
endfunction

" --- Pad helper ---

function! nvlime#ui#Pad(prefix, sep, max_len)
  let lua_ui = luaeval('require("nvlime.core.ui")')
  return luaeval('local ui = _A[1] return ui["pad"](ui, _A[2], _A[3], _A[4])',
        \ [lua_ui, a:prefix, a:sep, a:max_len])
endfunction

" --- Buffer naming ---

function! s:SetBufName(...)
  let name = extend(['nvlime:/'], a:000)
  return join(name, '/')
endfunction

function! nvlime#ui#SLDBBufName(conn, thread)
  return s:SetBufName(a:conn.cb_data.name, 'sldb', a:thread)
endfunction

function! nvlime#ui#REPLBufName(conn)
  return s:SetBufName(a:conn.cb_data.name, 'repl')
endfunction

function! nvlime#ui#MREPLBufName(conn, chan_obj)
  return s:SetBufName(a:conn.cb_data.name, 'mrepl ' .. a:chan_obj['id'])
endfunction

function! nvlime#ui#ArgListBufName()
  return s:SetBufName('arglist')
endfunction

function! nvlime#ui#TraceDialogBufName(conn)
  return s:SetBufName(a:conn.cb_data.name, 'trace')
endfunction

function! nvlime#ui#CompilerNotesBufName(conn)
  return s:SetBufName(a:conn.cb_data.name, 'compiler-notes')
endfunction

function! nvlime#ui#ServerBufName(server_name)
  return s:SetBufName(a:server_name)
endfunction

" ============================================================================
" Cursor/expression functions — NOT YET in Fennel, kept in VimScript
" ============================================================================

function! nvlime#ui#CurChar()
  return matchstr(getline('.'), '\%' . col('.') . 'c.')
endfunction

function! nvlime#ui#CurExprOrAtom()
  let str = nvlime#ui#CurExpr()
  if len(str) <= 0
    let str = nvlime#ui#CurAtom()
  endif
  return str
endfunction

function! nvlime#ui#CurAtom()
  let old_kw = &iskeyword
  try
    setlocal iskeyword+=+,-,*,/,%,<,=,>,:,$,?,!,@-@,94,~,#,\|,&,.,{,},[,]
    return expand('<cword>')
  finally
    let &l:iskeyword = old_kw
  endtry
endfunction

function! nvlime#ui#CurSymbol()
  let sym = nvlime#ui#CurAtom()
  if len(sym) > 0
    return "'" . sym
  endif
endfunction

function! nvlime#ui#CurExpr(...)
  let return_pos = get(a:000, 0, v:false)

  let cur_char = nvlime#ui#CurChar()
  let from_pos = nvlime#ui#CurExprPos(cur_char, 'begin')
  let to_pos = nvlime#ui#CurExprPos(cur_char, 'end')
  let expr = nvlime#ui#GetText(from_pos, to_pos)
  return return_pos ? [expr, from_pos, to_pos] : expr
endfunction

let s:cur_expr_pos_search_flags = {
      \ 'begin': ['cbnW', 'bnW', 'bnW'],
      \ 'end':   ['nW', 'cnW', 'nW'],
      \ }

function! nvlime#ui#CurExprPos(cur_char, ...)
  let side = get(a:000, 0, 'begin')

  if !has("syntax") || !exists("g:syntax_on")
    let s_skip = "0"
  else
    let s_skip = '!empty(filter(map(synstack(line("."), col(".")), ''synIDattr(v:val, "name")''), ' .
          \ '''v:val =~? "string\\|character\\|singlequote\\|escape\\|symbol\\|comment"''))'
    try
      execute 'if ' . s_skip . ' | let s_skip = "0" | endif'
    catch /^Vim\%((\a\+)\)\=:E363/
      return
    endtry
  endif

  if a:cur_char == '('
    return searchpairpos('(', '', ')', s:cur_expr_pos_search_flags[side][0], s_skip)
  elseif a:cur_char == ')'
    return searchpairpos('(', '', ')', s:cur_expr_pos_search_flags[side][1], s_skip)
  else
    return searchpairpos('(', '', ')', s:cur_expr_pos_search_flags[side][2], s_skip)
  endif
endfunction

function! nvlime#ui#CurTopExpr(...)
  let return_pos = get(a:000, 0, v:false)

  let [s_line, s_col] = nvlime#ui#CurTopExprPos('begin')
  if s_line > 0 && s_col > 0
    let old_cur_pos = getcurpos()
    try
      call setpos('.', [0, s_line, s_col, 0])
      return nvlime#ui#CurExpr(return_pos)
    finally
      call setpos('.', old_cur_pos)
    endtry
  else
    return return_pos ? ['', [0, 0], [0, 0]] : ''
  endif
endfunction

function! nvlime#ui#SearchParenPos(flags)
  let skipped_regions_fn = '!empty(filter(map(synstack(line("."), col(".")), ''synIDattr(v:val, "name")''), ' .
        \ '''v:val =~? "string\\|character\\|singlequote\\|escape\\|symbol\\|comment"''))'

  return searchpairpos('(', '', ')', a:flags, skipped_regions_fn)
endfunction

function! nvlime#ui#CurTopExprPos(...)
  let side = get(a:000, 0, 'begin')
  let max_level = get(a:000, 1, v:null)
  let max_lines = get(a:000, 2, v:null)

  if side == 'begin'
    let search_flags = 'bW'
  elseif side == 'end'
    let search_flags = 'W'
  endif

  let last_pos = [0, 0]

  let old_cur_pos = getcurpos()
  let cur_level = 1
  try
    while max_level is v:null || cur_level <= max_level
      let cur_pos = nvlime#ui#SearchParenPos(search_flags)
      if cur_pos[0] <= 0 || cur_pos[1] <= 0 ||
            \ (max_lines isnot v:null && abs(old_cur_pos[1] - cur_pos[0]) > max_lines)
        break
      endif
      if !s:InComment(cur_pos) && !s:InString(cur_pos)
        let last_pos = cur_pos
        let cur_level += 1
      endif
    endwhile
    if last_pos[0] > 0 && last_pos[1] > 0
      return last_pos
    else
      let cur_char = nvlime#ui#CurChar()
      if cur_char == '(' || cur_char == ')'
        return nvlime#ui#SearchParenPos(search_flags . 'c')
      else
        return [0, 0]
      endif
    endif
  finally
    call setpos('.', old_cur_pos)
  endtry
endfunction

function! nvlime#ui#CurRawForm(...)
  let max_level = get(a:000, 0, v:null)
  let max_lines = get(a:000, 1, v:null)

  let s_pos = nvlime#ui#CurTopExprPos('begin', max_level, max_lines)
  let [s_line, s_col] = s_pos
  if s_line <= 0 || s_col <= 0
    return []
  endif

  let cur_pos = getcurpos()[1:2]
  let cur_pos[1] -= 1
  let partial_expr = nvlime#ui#GetText(s_pos, cur_pos)
  let partial_expr = substitute(partial_expr, '\v(\_s)+$', ' ', '')

  if len(partial_expr) <= 0
    return []
  endif

  return nvlime#Memoize({-> nvlime#ToRawForm(partial_expr)[0]},
        \ partial_expr, 'raw_form_cache', s:, 1024)
endfunction

function! nvlime#ui#CurInPackage()
  let pattern = '(\_s*in-package\_s\+\(.\+\)\_s*)'
  let old_cur_pos = getcurpos()
  try
    let package_line = search(pattern, 'bcW')
    if package_line <= 0
      let package_line = search(pattern, 'cW')
    endif
    if package_line > 0
      let matches = matchlist(nvlime#ui#CurExpr(), pattern)
      let package = (len(matches) > 0) ? s:NormalizePackageName(matches[1]) : ''
    else
      let package = ''
    endif
    return package
  finally
    call setpos('.', old_cur_pos)
  endtry
endfunction

function! nvlime#ui#CurOperator()
  let [line, col] = getcurpos()[1:2]
  let [s_line, s_col] = luaeval('require"nvlime.search".pair_paren(_A[1], _A[2], _A[3])',
        \ [line, col, {'backward': v:true, 'same-column?': v:true}])
  if s_line > 0 && s_col > 0
    let op_line = getline(s_line)[(s_col-1):]
    let matches = matchlist(op_line, '^(\s*\(\k\+\)\s*')
    if len(matches) > 0
      return matches[1]
    endif
  endif
  return ''
endfunction

function! nvlime#ui#SurroundingOperator()
  let [line, col] = getcurpos()[1:2]
  let [s_line, s_col] = luaeval('require"nvlime.search".pair_paren(_A[1], _A[2], _A[3])',
        \ [line, col, {'backward': v:true}])
  if s_line > 0 && s_col > 0
    let op_line = getline(s_line)[(s_col-1):]
    let matches = matchlist(op_line, '^(\s*\(\k\+\)\s*')
    if len(matches) > 0
      return matches[1]
    endif
  endif
  return ''
endfunction

function! nvlime#ui#ParseOuterOperators(max_count)
  let stack = []
  let old_cur_pos = getcurpos()
  let line = old_cur_pos[1]
  let col = old_cur_pos[2]
  let stopline = luaeval('require"nvlime.search".top_form_line(true)')
  try
    while len(stack) < a:max_count
      let [p_line, p_col] = luaeval('require"nvlime.search".pair_paren(_A[1], _A[2], _A[3])',
            \ [line, col, {'backward': v:true, 'stopline': stopline}])
      if p_line <= 0 || p_col <= 0
        break
      endif
      let cur_pos = nvlime#ui#CurArgPos([p_line, p_col])

      let line = p_line
      let col = p_col
      call setpos('.', [0, p_line, p_col, 0])
      let cur_op = nvlime#ui#CurOperator()
      call add(stack, [cur_op, cur_pos, [p_line, p_col]])
    endwhile
  finally
    call setpos('.', old_cur_pos)
  endtry

  return stack
endfunction

function! nvlime#ui#CurSelection(...)
  let return_pos = get(a:000, 0, v:false)
  let sel_start = getpos("'<")
  let sel_end = getpos("'>")
  let lines = getline(sel_start[1], sel_end[1])
  if sel_start[1] == sel_end[1]
    let lines[0] = lines[0][(sel_start[2]-1):(sel_end[2]-1)]
  else
    let lines[0] = lines[0][(sel_start[2]-1):]
    let last_idx = len(lines) - 1
    let lines[last_idx] = lines[last_idx][:(sel_end[2]-1)]
  endif

  if return_pos
    return [join(lines, "\n"), sel_start[1:2], sel_end[1:2]]
  else
    return join(lines, "\n")
  endif
endfunction

" ============================================================================
" Coordinate helpers — NOT YET in Fennel, kept in VimScript
" ============================================================================

function! nvlime#ui#MatchCoord(coord, cur_line, cur_col)
  let c_begin = get(a:coord, 'begin', v:null)
  let c_end = get(a:coord, 'end', v:null)
  if c_begin is v:null || c_end is v:null
    return v:false
  endif

  if c_begin[0] == c_end[0] && a:cur_line == c_begin[0]
        \ && a:cur_col >= c_begin[1]
        \ && a:cur_col <= c_end[1]
    return v:true
  elseif c_begin[0] < c_end[0]
    if a:cur_line == c_begin[0] && a:cur_col >= c_begin[1]
      return v:true
    elseif a:cur_line == c_end[0] && a:cur_col <= c_end[1]
      return v:true
    elseif a:cur_line > c_begin[0] && a:cur_line < c_end[0]
      return v:true
    endif
  endif

  return v:false
endfunction

function! nvlime#ui#FindNextCoord(cur_pos, sorted_coords, forward = v:true)
  let next_coord = v:null
  for c in a:sorted_coords
    if a:forward
      if c['begin'][0] > a:cur_pos[0]
        return c
      elseif c['begin'][0] == a:cur_pos[0] && c['begin'][1] > a:cur_pos[1]
        return c
      endif
    else
      if c['begin'][0] < a:cur_pos[0]
        return c
      elseif c['begin'][0] == a:cur_pos[0] && c['begin'][1] < a:cur_pos[1]
        return c
      endif
    endif
  endfor

  return v:null
endfunction

function! nvlime#ui#CoordSorter(direction, c1, c2)
  if a:c1['begin'][0] > a:c2['begin'][0]
    return a:direction ? 1 : -1
  elseif a:c1['begin'][0] == a:c2['begin'][0]
    if a:c1['begin'][1] > a:c2['begin'][1]
      return a:direction ? 1 : -1
    elseif a:c1['begin'][1] == a:c2['begin'][1]
      return 0
    else
      return a:direction ? -1 : 1
    endif
  else
    return a:direction ? -1 : 1
  endif
endfunction

function! nvlime#ui#CoordsToMatchPos(coords)
  let pos_list = []
  for co in a:coords
    if co['begin'][0] == co['end'][0]
      let line = co['begin'][0]
      let col = co['begin'][1]
      let len = co['end'][1] - co['begin'][1] + 1
      call add(pos_list, [line, col, len])
    else
      for line in range(co['begin'][0], co['end'][0])
        if line == co['begin'][0]
          let col = co['begin'][1]
          let len = len(getline(line)) - col + 1
          call add(pos_list, [line, col, len])
        elseif line == co['end'][0]
          let col = 1
          let len = co['end'][1]
          call add(pos_list, [line, col, len])
        else
          call add(pos_list, line)
        endif
      endfor
    endif
  endfor

  return pos_list
endfunction

function! nvlime#ui#MatchAddCoords(group, coords)
  let pos_list = nvlime#ui#CoordsToMatchPos(a:coords)
  let match_list = []
  let stride = 8
  for i in range(0, len(pos_list) - 1, stride)
    if a:group == 'nvlime_replCoord'
      call add(match_list, matchaddpos(a:group, pos_list[i:i+stride-1], -1))
    else
      call add(match_list, matchaddpos(a:group, pos_list[i:i+stride-1]))
    endif
  endfor
  return match_list
endfunction

function! nvlime#ui#MatchDeleteList(match_list)
  for m in a:match_list
    try
      call matchdelete(m)
    catch /^Vim\%((\a\+)\)\=:E803/
    endtry
  endfor
endfunction

" ============================================================================
" ArgPos — NOT YET in Fennel, kept in VimScript
" ============================================================================

function! nvlime#ui#CurArgPos(...)
  let s_pos = get(a:000, 0, v:null)
  let arg_pos = -1

  if s_pos is v:null
    let [s_line, s_col] = nvlime#ui#SearchParenPos('bnW')
  else
    let [s_line, s_col] = s_pos
  endif
  if s_line <= 0 || s_col <= 0
    return arg_pos
  endif

  let cur_pos = getcurpos()
  let paren_count = 0
  let last_type = ''

  for ln in range(s_line, cur_pos[1])
    let line = getline(ln)
    let start_idx = (ln == s_line) ? (s_col - 1) : 0
    if ln == cur_pos[1]
      let end_idx = min([cur_pos[2], len(line)])
      if cur_pos[2] > len(line)
        let end_itr = end_idx + 1
      else
        let end_itr = end_idx
      endif
    else
      let end_idx = len(line)
      let end_itr = end_idx + 1
    endif

    let idx = start_idx
    while idx < end_itr
      if idx < end_idx
        let ch = line[idx]
      elseif idx < len(line)
        break
      else
        let ch = "\n"
      endif

      let syntax = map(synstack(ln, idx), 'synIDattr(v:val, "name")')

      if index(syntax, 'lispComment') >= 0
        " do nothing
      elseif last_type == '\'
        let last_type = 'i'
      elseif ch == '\'
        let last_type = '\'
      elseif ch == ' ' || ch == "\<tab>" || ch == "\n"
        if last_type != 's' && last_type != ')' && paren_count == 1
          let arg_pos += 1
        endif
        let last_type = 's'
      elseif ch == '('
        let paren_count += 1
        if last_type == '(' && paren_count == 2
          let arg_pos += 1
        endif
        let last_type = '('
      elseif ch == ')'
        let paren_count -= 1
        if paren_count == 1
          let arg_pos += 1
        endif
        let last_type = ')'
      else
        if last_type != 's' && last_type != ')' && last_type != 'i' && paren_count == 1
          let arg_pos += 1
        endif
        let last_type = 'i'
      endif

      let idx += 1
    endwhile

    let last_type = 's'
  endfor

  return arg_pos
endfunction

" ============================================================================
" File navigation — NOT YET in Fennel, kept in VimScript
" ============================================================================

function! nvlime#ui#JumpToOrOpenFile(file_path, byte_pos, snippet, edit_cmd, force_open)
  if a:force_open
    let buf_exists = v:false
  else
    let file_buf = bufnr(a:file_path)
    let buf_exists = v:true
    if file_buf > 0
      let buf_win = bufwinnr(file_buf)
      if buf_win > 0
        execute buf_win . 'wincmd w'
      else
        let win_list = win_findbuf(file_buf)
        if len(win_list) > 0
          call win_gotoid(win_list[0])
        else
          let buf_exists = v:false
        endif
      endif
    else
      let buf_exists = v:false
    endif
  endif

  if buf_exists
    normal! m'
  else
    if type(a:file_path) == v:t_number
      if bufnr(a:file_path) > 0
        try
          normal! m'
          execute a:edit_cmd '#' . a:file_path
        catch /^Vim\%((\a\+)\)\=:E37/
          if bufnr('%') != a:file_path
            throw v:exception
          endif
        endtry
      else
        call nvlime#ui#ErrMsg('Buffer ' . a:file_path . ' does not exist.')
        return
      endif
    elseif a:file_path[0:6] == 'sftp://' || filereadable(a:file_path)
      normal! m'
      execute a:edit_cmd escape(a:file_path, ' \')
    else
      call nvlime#ui#ErrMsg('Not readable: ' . a:file_path)
      return
    endif
  endif

  if a:byte_pos isnot v:null
    let src_line = byte2line(a:byte_pos)
    call setpos('.', [0, src_line, 1, 0, 1])
    let cur_pos = line2byte('.') + col('.') - 1
    if a:byte_pos - cur_pos > 0
      call setpos('.', [0, src_line, a:byte_pos - cur_pos + 1, 0])
    endif
    if a:snippet isnot v:null
      call cursor('.', 1)
      let to_search = '\V' .. substitute(escape(a:snippet, '\'), "\n.*", '', '')
      call search(to_search, 'cW')
    endif
    redraw
  endif
endfunction

function! nvlime#ui#ShowSource(conn, loc, edit_cmd = 'hide edit', force_open = v:false)
  let file_name = a:loc[0]
  let byte_pos = a:loc[1]
  let snippet = a:loc[2]

  if file_name is v:null
    call luaeval('require"nvlime.window.documentation".open(_A)',
          \ "Source form:\n\n" .. snippet)
  else
    call nvlime#ui#JumpToOrOpenFile(file_name, byte_pos, snippet, a:edit_cmd, a:force_open)
  endif
endfunction

" ============================================================================
" Private helpers — kept in VimScript (used by other VimScript code)
" ============================================================================

function! s:ReturnMiniBufferContent(thread, ttag)
  let content = nvlime#ui#CurBufferContent()
  call b:nvlime_conn.Return(a:thread, a:ttag, content)
endfunction

function! s:ReadStringInputComplete(thread, ttag)
  let content = nvlime#ui#CurBufferContent()
  if content[len(content)-1] != "\n"
    let content .= "\n"
  endif
  call b:nvlime_conn.ReturnString(a:thread, a:ttag, content)
endfunction

function! s:InComment(cur_pos)
  let syn_id = synID(a:cur_pos[0], a:cur_pos[1], v:false)
  if syn_id > 0
    return synIDattr(syn_id, 'name') =~ '[Cc]omment'
  else
    if searchpair('#|', '', '|#', 'bnW') > 0
      return v:true
    else
      let line = getline(a:cur_pos[0])
      let semi_colon_idx = match(line, ';')
      if semi_colon_idx >= 0 && (a:cur_pos[1] - 1) > semi_colon_idx
        return v:true
      endif
      return v:false
    endif
  endif
endfunction

function! s:InString(cur_pos)
  let syn_id = synID(a:cur_pos[0], a:cur_pos[1], v:false)
  if syn_id > 0
    return synIDattr(syn_id, 'name') =~ '[Ss]tring'
  else
    let quote_count = 0
    let pattern = '\v((^|[^\\])@<=")|(((^|[^\\])((\\\\)+))@<=")'
    let old_pos = getcurpos()
    try
      let quote_pos = searchpos(pattern, 'bW')
      while quote_pos[0] > 0 && quote_pos[1] > 0
        let quote_count += 1
        let quote_pos = searchpos(pattern, 'bW')
      endwhile
      return (quote_count % 2) > 0
    finally
      call setpos('.', old_pos)
    endtry
  endif
endfunction

function! s:NormalizePackageName(name)
  let pattern1 = '^\(\(#\?:\)\|''\)\(.\+\)'
  let pattern2 = '"\(.\+\)"'
  let matches = matchlist(a:name, pattern1)
  let r_name = ''
  if len(matches) > 0
    let r_name = matches[3]
  else
    let matches = matchlist(a:name, pattern2)
    if len(matches) > 0
      let r_name = matches[1]
    endif
  endif
  return toupper(r_name)
endfunction

" Leader variables — kept in VimScript (used by other VimScript code)

let s:special_leader_keys = [
      \ ['<', '<lt>'],
      \ ["\<space>", '<space>'],
      \ ["\<tab>", '<tab>'],
      \ ]

function! s:ExpandSpecialLeaderKeys(leader)
  let res = a:leader
  for [key, repr] in s:special_leader_keys
    let res = substitute(res, key, repr, 'g')
  endfor
  return res
endfunction

let s:default_leader = '\'

let s:leader = get(g:, 'mapleader', s:default_leader)
if len(s:leader) <= 0
  let s:leader = s:default_leader
endif
let s:leader = s:ExpandSpecialLeaderKeys(s:leader)

let s:local_leader = get(g:, 'maplocalleader', s:default_leader)
if len(s:local_leader) <= 0
  let s:local_leader = s:default_leader
endif
let s:local_leader = s:ExpandSpecialLeaderKeys(s:local_leader)

function! s:ExpandLeader(key)
  let to_expand = [['\c<Leader>', s:leader], ['\c<LocalLeader>', s:local_leader]]
  let res = a:key
  for [repr, lkey] in to_expand
    let res = substitute(res, repr, lkey, 'g')
  endfor
  return res
endfunction

" vim: sw=2
