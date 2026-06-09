" Shim: calls nvlime.core.async (Fennel -> Lua)
function! nvlime#async#ch_open(host, port, ...)
  let Callback = a:0 >= 1 ? a:1 : v:null
  let timeout = a:0 >= 2 ? a:2 : v:null
  return luaeval('require"nvlime.core.async".ch_open(_A[1], _A[2], _A[3], _A[4])', [a:host, a:port, Callback, timeout])
endfunction

function! nvlime#async#ch_sendexpr(chan, expr, Callback)
  return luaeval('require"nvlime.core.async".ch_sendexpr(_A[1], _A[2], _A[3])', [a:chan, a:expr, a:Callback])
endfunction

function! nvlime#async#job_start(cmd, opts)
  return luaeval('require"nvlime.core.async".job_start(_A[1], _A[2])', [a:cmd, a:opts])
endfunction

function! nvlime#async#job_is_active(job)
  return luaeval('require"nvlime.core.async".job_is_active(_A[1])', [a:job])
endfunction

function! nvlime#async#job_getbufnr(job)
  return luaeval('require"nvlime.core.async".job_getbufnr(_A[1])', [a:job])
endfunction
