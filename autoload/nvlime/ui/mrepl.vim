" MREPL shim — forwards to nvlime.core.ui.mrepl (Fennel)

function! nvlime#ui#mrepl#InitMREPLBuf(conn, chan_obj)
  return luaeval('require("nvlime.core.ui.mrepl")["init-mrepl-buf"](_A[1], _A[2])',
        \ [a:conn, a:chan_obj])
endfunction

function! nvlime#ui#mrepl#ShowPrompt(conn, chan_obj, prompt)
  let l:bufnr = bufnr(nvlime#ui#MREPLBufName(a:conn, a:chan_obj))
  return luaeval('require("nvlime.core.ui.mrepl")["show-prompt"](_A[1], _A[2])',
        \ [l:bufnr, a:prompt])
endfunction

function! nvlime#ui#mrepl#ShowResult(conn, chan_obj, result)
  let l:bufnr = bufnr(nvlime#ui#MREPLBufName(a:conn, a:chan_obj))
  return luaeval('require("nvlime.core.ui.mrepl")["show-result"](_A[1], _A[2])',
        \ [l:bufnr, a:result])
endfunction

function! nvlime#ui#mrepl#Submit()
  return luaeval('require("nvlime.core.ui.mrepl")["submit"]()')
endfunction

function! nvlime#ui#mrepl#Clear()
  return luaeval('require("nvlime.core.ui.mrepl")["clear"]()')
endfunction

function! nvlime#ui#mrepl#Disconnect(conn, chan_obj)
  " Fennel disconnect uses buffer-local vars; switch to target buffer first
  let l:bufnr = bufnr(nvlime#ui#MREPLBufName(a:conn, a:chan_obj))
  if l:bufnr > 0
    call nvim_buf_call(l:bufnr, { -> luaeval('require("nvlime.core.ui.mrepl")["disconnect"]()') })
  endif
endfunction

function! nvlime#ui#mrepl#Interrupt(conn, chan_obj)
  " Fennel interrupt uses buffer-local vars; switch to target buffer first
  let l:bufnr = bufnr(nvlime#ui#MREPLBufName(a:conn, a:chan_obj))
  if l:bufnr > 0
    call nvim_buf_call(l:bufnr, { -> luaeval('require("nvlime.core.ui.mrepl")["interrupt"]()') })
  endif
  return ''
endfunction

" vim: sw=2
