# Changelog

All notable changes to Nvlime plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and does not adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2026-06-12

### Added

- **Server management commands fully integrated**: `NvlimeShowCurrentServer`, `NvlimeShowSelectedServer`, `NvlimeStopCurrentServer`, `NvlimeStopSelectedServer`, `NvlimeRestartCurrentServer`, `NvlimeRenameSelectedServer`
- **Connection close now supports server stop**: `close-cur-connection` prompts to stop associated server when disconnecting
- **Trace Dialog fully integrated**: `NvlimeDialogToggleTrace`, `NvlimeOpenTraceDialog` — toggle trace state and view trace results
- **MREPL fully integrated**: `NvlimeCreateMREPL` — create multiple REPL threads
- **New REPL show keymap**: `<LocalLeader>so` to open REPL window

### Changed

- Migration of deprecated Neovim APIs to 0.10+ `nvim_set_option_value` / `nvim_get_option_value` (6 files)

### Fixed

- **SWAN-FUZZY completion parsing**: fixed incorrect plist format assumption — fuzzy items use `[label, type, flags, menu]` format with flags at index 3
- **Package tracking**: `ui.cur-in-package` now reads buffer-local `vim.b.nvlime_cur_pkg` instead of always returning empty string
- **`vim.bo.filetype` access bug**: removed erroneous parens that caused `(vim.bo.filetype)` to compile as function call
- **`with-modifiable` macro pcall destructuring**: fixed multi-value return handling in Fennel `pcall`
- **Vararg indexing bug**: fixed `(args N)` function call vs `(. args N)` table index confusion
- **Macro underscope vs hyphen**: fixed global variable lookup in Fennel macro templates
- **mrepl.fnl setbufvar inconsistency**: unified to `nvim_set_option_value` API
- **Scrollbar hardcoding**: extracted `100` to `SCROLLBAR-BUFFER-SIZE` constant

### Deprecated

- **`user_contrib_initializers`** config option: does not work with Fennel (requires vim funcrefs), marked as DEPRECATED
- **`nvim_buf_get_option`/`nvim_buf_set_option`**: all uses migrated to `nvim_get/set_option_value` — zero deprecated API remaining in Fennel sources

## 2022-12-31

### Changed

- Instead of a single disassemble action in cl source files (for current form:
  default keymap "<LocalLeader>a"), there are two now: for current form
  ("<LocalLeader>aa") and current symbol ("<LocalLeader>as").

## 2022-12-29 (Configuration overhaul)

### Added

- `g:nvlime_mappings` config variable to change and remove default keymaps, or
to add new ones.

### Changed

- Instead of multiple `g:nvlime_..` config variables, there is now one dictionary
variable `g:nvlime_config`.

## 2022-12-24

### Added

- `g:nvlime_disable_arglist` option to disable automatic pop up of the arglist
  help window.

## 2022-12-23 (Birth of the fork)

### Added

- **sldb**: proper toggling of frame. Also removes snippet and file
  location information from it.
- **xref**: shows source file location.
- **apropos**: keymap `i` to show inspector for the symbol.
- **input**: Shows previous history entry with virtual lines, when buffer
  is empty.
- New syntax files for documentation, description, macroexpand, threads,
  xref, compiler notes, apropos, keymaps help and disassembly.
- nvim-cmp source for code autocompletion.
- Global keymaps `q`, `<Esc>`, `<leader>ww`, `<C-n>`, `<C-p>` and `<F1>`.
- Keymap to show documentation `K`.
- New options: `g:nvlime_main_win`, `g:nvlime_enable_cmp`,
  `g:nvlime_scroll_step`, `g:nvlime_scroll_down`, `g:nvlime_scroll_up`,
  `g:nvlime_disable_mappings`, `g:nvlime_disable_global_mappings`,
  `g:nvlime_disable_xref_mappings`, `g:nvlime_disable_apropos_mappings`,
  `g:nvlime_disable_sldb_mappings`, `g:nvlime_disable_repl_mappings`,
  `g:nvlime_disable_inspector_mappings`,
  `g:nvlime_disable_server_mappings`, `g:nvlime_disable_trace_mappings`,
  `g:nvlime_disable_notes_mappings`,

### Changed

- vlime is renamed to nvlime everywhere in the source code.
- Content of vim directory moved to top level.
- All windows except for repl, sbcl and compiler notes spawn as floating
  windows.
- Some parts of the plugin rewritten in fennel.
- `g:nvlime_input_history_limit` from 200 to 100.
- Keymaps are binded in the after/ftplugin files and to generate their
  documentation built-in description of `nvim_set_keymap()` is used.
- Some keymaps are changed: `<leader>t -> <leader>T` for threads, `<leader>i ->
  <leader>I` for interaction mode, inspector keymaps starting with `<leader>i`
  instead of `<leader>I`, trace dialog keymaps starting with `<leader>t`
  instead of `<leader>T`, compiler keymaps starting with `<leader>c` instead of
  `<leader>o`.
- **inspector** additional highlighting uses extmarks instead of matchadd().
- **input**: `<CR>` keymap when input buffer is empty will send previous
  history entry instead of canceling it.

### Removed

- Config variables: `g:vlime_buf_name_sep`, `g:vlime_window_settings`, `g:vlime_cl_use_terminal`,
`g:vlime_force_default_keys`
- Keymaps for closing plugin windows.
- Mapping overlays
- async code related to vim
- asyncomplete sources.
