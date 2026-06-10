" Shim: forwards to Fennel nvlime.core.contrib.repl
function! nvlime#contrib#repl#CreateREPL(...) dict
  return luaeval('require("nvlime.core.contrib.repl").create-repl(_A[1], _A[2], _A[3])', [self, a:0 ? a:1 : v:null, a:0 ? a:2 : v:null])
endfunction

function! nvlime#contrib#repl#ListenerEval(expr, ...) dict
  return luaeval('require("nvlime.core.contrib.repl").listener-eval(_A[1], _A[2], _A[3])', [self, a:expr, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#repl#Init(conn)
  return luaeval('require("nvlime.core.contrib.repl").init-repl(_A[1])', a:conn)
endfunction
" vim: sw=2
