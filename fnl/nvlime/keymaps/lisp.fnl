(local km (require "nvlime.keymaps"))
(local lm km.mappings.lisp)
(local repl (require "nvlime.window.main.repl"))
(local uc (require "nvlime.ui_cursors"))

(local lisp {})

(fn lisp.add []
  (km.buffer.insert lm.insert.space_arglist
                    "<Space><Cmd>lua require('nvlime.core.plugin').space_enter_key()<CR>"
                    "nvlime: Trigger the arglist hint")
  (km.buffer.insert lm.insert.cr_arglist
                    "<CR><Cmd>lua require('nvlime.core.plugin').space_enter_key()<CR>"
                    "nvlime: Trigger the arglist hint")

  (km.buffer.normal lm.normal.interaction_mode
                    "<Cmd>lua require('nvlime.core.plugin').interaction_mode()<CR>"
                    "nvlime: Toggle interaction mode")
  (km.buffer.normal lm.normal.load_file
                    "<Cmd>lua require('nvlime.core.plugin').load_file(vim.api.nvim_buf_get_name(0))<CR>"
                    "nvlime: Load the current file")
  (km.buffer.normal lm.normal.disassemble.expr
                    "<Cmd>lua require('nvlime.core.plugin').disassemble_form(uc.cur_expr())<CR>"
                    "nvlime: Disassemble the form under the cursor")
  (km.buffer.normal lm.normal.disassemble.symbol
                    "<Cmd>lua require('nvlime.core.plugin').disassemble_form(uc.cur_symbol())<CR>"
                    "nvlime: Disassemble the form under the cursor")
  (km.buffer.normal lm.normal.set_package
                    "<Cmd>lua require('nvlime.core.plugin').set_package()<CR>"
                    "nvlime: Specify the package for the current buffer")
  (km.buffer.normal lm.normal.set_breakpoint
                    "<Cmd>lua require('nvlime.core.plugin').set_breakpoint()<CR>"
                    "nvlime: Set a breakpoint at entry to a function")
  (km.buffer.normal lm.normal.show_threads
                    "<Cmd>lua require('nvlime.core.plugin').list_threads()<CR>"
                    "nvlime: Show a list of the running threads")

  (km.buffer.normal lm.normal.connection.new
                    "<Cmd>lua require('nvlime.core.plugin').connect_repl()<CR>"
                    "nvlime: Connect to a server")
  (km.buffer.normal lm.normal.connection.switch
                    "<Cmd>lua require('nvlime.core.plugin').select_cur_connection()<CR>"
                    "nvlime: Switch connections")
  (km.buffer.normal lm.normal.connection.close
                    "<Cmd>lua require('nvlime.core.plugin').close_cur_connection()<CR>"
                    "nvlime: Disconnect the current connection")
  (km.buffer.normal lm.normal.connection.rename
                    "<Cmd>lua require('nvlime.core.plugin').rename_cur_connection()<CR>"
                    "nvlime: Rename the current connection")

  (km.buffer.normal lm.normal.server.new
                    "<Cmd>lua require('nvlime.core.server').new(true, vim.fn.get('g:', 'nvlime_cl_use_terminal', false))<CR>"
                    "nvlime: Run a new server and connect to it")
  (km.buffer.normal lm.normal.server.show
                    "<Cmd>lua require('nvlime.core.plugin').show_current_server()<CR>"
                    "nvlime: View the console outpot of the current server")
  (km.buffer.normal lm.normal.server.show_selected
                    "<Cmd>lua require('nvlime.core.plugin').show_selected_server()<CR>"
                    "nvlime: Show a list of the servers and view the console output of the chosen one")
  (km.buffer.normal lm.normal.server.stop
                    "<Cmd>lua require('nvlime.core.plugin').stop_current_server()<CR>"
                    "nvlime: Stop the current server")
  (km.buffer.normal lm.normal.server.stop_selected
                    "<Cmd>lua require('nvlime.core.plugin').stop_selected_server()<CR>"
                    "nvlime: Show a list of the servers and stop the chosen one")
  (km.buffer.normal lm.normal.server.rename
                    "<Cmd>lua require('nvlime.core.plugin').rename_selected_server()<CR>"
                    "nvlime: Rename a server")
  (km.buffer.normal lm.normal.server.restart
                    "<Cmd>lua require('nvlime.core.plugin').restart_current_server()<CR>"
                    "nvlime: Restart the current server")

  (km.buffer.normal lm.normal.repl.show
                    #(repl.open "" {:focus? false})
                    "nvlime: Show the REPL window")
  (km.buffer.normal lm.normal.repl.clear
                    #(repl.clear)
                    "nvlime: Clear the REPL buffer")
  (km.buffer.normal lm.normal.repl.send_atom_expr
                    "<Cmd>lua require('nvlime.core.plugin').send_to_repl(uc.cur_expr_or_atom())<CR>"
                    "nvlime: Send the expression/atom under the cursor to the REPL")
  (km.buffer.normal lm.normal.repl.send_atom
                    "<Cmd>lua require('nvlime.core.plugin').send_to_repl(uc.cur_atom())<CR>"
                    "nvlime: Send the atom under the cursor to the REPL")
  (km.buffer.normal lm.normal.repl.send_expr
                    "<Cmd>lua require('nvlime.core.plugin').send_to_repl(uc.cur_expr())<CR>"
                    "nvlime: Send the expression under the cursor to the REPL")
  (km.buffer.normal lm.normal.repl.send_toplevel_expr
                    "<Cmd>lua require('nvlime.core.plugin').send_to_repl(uc.cur_top_expr())<CR>"
                    "nvlime: Send the top-level expression under the cursor to the REPL")
  (km.buffer.normal lm.normal.repl.prompt
                    "<Cmd>lua require('nvlime.core.plugin').send_to_repl()<CR>"
                    "nvlime: Send a snippet to the REPL")
  (km.buffer.visual lm.visual.repl.send_selection
                    "<Cmd>lua require('nvlime.core.plugin').send_to_repl(uc.cur_selection())<CR>"
                    "nvlime: Send the current selection to the REPL")

  (km.buffer.normal lm.normal.macro.expand
                    "<Cmd>lua require('nvlime.core.plugin').expand_macro(uc.cur_expr(), 'expand')<CR>"
                    "nvlime: Expand the macro under the cursor")
  (km.buffer.normal lm.normal.macro.expand_once
                    "<Cmd>lua require('nvlime.core.plugin').expand_macro(uc.cur_expr(), 'one')<CR>"
                    "nvlime: Expand the macro under the cursor once")
  (km.buffer.normal lm.normal.macro.expand_all
                    "<Cmd>lua require('nvlime.core.plugin').expand_macro(uc.cur_expr(), 'all')<CR>"
                    "nvlime: Expand the macro under the cursor and all nested macros")

  (km.buffer.normal lm.normal.compile.expr
                    "<Cmd>lua require('nvlime.core.plugin').compile(uc.cur_expr(true))<CR>"
                    "nvlime: Compile the expression under the cursor")
  (km.buffer.normal lm.normal.compile.toplevel_expr
                    "<Cmd>lua require('nvlime.core.plugin').compile(uc.cur_top_expr(true))<CR>"
                    "nvlime: Compile the top-level expression under the cursor")
  (km.buffer.normal lm.normal.compile.file
                    "<Cmd>lua require('nvlime.core.plugin').compile_file(vim.api.nvim_buf_get_name(0))<CR>"
                    "nvlime: Compile the current file")
  (km.buffer.visual lm.visual.compile.selection
                    "<Cmd>lua require('nvlime.core.plugin').compile(uc.cur_selection(true))<CR>"
                    "nvlime: Compile the current selection")

  (km.buffer.normal lm.normal.xref.function.callers
                    "<Cmd>lua require('nvlime.core.plugin').xref_symbol('CALLS', uc.cur_atom())<CR>"
                    "nvlime: Show callers of the function under the cursor")
  (km.buffer.normal lm.normal.xref.function.callees
                    "<Cmd>lua require('nvlime.core.plugin').xref_symbol('CALLS-WHO', uc.cur_atom())<CR>"
                    "nvlime: Show callees of the function under the cursor")
  (km.buffer.normal lm.normal.xref.symbol.references
                    "<Cmd>lua require('nvlime.core.plugin').xref_symbol('REFERENCES', uc.cur_atom())<CR>"
                    "nvlime: Show references to the variable under the cursor")
  (km.buffer.normal lm.normal.xref.symbol.bindings
                    "<Cmd>lua require('nvlime.core.plugin').xref_symbol('BINDS', uc.cur_atom())<CR>"
                    "nvlime: Show bindings for the variable under the cursor")
  (km.buffer.normal lm.normal.xref.symbol.definition
                    "<Cmd>lua require('nvlime.core.plugin').find_definition(uc.cur_atom())<CR>"
                    "nvlime: Show the definition for the symbol under the cursor")
  (km.buffer.normal lm.normal.xref.symbol.set_locations
                    "<Cmd>lua require('nvlime.core.plugin').xref_symbol('SETS', uc.cur_atom())<CR>"
                    "nvlime: Show locations where the variable under the cursor is set")
  (km.buffer.normal lm.normal.xref.macro.callers
                    "<Cmd>lua require('nvlime.core.plugin').xref_symbol('MACROEXPANDS', uc.cur_atom())<CR>"
                    "nvlime: Show locations where the macro under the cursor is called")
  (km.buffer.normal lm.normal.xref.class.methods
                    "<Cmd>lua require('nvlime.core.plugin').xref_symbol('SPECIALIZES', uc.cur_atom())<CR>"
                    "nvlime: Show specialized methods for the class under the cursor")
  (km.buffer.normal lm.normal.xref.prompt
                    "<Cmd>lua require('nvlime.core.plugin').xref_symbol_wrapper()<CR>"
                    "nvlime: Interactively prompt for the symbol to search for cross references")

  (km.buffer.normal lm.normal.describe.operator
                    "<Cmd>lua require('nvlime.core.plugin').describe_symbol(uc.cur_operator())<CR>"
                    "nvlime: Describe the operator of the expression under the cursor")
  (km.buffer.normal lm.normal.describe.atom
                    "<Cmd>lua require('nvlime.core.plugin').describe_symbol(uc.cur_atom())<CR>"
                    "nvlime: Describe the atom under the cursor")
  (km.buffer.normal lm.normal.describe.prompt
                    "<Cmd>lua require('nvlime.core.plugin').describe_symbol()<CR>"
                    "nvlime: Prompt for the symbol to describe")
  (km.buffer.normal lm.normal.apropos.prompt
                    "<Cmd>lua require('nvlime.core.plugin').apropos_list()<CR>"
                    "nvlime: Apropos search")
  (km.buffer.normal lm.normal.arglist.show
                    "<Cmd>lua require('nvlime.core.plugin').show_operator_arglist(uc.cur_operator())<CR>"
                    "nvlime: Show the arglist for the expression under the cursor")
  (km.buffer.normal lm.normal.documentation.operator
                    "<Cmd>lua require('nvlime.core.plugin').documentation_symbol(uc.cur_operator())<CR>"
                    "nvlime: Show the documentation for the operator of the expression under the cursor")
  (km.buffer.normal lm.normal.documentation.atom
                    "<Cmd>lua require('nvlime.core.plugin').documentation_symbol(uc.cur_atom())<CR>"
                    "nvlime: Show the documentation for the atom under the cursor")
  (km.buffer.normal lm.normal.documentation.prompt
                    "<Cmd>lua require('nvlime.core.plugin').documentation_symbol()<CR>"
                    "nvlime: Prompt for a symbol and show its documentation")

  (km.buffer.normal lm.normal.inspect.atom_expr
                    "<Cmd>lua require('nvlime.core.plugin').inspect(uc.cur_expr_or_atom())<CR>"
                    "nvlime: Evaluate the expression/atom under the cursor and inspect the result")
  (km.buffer.normal lm.normal.inspect.atom
                    "<Cmd>lua require('nvlime.core.plugin').inspect(uc.cur_atom())<CR>"
                    "nvlime: Evaluate the atom under the cursor and inspect the result")
  (km.buffer.normal lm.normal.inspect.expr
                    "<Cmd>lua require('nvlime.core.plugin').inspect(uc.cur_expr())<CR>"
                    "nvlime: Evaluate the expression under the cursor and inspect the result")
  (km.buffer.normal lm.normal.inspect.toplevel_expr
                    "<Cmd>lua require('nvlime.core.plugin').inspect(uc.cur_top_expr())<CR>"
                    "nvlime: Evaluate the top-level expression under the cursor and inspect the result")
  (km.buffer.normal lm.normal.inspect.symbol
                    "<Cmd>lua require('nvlime.core.plugin').inspect(uc.cur_symbol())<CR>"
                    "nvlime: Inspect the symbol under the cursor")
  (km.buffer.normal lm.normal.inspect.prompt
                    "<Cmd>lua require('nvlime.core.plugin').inspect()<CR>"
                    "nvlime: Evaluate a snippet and inspect the result")
  (km.buffer.visual lm.visual.inspect.selection
                    "<Cmd>lua require('nvlime.core.plugin').inspect(uc.cur_selection())<CR>"
                    "nvlime: Evaluate the current selection and inspect the result")

  (km.buffer.normal lm.normal.trace.show
                    "<Cmd>lua require('nvlime.core.plugin')['open-trace-dialog']()<CR>"
                    "nvlime: Show the trace dialog")
  (km.buffer.normal lm.normal.trace.toggle
                    "<Cmd>lua require('nvlime.core.plugin').dialog_toggle_trace(uc.cur_atom())<CR>"
                    "nvlime: Trace/untrace the function under the cursor")
  (km.buffer.normal lm.normal.trace.prompt
                    "<Cmd>lua require('nvlime.core.plugin').dialog_toggle_trace()<CR>"
                    "nvlime: Prompt for a function name to trace/untrace")

  (km.buffer.normal lm.normal.undefine.function
                    "<Cmd>lua require('nvlime.core.plugin').undefine_function(uc.cur_atom())<CR>"
                    "nvlime: Undefine the function under the cursor")
  (km.buffer.normal lm.normal.undefine.symbol
                    "<Cmd>lua require('nvlime.core.plugin').unintern_symbol(uc.cur_atom())<CR>"
                    "nvlime: Unintern the symbol under the cursor")
  (km.buffer.normal lm.normal.undefine.prompt
                    "<Cmd>lua require('nvlime.core.plugin').undefine_unintern_wrapper()<CR>"
                    "nvlime: Interactively prompt for the function to undefine or symbol to unintern"))

lisp
