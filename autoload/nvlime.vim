" Shim: forwards all calls to Fennel/Lua modules in fnl/nvlime/core/
" Original 1744-line implementation migrated to Fennel mixins.

" ============================================================================
" Factory: nvlime#New
" ============================================================================

function! nvlime#New(cb_data = v:null, ui = v:null)
  let lua_conn = luaeval('local e = require("nvlime.core.connection.events"); e.new(_A[1], _A[2])', [a:cb_data, a:ui])
  let conn = {'__lua_ref': lua_conn}

  " Core connection methods
  function! conn.Connect(host, port, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "Connect", _A[2])',
          \ [self['__lua_ref'], [a:host, a:port] + a:000])
  endfunction
  function! conn.IsConnected() dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "IsConnected", _A[2])',
          \ [self['__lua_ref'], []])
  endfunction
  function! conn.Close() dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "Close", _A[2])',
          \ [self['__lua_ref'], []])
  endfunction
  function! conn.Call(msg) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "Call", _A[2])',
          \ [self['__lua_ref'], [a:msg]])
  endfunction
  function! conn.Send(msg, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "Send", _A[2])',
          \ [self['__lua_ref'], [a:msg] + a:000])
  endfunction

  " Path fixing
  function! conn.FixRemotePath(path) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "FixRemotePath", _A[2])',
          \ [self['__lua_ref'], [a:path]])
  endfunction
  function! conn.FixLocalPath(path) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "FixLocalPath", _A[2])',
          \ [self['__lua_ref'], [a:path]])
  endfunction

  " Context methods
  function! conn.GetCurrentPackage() dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "GetCurrentPackage", _A[2])',
          \ [self['__lua_ref'], []])
  endfunction
  function! conn.SetCurrentPackage(package) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SetCurrentPackage", _A[2])',
          \ [self['__lua_ref'], [a:package]])
  endfunction
  function! conn.GetCurrentThread() dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "GetCurrentThread", _A[2])',
          \ [self['__lua_ref'], []])
  endfunction
  function! conn.SetCurrentThread(thread) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SetCurrentThread", _A[2])',
          \ [self['__lua_ref'], [a:thread]])
  endfunction
  function! conn.WithThread(thread, Func) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "WithThread", _A[2])',
          \ [self['__lua_ref'], [a:thread, a:Func]])
  endfunction
  function! conn.WithPackage(package, Func) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "WithPackage", _A[2])',
          \ [self['__lua_ref'], [a:package, a:Func]])
  endfunction

  " Channel management
  function! conn.MakeLocalChannel(...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "MakeLocalChannel", _A[2])',
          \ [self['__lua_ref'], a:000])
  endfunction
  function! conn.RemoveLocalChannel(chan_id) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "RemoveLocalChannel", _A[2])',
          \ [self['__lua_ref'], [a:chan_id]])
  endfunction
  function! conn.MakeRemoteChannel(chan_id) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "MakeRemoteChannel", _A[2])',
          \ [self['__lua_ref'], [a:chan_id]])
  endfunction
  function! conn.RemoveRemoteChannel(chan_id) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "RemoveRemoteChannel", _A[2])',
          \ [self['__lua_ref'], [a:chan_id]])
  endfunction
  function! conn.EmacsChannelSend(chan_id, msg) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "EmacsChannelSend", _A[2])',
          \ [self['__lua_ref'], [a:chan_id, a:msg]])
  endfunction

  " Message methods
  function! conn.EmacsRex(cmd) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "EmacsRex", _A[2])',
          \ [self['__lua_ref'], [a:cmd]])
  endfunction
  function! conn.Ping() dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "Ping", _A[2])',
          \ [self['__lua_ref'], []])
  endfunction
  function! conn.Pong(thread, ttag) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "Pong", _A[2])',
          \ [self['__lua_ref'], [a:thread, a:ttag]])
  endfunction
  function! conn.ConnectionInfo(...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "ConnectionInfo", _A[2])',
          \ [self['__lua_ref'], a:000])
  endfunction
  function! conn.SwankRequire(contrib, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SwankRequire", _A[2])',
          \ [self['__lua_ref'], [a:contrib] + a:000])
  endfunction
  function! conn.Interrupt(thread) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "Interrupt", _A[2])',
          \ [self['__lua_ref'], [a:thread]])
  endfunction

  " SLDB / debugger
  function! conn.SLDBAbort(...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SLDBAbort", _A[2])',
          \ [self['__lua_ref'], a:000])
  endfunction
  function! conn.SLDBBreak(func_name, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SLDBBreak", _A[2])',
          \ [self['__lua_ref'], [a:func_name] + a:000])
  endfunction
  function! conn.SLDBContinue(...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SLDBContinue", _A[2])',
          \ [self['__lua_ref'], a:000])
  endfunction
  function! conn.SLDBStep(frame, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SLDBStep", _A[2])',
          \ [self['__lua_ref'], [a:frame] + a:000])
  endfunction
  function! conn.SLDBNext(frame, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SLDBNext", _A[2])',
          \ [self['__lua_ref'], [a:frame] + a:000])
  endfunction
  function! conn.SLDBOut(frame, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SLDBOut", _A[2])',
          \ [self['__lua_ref'], [a:frame] + a:000])
  endfunction
  function! conn.SLDBReturnFromFrame(frame, str, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SLDBReturnFromFrame", _A[2])',
          \ [self['__lua_ref'], [a:frame, a:str] + a:000])
  endfunction
  function! conn.SLDBDisassemble(frame, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SLDBDisassemble", _A[2])',
          \ [self['__lua_ref'], [a:frame] + a:000])
  endfunction
  function! conn.InvokeNthRestartForEmacs(level, restart, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "InvokeNthRestartForEmacs", _A[2])',
          \ [self['__lua_ref'], [a:level, a:restart] + a:000])
  endfunction
  function! conn.RestartFrame(frame, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "RestartFrame", _A[2])',
          \ [self['__lua_ref'], [a:frame] + a:000])
  endfunction
  function! conn.FrameLocalsAndCatchTags(frame, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "FrameLocalsAndCatchTags", _A[2])',
          \ [self['__lua_ref'], [a:frame] + a:000])
  endfunction
  function! conn.FrameSourceLocation(frame, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "FrameSourceLocation", _A[2])',
          \ [self['__lua_ref'], [a:frame] + a:000])
  endfunction
  function! conn.EvalStringInFrame(str, frame, package, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "EvalStringInFrame", _A[2])',
          \ [self['__lua_ref'], [a:str, a:frame, a:package] + a:000])
  endfunction

  " Inspector
  function! conn.InitInspector(thing, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "InitInspector", _A[2])',
          \ [self['__lua_ref'], [a:thing] + a:000])
  endfunction
  function! conn.InspectorReinspect(...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "InspectorReinspect", _A[2])',
          \ [self['__lua_ref'], a:000])
  endfunction
  function! conn.InspectorRange(r_start, r_end, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "InspectorRange", _A[2])',
          \ [self['__lua_ref'], [a:r_start, a:r_end] + a:000])
  endfunction
  function! conn.InspectNthPart(nth, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "InspectNthPart", _A[2])',
          \ [self['__lua_ref'], [a:nth] + a:000])
  endfunction
  function! conn.InspectorCallNthAction(nth, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "InspectorCallNthAction", _A[2])',
          \ [self['__lua_ref'], [a:nth] + a:000])
  endfunction
  function! conn.InspectorPop(...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "InspectorPop", _A[2])',
          \ [self['__lua_ref'], a:000])
  endfunction
  function! conn.InspectorNext(...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "InspectorNext", _A[2])',
          \ [self['__lua_ref'], a:000])
  endfunction
  function! conn.InspectCurrentCondition(...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "InspectCurrentCondition", _A[2])',
          \ [self['__lua_ref'], a:000])
  endfunction
  function! conn.InspectInFrame(thing, frame, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "InspectInFrame", _A[2])',
          \ [self['__lua_ref'], [a:thing, a:frame] + a:000])
  endfunction
  function! conn.InspectFrameVar(var_num, frame, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "InspectFrameVar", _A[2])',
          \ [self['__lua_ref'], [a:var_num, a:frame] + a:000])
  endfunction

  " Threads
  function! conn.ListThreads(...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "ListThreads", _A[2])',
          \ [self['__lua_ref'], a:000])
  endfunction
  function! conn.KillNthThread(nth, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "KillNthThread", _A[2])',
          \ [self['__lua_ref'], [a:nth] + a:000])
  endfunction
  function! conn.DebugNthThread(nth, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "DebugNthThread", _A[2])',
          \ [self['__lua_ref'], [a:nth] + a:000])
  endfunction

  " Symbols
  function! conn.UndefineFunction(func_name, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "UndefineFunction", _A[2])',
          \ [self['__lua_ref'], [a:func_name] + a:000])
  endfunction
  function! conn.UninternSymbol(sym_name, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "UninternSymbol", _A[2])',
          \ [self['__lua_ref'], [a:sym_name] + a:000])
  endfunction
  function! conn.SetPackage(package, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SetPackage", _A[2])',
          \ [self['__lua_ref'], [a:package] + a:000])
  endfunction
  function! conn.DescribeSymbol(symbol, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "DescribeSymbol", _A[2])',
          \ [self['__lua_ref'], [a:symbol] + a:000])
  endfunction
  function! conn.OperatorArgList(operator, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "OperatorArgList", _A[2])',
          \ [self['__lua_ref'], [a:operator] + a:000])
  endfunction
  function! conn.SimpleCompletions(symbol, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SimpleCompletions", _A[2])',
          \ [self['__lua_ref'], [a:symbol] + a:000])
  endfunction

  " Return
  function! conn.ReturnString(thread, ttag, str) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "ReturnString", _A[2])',
          \ [self['__lua_ref'], [a:thread, a:ttag, a:str]])
  endfunction
  function! conn.Return(thread, ttag, val) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "Return", _A[2])',
          \ [self['__lua_ref'], [a:thread, a:ttag, a:val]])
  endfunction

  " Macro expansion
  function! conn.SwankMacroExpandOne(expr, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SwankMacroExpandOne", _A[2])',
          \ [self['__lua_ref'], [a:expr] + a:000])
  endfunction
  function! conn.SwankMacroExpand(expr, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SwankMacroExpand", _A[2])',
          \ [self['__lua_ref'], [a:expr] + a:000])
  endfunction
  function! conn.SwankMacroExpandAll(expr, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "SwankMacroExpandAll", _A[2])',
          \ [self['__lua_ref'], [a:expr] + a:000])
  endfunction

  " Compilation
  function! conn.DisassembleForm(expr, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "DisassembleForm", _A[2])',
          \ [self['__lua_ref'], [a:expr] + a:000])
  endfunction
  function! conn.CompileStringForEmacs(expr, buffer, position, filename, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "CompileStringForEmacs", _A[2])',
          \ [self['__lua_ref'], [a:expr, a:buffer, a:position, a:filename] + a:000])
  endfunction
  function! conn.CompileFileForEmacs(filename, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "CompileFileForEmacs", _A[2])',
          \ [self['__lua_ref'], [a:filename] + a:000])
  endfunction
  function! conn.LoadFile(filename, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "LoadFile", _A[2])',
          \ [self['__lua_ref'], [a:filename] + a:000])
  endfunction

  " XRef
  function! conn.XRef(ref_type, name, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "XRef", _A[2])',
          \ [self['__lua_ref'], [a:ref_type, a:name] + a:000])
  endfunction
  function! conn.FindDefinitionsForEmacs(name, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "FindDefinitionsForEmacs", _A[2])',
          \ [self['__lua_ref'], [a:name] + a:000])
  endfunction
  function! conn.FindSourceLocationForEmacs(spec, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "FindSourceLocationForEmacs", _A[2])',
          \ [self['__lua_ref'], [a:spec] + a:000])
  endfunction
  function! conn.AproposListForEmacs(name, external_only, case_sensitive, package, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "AproposListForEmacs", _A[2])',
          \ [self['__lua_ref'], [a:name, a:external_only, a:case_sensitive, a:package] + a:000])
  endfunction
  function! conn.DocumentationSymbol(sym_name, ...) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "DocumentationSymbol", _A[2])',
          \ [self['__lua_ref'], [a:sym_name] + a:000])
  endfunction

  " Event routing
  function! conn.OnServerEvent(chan, msg) dict
    return luaeval('require("nvlime.core.connection")._call(_A[1], "OnServerEvent", _A[2])',
          \ [self['__lua_ref'], [a:chan, a:msg]])
  endfunction

  " Populate event handlers on the Lua side
  call luaeval('require("nvlime.core.connection.events").setup_event_handlers(_A[1])', lua_conn)

  return conn
endfunction

" ============================================================================
" Standalone utility functions
" ============================================================================

function! nvlime#SimpleSendCB(conn, Callback, caller, chan, msg) abort
  " Keep in VimScript to preserve conn type for callbacks
  call luaeval('require("nvlime.core.connection.messages")["check-return-status"](_A[1], _A[2])', [a:msg, a:caller])
  if type(a:Callback) == v:t_func
    call call(a:Callback, [a:conn, a:msg[1][1]])
  endif
endfunction

function! nvlime#PListToDict(plist)
  return luaeval('require("nvlime.core.connection.messages")["plist-to-dict"](nil, _A[1])', [a:plist])
endfunction

function! nvlime#ChainCallbacks(...)
  return luaeval('require("nvlime.core.connection.messages")["chain-callbacks"](nil, unpack(_A[1]))', [a:000])
endfunction

function! nvlime#ParseSourceLocation(loc)
  return luaeval('require("nvlime.core.connection.events")["parse-source-location"](nil, _A[1])', [a:loc])
endfunction

function! nvlime#GetValidSourceLocation(loc)
  return luaeval('require("nvlime.core.connection.events")["get-valid-source-location"](nil, _A[1])', [a:loc])
endfunction

function! nvlime#ToRawForm(expr)
  return luaeval('require("nvlime.core.connection.events")["to-raw-form"](nil, _A[1])', [a:expr])
endfunction

function! nvlime#Memoize(func, key, cache, ...)
  return luaeval('require("nvlime.core.connection.events")["memoize"](nil, _A[1], _A[2], _A[3], _A[4], _A[5])',
        \ [a:func, a:key, a:cache, get(a:000, 0, v:null), get(a:000, 1, v:null)])
endfunction

function! nvlime#Rand()
  return luaeval('require("nvlime.core.connection.events")["rand"](nil)')
endfunction

function! nvlime#CheckReturnStatus(return_msg, caller)
  return luaeval('require("nvlime.core.connection.messages")["check-return-status"](_A[1], _A[2])',
        \ [a:return_msg, a:caller])
endfunction

function! nvlime#TryToCall(Callback, args)
  return luaeval('require("nvlime.core.connection.messages")["try-to-call"](_A[1], _A[2])',
        \ [a:Callback, a:args])
endfunction

function! nvlime#SYM(package, name)
  return luaeval('require("nvlime.core.connection").sym(_A[1], _A[2])', [a:package, a:name])
endfunction

function! nvlime#KW(name)
  return luaeval('require("nvlime.core.connection").kw(_A[1])', [a:name])
endfunction

function! nvlime#CL(name)
  return luaeval('require("nvlime.core.connection").cl(_A[1])', [a:name])
endfunction

function! nvlime#HasKey(dict, key)
  return luaeval('require("nvlime.core.connection").has_key(_A[1], _A[2])', [a:dict, a:key])
endfunction

function! nvlime#Get(dict, key, ...)
  return luaeval('require("nvlime.core.connection").get(_A[1], _A[2], _A[3])',
        \ [a:dict, a:key, get(a:000, 0, v:null)])
endfunction

function! nvlime#DummyCB(conn, result)
  return luaeval('require("nvlime.core.connection.events")["dummy-cb"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:result])
endfunction

function! nvlime#KeywordList2Dict(input)
  return luaeval('require("nvlime.core.connection.events")["keyword-list-2-dict"](nil, _A[1])', [a:input])
endfunction

function! nvlime#ClearCurrentBuffer()
  return luaeval('require("nvlime.core.connection.events")["clear-current-buffer"](nil)')
endfunction

" ============================================================================
" Event handler functions
" ============================================================================

function! nvlime#OnPing(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-ping"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction

function! nvlime#OnNewPackage(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-new-package"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction

function! nvlime#OnDebug(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-debug"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction

function! nvlime#OnDebugActivate(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-debug-activate"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction

function! nvlime#OnDebugReturn(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-debug-return"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction

function! nvlime#OnWriteString(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-write-string"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction

function! nvlime#OnReadString(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-read-string"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction

function! nvlime#OnReadFromMiniBuffer(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-read-from-minibuffer"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction

function! nvlime#OnIndentationUpdate(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-indentation-update"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction

function! nvlime#OnNewFeatures(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-new-features"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction

function! nvlime#OnInvalidRPC(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-invalid-rpc"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction

function! nvlime#OnInspect(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-inspect"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction

function! nvlime#OnChannelSend(conn, msg)
  return luaeval('require("nvlime.core.connection.events")["on-channel-send"](_A[1], _A[2])',
        \ [a:conn['__lua_ref'], a:msg])
endfunction
