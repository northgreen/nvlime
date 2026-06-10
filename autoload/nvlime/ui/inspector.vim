" Inspector shim — forwards to nvlime.core.ui.inspector (Fennel)

function! nvlime#ui#inspector#InspectorSelect()
  return luaeval('require("nvlime.core.ui.inspector")["inspector-select"]()')
endfunction

function! nvlime#ui#inspector#SendCurValueToREPL()
  return luaeval('require("nvlime.core.ui.inspector")["send-cur-value-to-repl"]()')
endfunction

function! nvlime#ui#inspector#SendCurInspecteeToREPL()
  return luaeval('require("nvlime.core.ui.inspector")["send-cur-inspectee-to-repl"]()')
endfunction

function! nvlime#ui#inspector#FindSource(type, ...)
  return luaeval('require("nvlime.core.ui.inspector")["find-source"](_A[1], _A[2])',
        \ [a:type, get(a:, 1, 'hide edit')])
endfunction

function! nvlime#ui#inspector#NextField(forward)
  return luaeval('require("nvlime.core.ui.inspector")["next-field"](_A[1])',
        \ a:forward)
endfunction

function! nvlime#ui#inspector#InspectorPop()
  return luaeval('require("nvlime.core.ui.inspector")["inspector-pop"]()')
endfunction

function! nvlime#ui#inspector#InspectorNext()
  return luaeval('require("nvlime.core.ui.inspector")["inspector-next"]()')
endfunction

" vim: sw=2
