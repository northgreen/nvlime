"Xref module — Fennel migration of autoload/nvlime/ui/xref.vim (34 lines).
Provides cross-reference buffer display and source location navigation."

(local {: nvim_win_close}
       vim.api)

(local {: luaeval
         : setbufvar
         : float2nr
         : line}
       vim.fn)

(local ui (require "nvlime.core.ui"))

(local xref {})

;;; ============================================================================
;;; Public API
;;; ============================================================================

(fn xref.open-xref-buf [conn xref-list]
  "Open a buffer and fill it with cross-reference results.
  conn: connection object
  xref-list: list of xref entries from the compiler/REPL"
  (let [[_ bufnr] (luaeval
                    "require(\"nvlime.window.xref\").open(_A[1], _A[2])"
                    [xref-list
                     {:conn-name (. (. conn :cb_data) :name)}])]
    (setbufvar bufnr "nvlime_conn" conn)
    (setbufvar bufnr "xref_list" xref-list)))

(fn xref.open-cur-xref [edit-cmd]
  "Jump to the source location of the selected cross-reference.
  edit-cmd: command to use for opening the file (default: 'hide edit').
  Calculates the xref index from cursor position (2 lines per entry).
  Handles parse errors, missing files, and ERROR xref entries."
  (let [edit-cmd (or edit-cmd "hide edit")
        idx (- (float2nr (math.floor (/ (+ (line ".") 1) 2))) 1)
        raw-xref-loc (. (. vim.b.xref_list idx) 2)]
    (nvim_win_close 0 true)
    (pcall
      (fn []
        (let [xref-loc ((. vim.fn "nvlime#ParseSourceLocation") raw-xref-loc)
              valid-loc ((. vim.fn "nvlime#GetValidSourceLocation") xref-loc)]
          (if (and (> (length valid-loc) 0)
                   (!= (. valid-loc 2) nil))
              ;; Valid location found
              (let [path (. valid-loc 1)]
                (if (and (= (type path) "string")
                         (not (string.find path "^sftp://"))
                         (not (vim.fn.filereadable path)))
                    (ui.err-msg (.. "Not readable: " path))
                    (do
                      ((. vim.fn "nvlime#ui#ShowSource")
                       vim.b.nvlime_conn valid-loc edit-cmd))))
              ;; Check for ERROR xref entry
              (if (and (!= raw-xref-loc nil)
                       (= (. (. raw-xref-loc 1) "name") "ERROR"))
                  (ui.err-msg (. raw-xref-loc 2))
                  (ui.err-msg "No source available."))))))))

;;; ============================================================================
;;; Module export
;;; ============================================================================

xref
