" Shim: forwards to Fennel nvlime.core.contrib.trace_dialog
function! nvlime#contrib#trace_dialog#ClearTraceTree(...) dict
  return luaeval('require("nvlime.core.contrib.trace_dialog").clear-trace-tree(_A[1], _A[2])', [self, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#trace_dialog#DialogToggleTrace(spec, ...) dict
  return luaeval('require("nvlime.core.contrib.trace_dialog").dialog-toggle-trace(_A[1], _A[2], _A[3])', [self, a:spec, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#trace_dialog#DialogTrace(spec, ...) dict
  return luaeval('require("nvlime.core.contrib.trace_dialog").dialog-trace(_A[1], _A[2], _A[3])', [self, a:spec, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#trace_dialog#DialogUntrace(spec, ...) dict
  return luaeval('require("nvlime.core.contrib.trace_dialog").dialog-untrace(_A[1], _A[2], _A[3])', [self, a:spec, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#trace_dialog#DialogUntraceAll(...) dict
  return luaeval('require("nvlime.core.contrib.trace_dialog").dialog-untrace-all(_A[1], _A[2])', [self, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#trace_dialog#FindTrace(id, ...) dict
  return luaeval('require("nvlime.core.contrib.trace_dialog").find-trace(_A[1], _A[2], _A[3])', [self, a:id, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#trace_dialog#FindTracePart(id, part_id, type, ...) dict
  return luaeval('require("nvlime.core.contrib.trace_dialog").find-trace-part(_A[1], _A[2], _A[3], _A[4], _A[5])', [self, a:id, a:part_id, a:type, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#trace_dialog#InspectTracePart(id, part_id, type, ...) dict
  return luaeval('require("nvlime.core.contrib.trace_dialog").inspect-trace-part(_A[1], _A[2], _A[3], _A[4], _A[5])', [self, a:id, a:part_id, a:type, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#trace_dialog#ReportPartialTree(key, ...) dict
  return luaeval('require("nvlime.core.contrib.trace_dialog").report-partial-tree(_A[1], _A[2], _A[3])', [self, a:key, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#trace_dialog#ReportSpecs(...) dict
  return luaeval('require("nvlime.core.contrib.trace_dialog").report-specs(_A[1], _A[2])', [self, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#trace_dialog#ReportTotal(...) dict
  return luaeval('require("nvlime.core.contrib.trace_dialog").report-total(_A[1], _A[2])', [self, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#trace_dialog#ReportTraceDetail(id, ...) dict
  return luaeval('require("nvlime.core.contrib.trace_dialog").report-trace-detail(_A[1], _A[2], _A[3])', [self, a:id, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#trace_dialog#Init(conn)
  return luaeval('require("nvlime.core.contrib.trace_dialog").init-trace-dialog(_A[1])', a:conn)
endfunction
" vim: sw=2
