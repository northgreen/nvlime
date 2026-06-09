" Compiler notes shim — forwards to nvlime.core.ui.compiler_notes (Fennel)

function! nvlime#ui#compiler_notes#InitCompilerNotesBuffer(conn, orig_win)
  return luaeval('require("nvlime.core.ui.compiler_notes")["init-buffer"](_A[1], _A[2])',
        \ [a:conn, a:orig_win])
endfunction

function! nvlime#ui#compiler_notes#FillCompilerNotesBuf(note_list)
  return luaeval('require("nvlime.core.ui.compiler_notes")["fill-buffer"](_A[1])',
        \ [a:note_list])
endfunction

function! nvlime#ui#compiler_notes#OpenCurNote(...)
  return luaeval('require("nvlime.core.ui.compiler_notes")["open-cur-note"](_A[1])',
        \ [get(a:, 1, 'hide edit')])
endfunction

" vim: sw=2
