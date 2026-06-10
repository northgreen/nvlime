" Shim: calls nvlime.core.server (Fennel -> Lua)
function! nvlime#server#New(...)
  let auto_connect = a:0 >= 1 ? a:1 : v:true
  let use_terminal = a:0 >= 2 ? a:2 : v:false
  let name = a:0 >= 3 ? a:3 : v:null
  let cl_impl = a:0 >= 4 ? a:4 : v:null
  return luaeval('require("nvlime.core.server").new(_A[1], _A[2], _A[3], _A[4])',
        \ [auto_connect, use_terminal, name, cl_impl])
endfunction

function! nvlime#server#Stop(server)
  return luaeval('require("nvlime.core.server").stop(_A)', a:server)
endfunction

function! nvlime#server#Rename(server, new_name)
  return luaeval('require("nvlime.core.server").rename(_A[1], _A[2])',
        \ [a:server, a:new_name])
endfunction

function! nvlime#server#Show(server)
  return luaeval('require("nvlime.core.server").show(_A)', a:server)
endfunction

function! nvlime#server#Select()
  return luaeval('require("nvlime.core.server").select()')
endfunction

function! nvlime#server#ConnectToCurServer()
  return luaeval('require("nvlime.core.server").connect_to_cur_server()')
endfunction

function! nvlime#server#StopCurServer()
  return luaeval('require("nvlime.core.server").stop_cur_server()')
endfunction

function! nvlime#server#BuildServerCommand(cl_impl)
  return luaeval('require("nvlime.core.server").build_server_command(_A)', a:cl_impl)
endfunction

function! nvlime#server#BuildServerCommandFor_sbcl(loader, eval)
  return luaeval('require("nvlime.core.server").build_server_command_for_sbcl(_A[1], _A[2])',
        \ [a:loader, a:eval])
endfunction

function! nvlime#server#BuildServerCommandFor_ccl(loader, eval)
  return luaeval('require("nvlime.core.server").build_server_command_for_ccl(_A[1], _A[2])',
        \ [a:loader, a:eval])
endfunction
