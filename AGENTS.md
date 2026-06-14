# Nvlime — Common Lisp development environment for Neovim

## Build

```bash
make all           # Compile all fnl/ sources to lua/ (default target)
make clean         # Remove all compiled .lua files
make compile FILE=fnl/nvlime/core/foo.fnl  # Single file compile
make watch         # Auto-compile on file change (requires inotify-tools)
make check         # Verify all .fnl have corresponding .lua
make status        # Show compilation stats
```

- Fennel compiler: `/usr/bin/fennel`
- Source in `fnl/` -> compiled to `lua/` (same tree)
- `after/` dir compiles in-place (`.fnl` → `.lua` in same dir)
- `*macros.fnl` files are excluded from compilation (macros are compile-time)

## Test

```bash
make test          # luac syntax check + nvim-test functional tests
make test-check    # Lua syntax check only
make test-run      # Run nvim-test only (requires .test-deps/nvim-test)
```

- Tests use `nvim-test` framework (https://github.com/lewis6991/nvim-test)
- Test files in `tests/*_spec.lua` (plain Lua, not Fennel)
- Tests need compiled Lua files — run `make all` first
- `.test-deps/` is gitignored, auto-downloaded by make targets

## Key architecture

- **Entry point**: `fnl/nvlime/core/plugin.fnl` — user commands and main dispatch
- **Connection object**: `fnl/nvlime/core/connection.fnl` — base type, extended via mixin modules
- **Mixins** (require connection.fnl and add methods to it):
  - `core/connection/channels.fnl` — channel CRUD
  - `core/connection/messages.fnl` — SWANK message send/recv
  - `core/connection/sldb.fnl` — debugger
  - `core/connection/inspector.fnl` — inspector
  - `core/connection/swank.fnl` — protocol helpers
  - `core/connection/events.fnl` — event dispatching
- **Connection registry**: `fnl/nvlime/core/conn_manager.fnl` — global `connections{}` table, per-buffer `vim.b.nvlime_conn`
- **UI**: `fnl/nvlime/core/ui.fnl` + `fnl/nvlime/core/ui_events.fnl` (event handlers extend ui table)
- **Server lifecycle**: `fnl/nvlime/core/server.fnl` — Lisp process management
- **Config**: `fnl/nvlime/config.fnl` — `vim.g.nvlime_config` defaults
- **Logger**: `fnl/nvlime/logger.fnl` — LuaLog singleton with `config.log_level`
- **Buffer helpers**: `fnl/nvlime/buffer.fnl` — buffer creation, `set-conn-var!`, `with-modifiable` macro
- **Per-filetype keymaps**: `after/ftplugin/nvlime_*.fnl` — one per window type

## Critical gotchas

### Fennel footguns
- **Parentheses = function call**: `(vim.b.foo)` compiles to `vim.b.foo()` — use bare `vim.b.foo` for value access
- **Vararg indexing**: `(. args 1)` not `(args 1)` — latter compiles to function call
- **Colon vs dot**: `(obj:method arg)` auto-injects self; `((. obj :method) arg)` does NOT
- **pcall multi-value**: `(let [(ok err) (pcall ...)])` — single-value bind only gets the bool
- **Chain double-call**: `(get()):method()(arg)` crashes — use local binding first
- **`when` doesn't short-circuit**: sequential when blocks all execute; use `or` for chained conditions
- **`if` only protects its own expression**: `(if x (. x :field) "nil")` protects field access but any later `(. x :other)` in same expression is NOT protected by the `if`

### vim.b.* storage loses metatable
- Neovim serializes tables stored in `vim.b.*` / `vim.g.*` — metatables (including `__index`) are NOT preserved
- All objects stored as buffer variables must have methods copied directly onto them
- Pattern: `(each [k v (pairs module)] (when (= (type v) "function") (tset self k v)))`

### __index infinite recursion
```fennel
;; BAD — if gsub doesn't change key, (. self new-key) triggers __index again
(setmetatable t {:__index (fn [self key]
  (let [new-key (string.gsub key "_" "-")]
    (. self new-key)))})  ; hangs if key has no underscore

;; GOOD — guard against no-change
(setmetatable t {:__index (fn [self key]
  (let [new-key (string.gsub key "_" "-")]
    (if (= new-key key) nil (. self new-key)))})
```

### LuaLog usage
- `(logger:debug msg)` compiles to `logger:debug()(msg)` — double call, crashes
- Always use dot syntax with a let-binding: `(logger.debug msg)`
- Or bind to local: `(let [l (logger.get)] (l:debug msg))` — local:method is safe

### SWANK protocol
- Message format: `(keyword tag thread string style)` — string at index 2 (not 1)
- Thread identifiers are simple strings like `"REPL-THREAD"`, not dicts/lists
- Fuzzy completion items: `[label, type, flags-string, menu-string]` — flags at index 3, can be `vim.NIL`
- SLDB returns slot values starting at index 2 (1-indexed, first is metadata)

### REPL thread format
- Use `true` (CL `T`) as REPL thread tag, not strings or dicts
- `conn:set-current-thread true` or `conn:with-thread true`
