" Shim: forwards to Fennel nvlime.core.contrib.presentations
function! nvlime#contrib#presentations#InspectPresentation(presentation, ...) dict
  return luaeval('require("nvlime.core.contrib.presentations").inspect-presentation(_A[1], _A[2], _A[3])', [self, a:presentation, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#presentations#Init(conn)
  return luaeval('require("nvlime.core.contrib.presentations").init-presentations(_A[1])', a:conn)
endfunction
" vim: sw=2
