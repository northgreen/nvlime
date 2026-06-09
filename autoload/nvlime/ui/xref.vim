" Xref shim — forwards to nvlime.core.ui.xref (Fennel)

function! nvlime#ui#xref#OpenXRefBuf(conn, xref_list)
  return luaeval('require("nvlime.core.ui.xref")["open-xref-buf"](_A[1], _A[2])',
        \ [a:conn, a:xref_list])
endfunction

function! nvlime#ui#xref#OpenCurXref(...)
  return luaeval('require("nvlime.core.ui.xref")["open-cur-xref"](_A[1])',
        \ [get(a:, 1, 'hide edit')])
endfunction

" vim: sw=2
