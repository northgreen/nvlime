" Shim: forwards to Fennel nvlime.core.contrib.mrepl
function! nvlime#contrib#mrepl#CreateMREPL(...) dict
  return luaeval('require("nvlime.core.contrib.mrepl").create-mrepl(_A[1], _A[2], _A[3])', [self, a:0 ? a:1 : v:null, a:0 ? a:2 : v:null])
endfunction

function! nvlime#contrib#mrepl#Init(conn)
  return luaeval('require("nvlime.core.contrib.mrepl").init-mrepl(_A[1])', a:conn)
endfunction
" vim: sw=2
