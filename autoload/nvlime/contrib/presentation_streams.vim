" Shim: forwards to Fennel nvlime.core.contrib.presentation_streams
function! nvlime#contrib#presentation_streams#Init(conn)
  return luaeval('require("nvlime.core.contrib.presentation_streams").init-presentation-streams(_A[1])', a:conn)
endfunction
" vim: sw=2
