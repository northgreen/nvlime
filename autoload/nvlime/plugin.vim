" initialize options
let g:nvlime_options = luaeval('require"nvlime.config"')

let s:P = luaeval('require"nvlime.core.plugin"')

function! nvlime#plugin#CloseCurConnection()
  return s:P.close_cur_connection()
endfunction

function! nvlime#plugin#RenameCurConnection()
  return s:P.rename_cur_connection()
endfunction

function! nvlime#plugin#SelectCurConnection()
  return s:P.select_cur_connection()
endfunction

function! nvlime#plugin#SendToREPL(...)
  return luaeval('require"nvlime.core.plugin".send_to_repl(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#Compile(...)
  return luaeval('require"nvlime.core.plugin".compile(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#CompileDefun()
  return s:P.compile_defun()
endfunction

function! nvlime#plugin#LoadFile(...)
  return luaeval('require"nvlime.core.plugin".load_file(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#SetPackage(...)
  return luaeval('require"nvlime.core.plugin".set_package(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#Inspect(...)
  return luaeval('require"nvlime.core.plugin".inspect(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#CompileFile(...)
  return luaeval('require"nvlime.core.plugin".compile_file(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#ExpandMacro(...)
  return luaeval('require"nvlime.core.plugin".expand_macro(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#DisassembleForm(...)
  return luaeval('require"nvlime.core.plugin".disassemble_form(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#DescribeSymbol(...)
  return luaeval('require"nvlime.core.plugin".describe_symbol(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#DocumentationSymbol(...)
  return luaeval('require"nvlime.core.plugin".documentation_symbol(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#AproposList(...)
  return luaeval('require"nvlime.core.plugin".apropos_list(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#FindDefinition(...)
  return luaeval('require"nvlime.core.plugin".find_definition(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#XRefSymbol(ref_type, ...)
  return luaeval('require"nvlime.core.plugin".xref_symbol(_A[1], unpack(_A, 2))', [a:ref_type] + a:000)
endfunction

function! nvlime#plugin#XRefSymbolWrapper()
  return s:P.xref_symbol_wrapper()
endfunction

function! nvlime#plugin#ShowOperatorArgList(...)
  return luaeval('require"nvlime.core.plugin".show_operator_arglist(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#CurAutodoc()
  return s:P.cur_autodoc()
endfunction

function! nvlime#plugin#SetBreakpoint(...)
  return luaeval('require"nvlime.core.plugin".set_breakpoint(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#ListThreads()
  return s:P.list_threads()
endfunction

function! nvlime#plugin#UndefineFunction(...)
  return luaeval('require"nvlime.core.plugin".undefine_function(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#UninternSymbol(...)
  return luaeval('require"nvlime.core.plugin".unintern_symbol(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#UndefineUninternWrapper()
  return s:P.undefine_unintern_wrapper()
endfunction

function! nvlime#plugin#SwankRequire(contribs, ...)
  return luaeval('require"nvlime.core.plugin".swank_require(_A[1], _A[2])', [a:contribs] + (a:0 ? a:000 : [v:true]))
endfunction

function! nvlime#plugin#DialogToggleTrace(...)
  return luaeval('require"nvlime.core.plugin".dialog_toggle_trace(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#OpenTraceDialog()
  return s:P.open_trace_dialog()
endfunction

function! nvlime#plugin#CreateMREPL()
  return s:P.create_mrepl()
endfunction

function! nvlime#plugin#ShowCurrentServer()
  return s:P.show_current_server()
endfunction

function! nvlime#plugin#ShowSelectedServer()
  return s:P.show_selected_server()
endfunction

function! nvlime#plugin#StopCurrentServer()
  return s:P.stop_current_server()
endfunction

function! nvlime#plugin#RestartCurrentServer()
  return s:P.restart_current_server()
endfunction

function! nvlime#plugin#StopSelectedServer()
  return s:P.stop_selected_server()
endfunction

function! nvlime#plugin#RenameSelectedServer()
  return s:P.rename_selected_server()
endfunction

function! nvlime#plugin#ConnectREPL(...)
  return luaeval('require"nvlime.core.plugin".connect_repl(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#CompleteFunc(findstart, base)
  return s:P.completefunc(a:findstart, a:base)
endfunction

function! nvlime#plugin#CalcCurIndent(...)
  return luaeval('require"nvlime.core.plugin".calc_cur_indent(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#SpaceEnterKey()
  return s:P.space_enter_key()
endfunction

function! nvlime#plugin#TabKey(key)
  return s:P.tab_key(a:key)
endfunction

function! nvlime#plugin#Setup(...)
  return luaeval('require"nvlime.core.plugin".setup(unpack(_A))', a:000)
endfunction

function! nvlime#plugin#InteractionMode(...)
  return luaeval('require"nvlime.core.plugin".interaction_mode(unpack(_A))', a:000)
endfunction

" vim: sw=2
