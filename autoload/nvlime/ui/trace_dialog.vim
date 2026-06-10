" nvlime#ui#trace_dialog — VimScript shim forwarding to Fennel implementation.
" All logic lives in fnl/nvlime/core/ui/trace_dialog.fnl.

function! nvlime#ui#trace_dialog#InitTraceDialogBuf(conn)
  return luaeval('require("nvlime.core.ui.trace_dialog").init_trace_dialog_buf(_A[1])', a:conn)
endfunction

function! nvlime#ui#trace_dialog#FillTraceDialogBuf(spec_list, trace_count)
  return luaeval('require("nvlime.core.ui.trace_dialog").fill_trace_dialog_buf(_A[1], _A[2])',
        \ [a:spec_list, a:trace_count])
endfunction

function! nvlime#ui#trace_dialog#RefreshSpecs()
  return luaeval('require("nvlime.core.ui.trace_dialog").refresh_specs()')
endfunction

function! nvlime#ui#trace_dialog#Select(...)
  let l:action = get(a:000, 0, 'button')
  return luaeval('require("nvlime.core.ui.trace_dialog").select(_A[1])', l:action)
endfunction

function! nvlime#ui#trace_dialog#NextField(forward)
  return luaeval('require("nvlime.core.ui.trace_dialog").next_field(_A[1])', a:forward)
endfunction

function! nvlime#ui#trace_dialog#CalcFoldLevel(...)
  let l:line_nr = get(a:000, 0, v:lnum)
  return luaeval('require("nvlime.core.ui.trace_dialog").calc_fold_level(_A[1])', l:line_nr)
endfunction

function! nvlime#ui#trace_dialog#BuildFoldText(...)
  let l:fold_start = get(a:000, 0, v:foldstart)
  return luaeval('require("nvlime.core.ui.trace_dialog").build_fold_text(_A[1])', l:fold_start)
endfunction

" vim: sw=2
