"Compiler notes module — Fennel migration of autoload/nvlime/ui/compiler_notes.vim (90 lines).
Provides buffer-based display of compiler warnings/errors with coordinates
and interactive source location jumping."

(local {: bufnr
         : setbufvar
         : getbufvar
         : getcurpos
         : setpos
         : win_gotoid}
       vim.fn)

(local {: nvim_buf_set_lines}
       vim.api)

(local ui (require "nvlime.core.ui"))
(local messages (require "nvlime.core.connection.messages"))
(local events (require "nvlime.core.connection.events"))
(local conn (require "nvlime.core.connection"))

(local compiler-notes {})

;;; ============================================================================
;;; Private helpers
;;; ============================================================================

(fn compiler-notes.init-buffer [conn orig-win]
  "Create and configure the compiler notes buffer.
  conn: connection object
  orig-win: original window id to return to
  Returns buffer number."
  (let [buf-name (ui.compiler-notes-buf-name conn)
        buf (bufnr buf-name true)]
    (when (not (ui.nvlime-buffer-initialized buf))
      (ui.set-nvlime-buffer-opts buf conn)
      (setbufvar buf :filetype "nvlime_notes"))
    (setbufvar buf "nvlime_notes_orig_win" orig-win)
    buf))

(fn compiler-notes.fill-buffer [note-list]
  "Fill the current buffer with compiler notes.
  note-list: list of note plists, or nil for empty.
  Sets b:nvlime_compiler_note_coords and b:nvlime_compiler_note_list."
  (vim.cmd "setlocal modifiable")

  (when (not note-list)
    (ui.replace-content "No message from the compiler.")
    (set vim.b.nvlime_compiler_note_coords [])
    (set vim.b.nvlime_compiler_note_list [])
    (values))

  (var coords [])
  (var nlist [])
  (nvim_buf_set_lines 0 0 -1 false [])
  (var idx 0)
  (var note-count (length note-list))

  (for [_ note (ipairs note-list)]
    (let [note-dict (messages.plist-to-dict nil note)]
      (table.insert nlist note-dict)

      (let [begin-pos (getcurpos)]
        (ui.append-string (.. (. note-dict.SEVERITY :name) ": "
                              note-dict.MESSAGE)
                          nil)
        (let [eof-coord (ui.get-end-of-file-coord)]
          (when (< idx (- note-count 1))
            (ui.append-string "\n--\n" nil))
          (table.insert coords
                        {:begin [(. begin-pos 1) (. begin-pos 2)]
                         :end eof-coord
                         :type "NOTE"
                         :id idx})))
      (set idx (+ idx 1))))

  (setpos "." [0 1 1 0 1])
  (vim.cmd "setlocal nomodifiable")

  (set vim.b.nvlime_compiler_note_coords coords)
  (set vim.b.nvlime_compiler_note_list nlist))

(fn compiler-notes.open-cur-note [edit-cmd]
  "Jump to the source location of the note under the cursor.
  edit-cmd: Vim edit command (default: 'hide edit')."
  (var note-coord nil)
  (let [edit-cmd (or edit-cmd "hide edit")
        cur-pos (getcurpos)]

    ;; Find the coordinate region under cursor
    (each [_ c (ipairs vim.b.nvlime_compiler_note_coords)]
      (when ((. vim.fn "nvlime#ui#MatchCoord") c (. cur-pos 1) (. cur-pos 2))
        (set note-coord c)
        (values)))

    (when (not note-coord)
      (values))

    (let [raw-note-loc (conn.get
                        (. vim.b.nvlime_compiler_note_list (. note-coord :id))
                        "LOCATION"
                        nil)
          pcall-result (pcall (fn []
                                (let [note-loc (events.parse-source-location nil
                                                       raw-note-loc)]
                                  (events.get-valid-source-location nil note-loc))))
          valid-loc (if (. pcall-result 1)
                      (. pcall-result 2)
                      [])]

      (if (and (> (length valid-loc) 0)
               (. valid-loc 1)
               (not= (. valid-loc 1) nil))
          ;; Has valid location — navigate to source
          (do
            (let [orig-win (getbufvar "%" "nvlime_notes_orig_win" nil)
                  [win-to-go count-specified] (ui.choose-window-with-count orig-win)]
              (when (> win-to-go 0)
                (win_gotoid win-to-go))
              (when (and (<= win-to-go 0) count-specified)
                (values))
              (ui.show-source vim.b.nvlime_conn valid-loc edit-cmd
                              count-specified)))
          ;; No valid location
          (if (and raw-note-loc
                   (= (. raw-note-loc 0 "name") "ERROR"))
              (ui.err-msg (. raw-note-loc 1))
              (ui.err-msg "No source available."))))))

;;; ============================================================================
;;; Module export
;;; ============================================================================

compiler-notes
