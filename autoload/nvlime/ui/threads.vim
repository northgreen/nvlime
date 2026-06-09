" Threads shim — forwards to nvlime.core.ui.threads (Fennel)

function! nvlime#ui#threads#FillThreadsBuf(conn, thread_list)
  return luaeval('require("nvlime.core.ui.threads")["fill-threads-buf"](_A[1], _A[2])',
        \ [a:conn, a:thread_list])
endfunction

function! nvlime#ui#threads#InterruptCurThread()
  return luaeval('require("nvlime.core.ui.threads")["interrupt-cur-thread"]()')
endfunction

function! nvlime#ui#threads#KillCurThread()
  return luaeval('require("nvlime.core.ui.threads")["kill-cur-thread"]()')
endfunction

function! nvlime#ui#threads#DebugCurThread()
  return luaeval('require("nvlime.core.ui.threads")["debug-cur-thread"]()')
endfunction

function! nvlime#ui#threads#Refresh(...)
  return luaeval('require("nvlime.core.ui.threads")["refresh"](_A[1], _A[2])',
        \ [get(a:, 1, v:null), get(a:, 2, v:true)])
endfunction

" vim: sw=2
