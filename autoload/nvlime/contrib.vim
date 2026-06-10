" Shim: forwards to Fennel implementation
function! nvlime#contrib#CallInitializers(conn, ...)
  return luaeval('require("nvlime.core.contrib").call-initializers(_A[1], _A[2], _A[3])', [a:conn, a:0 ? a:1 : v:null, a:0 ? a:2 : v:null])
endfunction
" vim: sw=2
