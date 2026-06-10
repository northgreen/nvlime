" Shim: forwards all public functions to the Fennel implementation.
" Original implementation moved to fnl/nvlime/core/ui/sldb.fnl

let s:sldb = luaeval('require("nvlime.core.ui.sldb")')

function! nvlime#ui#sldb#FillSLDBBuf(thread, level, condition, restarts, frames)
  return s:sldb.fill_sldb_buf(a:thread, a:level, a:condition, a:restarts, a:frames)
endfunction

function! nvlime#ui#sldb#ChooseCurRestart()
  return s:sldb.choose_cur_restart()
endfunction

function! nvlime#ui#sldb#ShowFrameDetails()
  return s:sldb.show_frame_details()
endfunction

function! nvlime#ui#sldb#OpenFrameSource(...)
  let l:edit_cmd = a:0 ? a:1 : 'hide edit'
  return s:sldb.open_frame_source(l:edit_cmd)
endfunction

function! nvlime#ui#sldb#FindSource(...)
  let l:edit_cmd = a:0 ? a:1 : 'hide edit'
  return s:sldb.find_source(l:edit_cmd)
endfunction

function! nvlime#ui#sldb#RestartCurFrame()
  return s:sldb.restart_cur_frame()
endfunction

function! nvlime#ui#sldb#StepCurOrLastFrame(opr)
  return s:sldb.step_cur_or_last_frame(a:opr)
endfunction

function! nvlime#ui#sldb#InspectCurCondition()
  return s:sldb.inspect_cur_condition()
endfunction

function! nvlime#ui#sldb#InspectVarInCurFrame()
  return s:sldb.inspect_var_in_cur_frame()
endfunction

function! nvlime#ui#sldb#EvalStringInCurFrame()
  return s:sldb.eval_string_in_cur_frame()
endfunction

function! nvlime#ui#sldb#SendValueInCurFrameToREPL()
  return s:sldb.send_value_in_cur_frame_to_repl()
endfunction

function! nvlime#ui#sldb#DisassembleCurFrame()
  return s:sldb.disassemble_cur_frame()
endfunction

function! nvlime#ui#sldb#ReturnFromCurFrame()
  return s:sldb.return_from_cur_frame()
endfunction

" vim: sw=2
