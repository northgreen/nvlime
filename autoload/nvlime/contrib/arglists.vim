" Shim: forwards to Fennel nvlime.core.contrib.arglists
function! nvlime#contrib#arglists#Autodoc(raw_form, ...) dict
  return luaeval('require("nvlime.core.contrib.arglists").autodoc(_A[1], _A[2], _A[3], _A[4])', [self, a:raw_form, a:0 ? a:1 : v:null, a:0 ? a:2 : v:null])
endfunction

function! nvlime#contrib#arglists#Init(conn)
  return luaeval('require("nvlime.core.contrib.arglists").init-arglists(_A[1])', a:conn)
endfunction
" vim: sw=2
