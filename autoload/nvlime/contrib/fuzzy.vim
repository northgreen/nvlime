" Shim: forwards to Fennel nvlime.core.contrib.fuzzy
function! nvlime#contrib#fuzzy#FuzzyCompletions(symbol, ...) dict
  return luaeval('require("nvlime.core.contrib.fuzzy").fuzzy-completions(_A[1], _A[2], _A[3])', [self, a:symbol, a:0 ? a:1 : v:null])
endfunction

function! nvlime#contrib#fuzzy#Init(conn)
  return luaeval('require("nvlime.core.contrib.fuzzy").init-fuzzy(_A[1])', a:conn)
endfunction
" vim: sw=2
