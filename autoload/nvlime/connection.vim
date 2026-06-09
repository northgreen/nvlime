function! nvlime#connection#New(name = v:null)
  let cm = luaeval('require("nvlime.core.conn_manager")')
  return luaeval('_A[1]["new"](_A[2])', [cm, a:name])
endfunction

function! nvlime#connection#Close(conn)
  let cm = luaeval('require("nvlime.core.conn_manager")')
  return luaeval('_A[1]["close"](_A[2])', [cm, a:conn])
endfunction

function! nvlime#connection#Rename(conn, new_name)
  let cm = luaeval('require("nvlime.core.conn_manager")')
  return luaeval('_A[1]["rename"](_A[2], _A[3])', [cm, a:conn, a:new_name])
endfunction

function! nvlime#connection#Select(quiet)
  let cm = luaeval('require("nvlime.core.conn_manager")')
  return luaeval('_A[1]["select"](_A[2])', [cm, a:quiet])
endfunction

function! nvlime#connection#Get(quiet = v:false) abort
  let cm = luaeval('require("nvlime.core.conn_manager")')
  return luaeval('_A[1]["get"](_A[2])', [cm, a:quiet])
endfunction
