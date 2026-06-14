(local pbuf (require "parsley.buffer"))
(local {: nvim_create_autocmd
        : nvim_buf_call
        : nvim_set_option_value
        : nvim_get_option_value
        : nvim_buf_set_name
        : nvim_buf_set_var
        : nvim_clear_autocmds
        : nvim_create_buf
        : nvim_buf_set_lines
        : nvim_buf_get_var
        : nvim_exec}
       vim.api)

(local M {})

(tset M
      :names {:repl "repl"
              :sldb "sldb"
              :xref "xref"
              :input "input"
              :notes "notes"
              :trace "trace"
              :server "server"
              :apropos "apropos"
              :arglist "arglist"
              :keymaps "keymaps"
              :threads "threads"
              :inspector "inspector"
              :description "description"
              :disassembly "disassembly"
              :macroexpand "macroexpand"
              :documentation "documentation"})

(macro with-modifiable [bufnr ...]
  "Allows making changes to the text in the buffer
even if its 'nomodifiable' option is set."
  `(let [old-mod# (nvim_get_option_value "modifiable" {:buf ,bufnr})]
     (nvim_set_option_value "modifiable" true {:buf ,bufnr})
     (let [(ok# err#) (pcall (fn [] (do ,(unpack [...]))))]
       (nvim_set_option_value "modifiable" old-mod# {:buf ,bufnr})
       (when (not ok#)
         (error err#)))))

;;; ...string -> BufName
(fn M.gen-name [...]
  "Generate name for the nvlime buffers."
  (.. "nvlime://" (table.concat [...] "/")))

;;; string -> BufName
(fn M.gen-repl-name [conn-name]
  "Generates repl buffer name."
  (M.gen-name (or conn-name "default") M.names.repl))

;;; string integer -> BufName
(fn M.gen-sldb-name [conn-name thread]
  "Generates sldb buffer name."
  (M.gen-name
    conn-name M.names.sldb thread))

;;; string -> string
(fn M.gen-filetype [suffix]
  "Generates nvlime filetype."
  (.. "nvlime_" suffix))

;;; BufNr string -> any
(fn M.get-opt [bufnr opt]
  "Gets buffer local option `opt`."
  (nvim_get_option_value opt {:buf bufnr}))

;;; BufNr {any} ->
(fn M.set-opts [bufnr opts]
  "Sets buffer local options from the hash table where
key - option name, value - option value."
  (each [opt val (pairs opts)]
    (nvim_set_option_value opt val {:buf bufnr}))
  nil)

;;; BufNr {any} ->
(fn M.set-vars [bufnr vars]
  "Sets buffer variables from the hash table where
key - var name, value - var value."
  (each [v val (pairs vars)]
    (nvim_buf_set_var bufnr v val)))

;;; TODO convert to macro
;;; BufNr [string] ->
(fn M.vim-call! [bufnr cmds]
  "Calls vim commands temporally setting buffer with `bufnr` as current buffer."
  (nvim_buf_call
    bufnr #(each [_ c (ipairs cmds)]
             (nvim_exec c false))))

;;; BufNr ->
(fn M.set-conn-var! [bufnr]
  "Ensures b:nvlime_conn is set to the current connection on the target buffer."
  (local conn-manager (require "nvlime.core.conn_manager"))
  (let [conn (conn-manager.get false)]
    (when conn
      (nvim_buf_set_var bufnr "nvlime_conn" conn))
    conn))

;;; BufNr -> ?{any}
(fn M.get-conn-var! [bufnr]
  "Returns b:nvlime_conn variable, but without vimscript methods
in it. Returns nil if it is not present."
  (M.set-conn-var! bufnr)
  (case (pcall nvim_buf_get_var bufnr "nvlime_conn")
    (true conn) conn))

;;; BufName bool ?(fn [BufNr]) -> BufNr
(fn M.create [name listed? callback]
  "Creates a new buffer with the default options and returns its number.
Additional configuration can be done with `callback` function."
  (let [bufnr (nvim_create_buf listed? false)]
    (nvim_buf_set_name bufnr name)
    (M.set-opts bufnr {:modifiable false
                       :swapfile false
                       :modeline false
                       :buftype "nofile"})
    ;;; Always preserve 'nolisted' option, because some neovim
    ;;; keybinding can change it's value (like `C-^`)
    (when (not listed?)
      (nvim_create_autocmd "BufWinEnter"
        {:buffer bufnr
         :callback #(M.set-opts bufnr {:buflisted false})})
      ;; clear autocmds
      (nvim_create_autocmd "BufWipeout"
        {:buffer bufnr
         :callback #(nvim_clear_autocmds
                     {:event "BufWinEnter"
                     :buffer bufnr})
         :once true}))
    (when callback (callback bufnr))
    bufnr))

;;; BufName bool ?(fn [BufNr]) -> BufNr
(fn M.create-if-not-exists [name listed? callback]
  "Creates new buffer only if buffer with the `name` doesn't exists.
Returns buffer number in any case."
  (if (pbuf.exists? name)
      (vim.fn.bufnr name)
      (M.create name listed? callback)))

;;; BufName FileType -> BufNr
(fn M.create-listed [name filetype]
  "Creates a new buffer which would be listed."
  (M.create-if-not-exists
    name true #(M.set-opts $ {: filetype})))

;;; BufName FileType -> BufNr
(fn M.create-nolisted [name filetype]
  "Creates new buffer which wouldn't be listed.
Not shown up for `:ls`, but present for `:ls!`"
  (M.create-if-not-exists
    name false #(M.set-opts $ {: filetype})))

;;; BufName FileType -> BufNr
(fn M.create-scratch [name filetype]
  "Creates new buffer which wouldn't be listed.
And also would be wiped out after becomeing hidden."
  (M.create-if-not-exists
    name false #(M.set-opts $ {:filetype filetype
                                    :bufhidden "wipe"})))

;;; BufName FileType -> BufNr
(fn M.create-scratch-with-conn-var! [name filetype]
  "Creates new scratch buffer and also set `b:nvlime_conn`."
  (let [callback
        (fn [bufnr]
          (M.set-conn-var! bufnr)
          (M.set-opts bufnr {:filetype filetype
                                  :bufhidden "wipe"}))]
    (M.create-if-not-exists name false #(callback $))))

;;; BufNr [string] ...[string] ->
(fn M.fill! [bufnr ...]
  "Changes all lines of the buffer with `bufnr` to `lines` and
any other variable number of [string] appended right after the `lines`."
  (let [args [...]
         lines (. args 1)]
    (table.remove args 1)
    (with-modifiable bufnr
      (nvim_buf_set_lines bufnr 0 -1 false lines)
      (each [_ ls (ipairs args)]
        (nvim_buf_set_lines bufnr -1 -1 false ls)))))

;;; BufNr ...[string] ->
(fn M.append! [bufnr ...]
  "Appends `...` any number of list of strings to the end of the
  buffer with `bufnr`."
  (let [args [...]]
    (with-modifiable bufnr
      (when (> (length args) 0)
        (each [_ ls (ipairs args)]
          (nvim_buf_set_lines bufnr -1 -1 false ls))))))

M
