" Helper functions for nvim-cmp - bridge to Fennel connection methods

function nvlime#cmp#get_fuzzy(base, callback)
  silent let conn_dict = nvlime#connection#Get(v:true)
  if type(conn_dict) == v:t_dict && has_key(conn_dict, '__lua_ref')
    let lua_conn = conn_dict['__lua_ref']
    call luaeval('local fn = _A[1]["fuzzy-completions"] or _A[1]["FuzzyCompletions"]; if fn then fn(_A[1], _A[2], function(conn, r) _A[3](r or {}) end) end', [lua_conn, a:base, a:callback])
  endif
endfunction

function nvlime#cmp#get_simple(base, callback)
  silent let conn_dict = nvlime#connection#Get(v:true)
  if type(conn_dict) == v:t_dict && has_key(conn_dict, '__lua_ref')
    let lua_conn = conn_dict['__lua_ref']
    call luaeval('_A[1]["simple-completions"](_A[1], _A[2], function(conn, r) _A[3](r or {}) end)', [lua_conn, a:base, a:callback])
  endif
endfunction

function! nvlime#cmp#get_docs(symbol, callback)
  silent let conn_dict = nvlime#connection#Get(v:true)
  if type(conn_dict) == v:t_dict && has_key(conn_dict, '__lua_ref')
    let lua_conn = conn_dict['__lua_ref']
    call luaeval('_A[1]["documentation-symbol"](_A[1], _A[2], function(conn, r) _A[3](r or "") end)', [lua_conn, a:symbol, a:callback])
  endif
endfunction

" vim: sw=2
