"Core UI module — migrated from autoload/nvlime/ui.vim (first part).
Functions deferred to later files:
  - ui_events.fnl: On* event handlers
  - ui_cursor.fnl: CurChar, CurExpr, CurAtom, etc.
  - ui_coords.fnl: MatchCoord, FindNextCoord, etc.
  - ui_file.fnl: JumpToOrOpenFile, ShowSource"

(local {: nvim_set_current_win
        : nvim_buf_set_option
        : nvim_buf_set_var
        : nvim_buf_get_var
        : nvim_win_set_cursor
        : nvim_tabpage_get_win
        : nvim_list_tabpages}
       vim.api)

(local {: bufnr
        : bufwinid
        : win_getid
        : win_findbuf
        : win_id2win
        : getline
        : setline
        : cursor
        : line
        : strdisplaywidth
        : byte2line
        : line2byte
        : matchaddpos
        : matchdelete
        : filereadable
        : search
        : searchpos
        : searchpair
        : getcurpos
        : setpos
        : synID
        : synIDattr
        : synstack
        : matchlist
        : escape
        : copy}
       vim.fn)

(local ui {})

;;; ============================================================================
;;; Global variables
;;; ============================================================================

(tset vim.g :nvlime_horiz_sep "─")
(tset vim.g :nvlime_vert_sep "│")

(tset vim.g :nvlime_default_window_settings
      {:mrepl {:pos "botright" :size 0 :vertical false}
       :trace {:pos "botright" :size 0 :vertical false}})

;;; ============================================================================
;;; NvlimeUI singleton
;;; ============================================================================

(var ui-instance nil)

(fn ui.new []
  "Creates a new NvlimeUI object with buffer-package and buffer-thread maps."
  (let [self {:buffer-package-map {}
              :buffer-thread-map {}}]
    (setmetatable self {:__index ui})
    self))

(fn ui.get-ui []
  "Returns the NvlimeUI singleton, creating it on first call."
  (when (not ui-instance)
    (set ui-instance (ui.new)))
  ui-instance)

;;; ============================================================================
;;; Package / Thread context
;;; ============================================================================

(fn ui.cur-in-package []
  "Search for an in-package expression in current buffer.
  Returns package name string, or empty string if not found.
  NOTE: Stub — full implementation deferred to ui_cursor.fnl."
  "")

(fn ui.get-current-package [self buf]
  "Return the Common Lisp package bound to the specified buffer.
  If no package is bound yet, try to guess one from buffer content.
  Returns [full-name nickname] pair. Defaults to COMMON-LISP-USER."
  (let [cur-buf (bufnr (or buf "%"))
        buf-pkg (. self.buffer-package-map cur-buf)]
    (if (and buf-pkg (= (type buf-pkg) "table"))
        buf-pkg
        (let [in-pkg (ui.with-buffer cur-buf ui.cur-in-package)]
          (if (> (length in-pkg) 0)
              (let [pkg [in-pkg in-pkg]]
                (tset self.buffer-package-map cur-buf pkg)
                pkg)
              ["COMMON-LISP-USER" "CL-USER"])))))

(fn ui.set-current-package [self pkg buf]
  "Bind a Common Lisp package to the specified buffer.
  pkg should be [full-name nickname] pair."
  (tset self.buffer-package-map (bufnr (or buf "%")) pkg))

(fn ui.get-current-thread [self buf]
  "Return the thread bound to the buffer.
  Returns true when no thread is bound (debugger buffer only)."
  (or (. self.buffer-thread-map (bufnr (or buf "%"))) true))

(fn ui.set-current-thread [self thread buf]
  "Bind a thread to the specified buffer."
  (tset self.buffer-thread-map (bufnr (or buf "%")) thread))

;;; ============================================================================
;;; Buffer naming
;;; ============================================================================

(fn ui.sldb-buf-name [conn thread]
  "Returns the SLDB buffer name for a connection and thread."
  (.. "nvlime:/" (. (. conn :cb_data) :name) "/sldb/" thread))

(fn ui.repl-buf-name [conn]
  "Returns the REPL buffer name for a connection."
  (.. "nvlime:/" (. (. conn :cb_data) :name) "/repl"))

(fn ui.mrepl-buf-name [conn chan-obj]
  "Returns the MREPL buffer name for a connection and channel object."
  (.. "nvlime:/" (. (. conn :cb_data) :name) "/mrepl " (. chan-obj :id)))

(fn ui.arglist-buf-name []
  "Returns the arglist buffer name."
  "nvlime:/arglist")

(fn ui.trace-dialog-buf-name [conn]
  "Returns the trace dialog buffer name for a connection."
  (.. "nvlime:/" (. (. conn :cb_data) :name) "/trace"))

(fn ui.compiler-notes-buf-name [conn]
  "Returns the compiler notes buffer name for a connection."
  (.. "nvlime:/" (. (. conn :cb_data) :name) "/compiler-notes"))

(fn ui.server-buf-name [server-name]
  "Returns the server buffer name."
  (.. "nvlime:/" server-name))

;;; ============================================================================
;;; Window settings
;;; ============================================================================

(fn ui.get-window-settings [win-name]
  "Return settings for a window type.
  Returns [pos size vertical] tuple.
  Merges user settings from g:nvlime_window_settings over defaults."
  (let [settings (vim.get
                   vim.g.nvlime_default_window_settings win-name nil)]
    (when (not settings)
      (error (.. "nvlime#ui#GetWindowSettings: unknown window "
                 (vim.inspect win-name))))
    (let [settings (vim.deepcopy settings)]
      (when vim.g.nvlime_window_settings
        (var user-settings (vim.get
                               vim.g.nvlime_window_settings win-name {}))
        (when (= (type user-settings) "function")
          (set user-settings (user-settings)))
        (each [sk sv (pairs user-settings)]
          (tset settings sk sv)))
      [(vim.get settings "pos" "botright")
       (vim.get settings "size" 0)
       (vim.get settings "vertical" false)])))

;;; ============================================================================
;;; Window layout
;;; ============================================================================

(fn ui.get-cur-window-layout []
  "Capture the current window layout (ids, heights, widths)."
  (let [old-win (win_getid)
        old-ei vim.o.eventignore]
    (var layout [])
    (set vim.o.eventignore "all")
    (pcall (fn []
             (vim.cmd "windo call add(g:_nvlime_layout, {'id': win_getid(), 'height': winheight(0), 'width': winwidth(0)})")
             (set layout vim.g._nvlime_layout)
             (set vim.g._nvlime_layout nil)))
    (when (win_id2win old-win)
      (nvim_set_current_win old-win))
    (set vim.o.eventignore old-ei)
    layout))

(fn ui.restore-window-layout [layout]
  "Restore a previously captured window layout.
  No-op if window count doesn't match."
  (when (not (= (length layout) (vim.fn.winnr "$")))
    (values))
  (let [old-win (win_getid)
        old-ei vim.o.eventignore]
    (set vim.o.eventignore "all")
    (pcall (fn []
             (each [_ ws (ipairs layout)]
               (when (win_id2win ws.id)
                 (nvim_set_current_win ws.id)
                 (vim.cmd (.. "resize " ws.height))
                 (vim.cmd (.. "vertical resize " ws.width))))))
    (when (win_id2win old-win)
      (nvim_set_current_win old-win))
    (set vim.o.eventignore old-ei)))

(fn ui.keep-cur-window [func]
  "Call func, then restore cursor to the original window."
  (let [cur-win-id (win_getid)]
    (pcall func)
    (when (win_id2win cur-win-id)
      (nvim_set_current_win cur-win-id))))

(fn ui.with-buffer [buf func ev-ignore]
  "Call func with buf set as the current buffer.
  ev-ignore specifies what autocmd events to ignore (default: 'all')."
  (let [buf-win (bufwinid buf)
        buf-visible (>= buf-win 0)
        old-win (win-getid-safe)
        old-lazyredraw vim.o.lazyredraw
        old-ei vim.o.eventignore
        ev-ignore (or ev-ignore "all")]
    (set vim.o.lazyredraw true)
    (set vim.o.eventignore ev-ignore)
    (let [result (pcall (fn []
                          (if buf-visible
                              (ui.with-buffer-visible buf-win func old-ei)
                              (ui.with-buffer-hidden buf func old-ei ev-ignore))))]
      (when (win_id2win old-win)
        (nvim_set_current_win old-win))
      (set vim.o.lazyredraw old-lazyredraw)
      (set vim.o.eventignore old-ei)
      (if (. result 1)
          (. result 2)
          (error (. result 2))))))

(fn ui.with-buffer-visible [buf-win func old-ei]
  "Execute func with a visible buffer's window active."
  (nvim_set_current_win buf-win)
  (let [saved-ei vim.o.eventignore]
    (set vim.o.eventignore old-ei)
    (let [result (func)]
      (set vim.o.eventignore saved-ei)
      result)))

(fn ui.with-buffer-hidden [buf func old-ei ev-ignore]
  "Execute func with a hidden buffer (opens/closes temp window)."
  (let [old-layout (ui.get-cur-window-layout)]
    (pcall (fn []
             (ui.open-buffer buf false)
             (let [tmp-win-id (win_getid)]
               (let [saved-ei vim.o.eventignore]
                 (set vim.o.eventignore old-ei)
                 (let [result (func)]
                   (set vim.o.eventignore saved-ei)
                   (set vim.o.eventignore ev-ignore)
                   (let [win-num (win_id2win tmp-win-id)]
                     (when (> win-num 0)
                       (vim.cmd (.. win-num "wincmd c"))))
                   result)))))
    (set vim.o.eventignore ev-ignore)
    (ui.restore-window-layout old-layout)))

(fn win-getid-safe []
  "Safe wrapper for win_getid."
  (win_getid))

;;; ============================================================================
;;; Buffer opening / closing
;;; ============================================================================

(fn ui.open-buffer [name create pos vertical initial-size]
  "Open a buffer by name. Returns buffer number, or -1 if not found.
  create: if true, create the buffer if it doesn't exist.
  pos: window position ('aboveleft', 'belowright', 'topleft', 'botright').
  vertical: if true, split vertically.
  initial-size: initial window size."
  (let [buf (bufnr name (or create false))]
    (when (<= buf 0)
      (values buf))
    (when (< (bufwinid buf) 0)
      (let [split-cmd (.. "split #" buf)]
        (let [split-cmd (if vertical
                          (.. "vertical " split-cmd)
                          split-cmd)]
          (let [split-cmd (if (> (or initial-size 0) 0)
                            (.. initial-size split-cmd)
                            split-cmd)
                pos (or pos "")]
            (if (> (length pos) 0)
                (pcall vim.cmd (.. pos " " split-cmd))
                (pcall vim.cmd split-cmd))))))
    ;; Buffer already visible — jump to its window
    (when (> (bufwinid buf) 0)
      (nvim_set_current_win (bufwinid buf)))
    buf))

(fn ui.open-buffer-with-win-settings [buf-name buf-create win-name]
  "Open a buffer using window settings from g:nvlime_window_settings."
  (let [(win-pos win-size win-vert) (ui.get-window-settings win-name)]
    (ui.open-buffer buf-name buf-create win-pos win-vert win-size)))

(fn ui.close-buffer [buf]
  "Close all windows containing buf. Buffer remains loaded."
  (let [win-id-list (win_findbuf buf)]
    (when (<= (length win-id-list) 0)
      (values))
    (let [cur-win-id (win_getid)
          old-lazyredraw vim.o.lazyredraw]
      (var close-cur-win false)
      (set vim.o.lazyredraw true)
      (pcall (fn []
               (each [_ win-id (ipairs win-id-list)]
                 (if (= win-id cur-win-id)
                     (set close-cur-win true)
                     (when (win_id2win win-id)
                       (nvim_set_current_win win-id)
                       (vim.cmd "wincmd c"))))))
      (when (and (win_id2win cur-win-id) close-cur-win)
        (vim.cmd "wincmd c"))
      (set vim.o.lazyredraw old-lazyredraw))))

;;; ============================================================================
;;; Text manipulation
;;; ============================================================================

(fn ui.append-string [str target-line]
  "Append str to the specified line in the current buffer.
  Appends to last line if target-line is nil.
  Returns number of new lines added."
  (let [last-line-nr (line "$")
        to-append (or target-line last-line-nr)
        new-lines (vim.split str "\n" {:trimempty false})]
    (var sidx 0)
    (var eidx -1)
    (when (> to-append 0)
      (let [line-to-append (getline to-append)]
        (setline to-append (.. line-to-append (. new-lines 1)))
        (set sidx 1)))
    (when (and (< to-append last-line-nr) (> (length new-lines) 1))
      (let [line-after (getline (+ to-append 1))]
        (setline (+ to-append 1)
                 (.. (. new-lines (length new-lines)) line-after)))
        (set eidx -2))
    (let [start (+ to-append 1)
          end (+ to-append eidx)]
      (when (<= start end)
        (let [lines-to-add {}]
          (for [i (+ sidx 1) (+ eidx 1)]
            (tset lines-to-add (- i 1) (. new-lines i)))
          (vim.api.nvim_buf_set_lines 0 start end false lines-to-add))))
    (when (not target-line)
      (cursor (line "$") 1))
    (+ (length new-lines) eidx (- sidx) 1)))

(fn ui.replace-content [str first-line last-line]
  "Replace buffer content from first-line to last-line with str.
  Defaults: first-line=1, last-line=end of file."
  (let [first-line (or first-line 1)
        last-line (or last-line "$")]
    (pcall vim.cmd (.. first-line "," last-line "delete _"))
    (let [str (if (> first-line 1)
                (.. "\n" str)
                str)]
      (ui.append-string str (- first-line 1))
      (cursor [first-line 1 0 1]))))

(fn ui.indent-cur-line [indent]
  "Adjust indentation of the current line by indent spaces."
  (let [indent-str (if vim.o.expandtab
                     (string.rep " " indent)
                      (let [tabs (math.floor (/ indent vim.o.tabstop))
                           remainder (% indent vim.o.tabstop)]
                       (.. (string.rep "\t" tabs)
                           (string.rep " " remainder))))]
    (let [current-line (getline ".")]
      (let [new-line (string.gsub current-line "^%s*" indent-str)]
        (setline "." new-line)
        (let [spaces (ui.calc-leading-spaces new-line)]
          (vim.fn.setpos "." [0 (line ".") (+ spaces 1) 0 indent]))))))

(fn ui.calc-leading-spaces [str expand-tab]
  "Count leading whitespace characters in str.
  If expand-tab is true, tabs count as &tabstop spaces."
  (let [n-str (if expand-tab
                (string.gsub str "\t"
                             (string.rep " " vim.o.tabstop))
                str)]
    (let [spaces (string.find n-str "[^%s]")]
      (if spaces
          (- spaces 1)
          (length n-str)))))

;;; ============================================================================
;;; Text extraction
;;; ============================================================================

(fn ui.cur-buffer-content [raw]
  "Get the text content of the current buffer.
  Lines starting with ';' are dropped unless raw is true."
  (var lines (getline 1 "$"))
  (when (not raw)
    (let [filtered {}]
      (each [_ l (ipairs lines)]
        (when (not (string.find l "^%s*;"))
          (tset filtered (length filtered) l)))
      (set lines filtered)))
  (table.concat lines "\n"))

(fn ui.get-text [from-pos to-pos]
  "Retrieve text from from-pos to to-pos in current buffer.
  Positions are [line col] tuples (1-indexed)."
  (let [s-line (. from-pos 1)
        s-col (. from-pos 2)
        e-line (. to-pos 1)
        e-col (. to-pos 2)
        lines (getline s-line e-line)]
    (if (= (length lines) 1)
        (do
          (tset lines 1
                (string.sub (. lines 1) s-col (- e-col s-col -1)))
          (. lines 1))
        (do
          (tset lines 1 (string.sub (. lines 1) s-col))
          (let [last-idx (length lines)]
            (tset lines last-idx
                  (string.sub (. lines last-idx) 1 e-col)))
          (table.concat lines "\n")))))

(fn ui.get-end-of-file-coord []
  "Return [line col] of the end of file position."
  (let [last-line-nr (line "$")
        last-line (getline last-line-nr)
        last-col (length last-line)]
    [last-line-nr (if (<= last-col 0) 1 last-col)]))

;;; ============================================================================
;;; Window / file utilities
;;; ============================================================================

(fn ui.get-filetype-window-list [ft]
  "Return a list of [winid bufname] for windows with the given filetype."
  (let [old-win-id (win_getid)]
    (var winid-list [])
    (pcall (fn []
             (vim.cmd "windo if &filetype == '" ft
                        "| call add(g:_nvlime_ft_wins, [win_getid(), bufname('%')])"
                        "| endif")
             (set winid-list (or vim.g._nvlime_ft_wins []))
             (set vim.g._nvlime_ft_wins nil)))
    (when (win_id2win old-win-id)
      (nvim_set_current_win old-win-id))
    winid-list))

(fn ui.choose-window-with-count [default-win]
  "Choose a window using v:count.
  Returns [win-id count-specified] tuple."
  (var count-specified false)
  (let [win-to-go (if (> vim.v.count 0)
                    (do
                      (set count-specified true)
                      (let [wid (vim.fn.win_getid vim.v.count)]
                        (when (<= wid 0)
                          (ui.err-msg (.. "Invalid window number: " vim.v.count)))
                        wid))
                    (if (and default-win (> (win_id2win default-win) 0))
                        default-win
                        (let [win-list (ui.get-filetype-window-list "lisp")]
                          (if (> (length win-list) 0)
                              (. (. win-list 1) 1)
                              0))))]
    [win-to-go count-specified]))

(fn ui.is-yes-string [str]
  "Check if str matches 'y' or 'yes' (case-insensitive)."
  (not (not (string.find str "^[yY][eE][sS]?$"))))

;;; ============================================================================
;;; Buffer options
;;; ============================================================================

(fn ui.set-nvlime-buffer-opts [buf conn]
  "Set standard nvlime buffer options and connection variable."
  (nvim_buf_set_option buf :buftype "nofile")
  (nvim_buf_set_option buf :bufhidden "hide")
  (nvim_buf_set_option buf :swapfile false)
  (nvim_buf_set_option buf :buflisted true)
  (nvim_buf_set_var buf "nvlime_conn" conn))

(fn ui.nvlime-buffer-initialized [buf]
  "Check if buffer has been initialized with nvlime connection."
  (let [val (pcall nvim_buf_get_var buf "nvlime_conn")]
    (if (. val 1)
        (not (not (. val 2)))
        false)))

;;; ============================================================================
;;; Error display
;;; ============================================================================

(fn ui.err-msg [msg]
  "Show an error message."
  (vim.cmd "redraw")
  (vim.cmd "echohl ErrorMsg")
  (let [escaped (string.gsub (string.gsub msg "\\" "\\\\") "\"" "\\\"")]
    (vim.cmd (.. "echom \"" escaped "\"")))
  (vim.cmd "echohl None"))

;;; ============================================================================
;;; Window display
;;; ============================================================================

(fn ui.show-disassemble-form [conn content]
  "Show disassembly content in the disassembly window."
  (when (not content)
    (ui.err-msg "Blank disassemble."))
  (vim.fn.luaeval
    "require(\"nvlime.window.disassembly\").open(_A)"
    content))

(fn ui.show-arglist [conn content]
  "Show content in the arglist buffer."
  (vim.fn.luaeval
    "require(\"nvlime.window.arglist\").show(_A)"
    content))

;;; ============================================================================
;;; Pad helper
;;; ============================================================================

(fn ui.pad [prefix sep max-len]
  "Pad prefix with sep and spaces up to max-len display width."
  (.. prefix sep (string.rep " "
                             (+ (- max-len (strdisplaywidth prefix)) 1))))

;;; ============================================================================
;;; Coordinate matching / navigation
;;; ============================================================================

(fn ui.match-coord [coord cur-line cur-col]
  "Check if point (cur-line, cur-col) falls within coord range."
  (let [c-begin (. coord :begin)
        c-end (. coord :end)]
    (or
      ;; Null guard
      (when (or (not c-begin) (not c-end)) #f)

      ;; Single-line span
      (when (and (= (. c-begin 1) (. c-end 1))
                 (= cur-line (. c-begin 1))
                 (>= cur-col (. c-begin 2))
                 (<= cur-col (. c-end 2)))
        true)

      ;; Multi-line span
      (when (< (. c-begin 1) (. c-end 1))
        (or
          ;; On begin line
          (when (and (= cur-line (. c-begin 1))
                     (>= cur-col (. c-begin 2)))
            true)
          ;; On end line
          (when (and (= cur-line (. c-end 1))
                     (<= cur-col (. c-end 2)))
            true)
          ;; Between lines
          (when (and (> cur-line (. c-begin 1))
                     (< cur-line (. c-end 1)))
            true)))
      #f)))

(fn ui.compare-coords-forward [c1 c2]
  "Compare two coordinates for forward sorting. Returns true if c1 < c2."
  (if (> (. c1.begin 1) (. c2.begin 1))
      false
      (< (. c1.begin 1) (. c2.begin 1))
      true
      ;; Same line, compare column
      (> (. c1.begin 2) (. c2.begin 2))
      false
      (< (. c1.begin 2) (. c2.begin 2))
      true
      ;; Equal
      false))

(fn ui.compare-coords-backward [c1 c2]
  "Compare two coordinates for backward sorting. Returns true if c1 > c2."
  (if (> (. c1.begin 1) (. c2.begin 1))
      true
      (< (. c1.begin 1) (. c2.begin 1))
      false
      ;; Same line, compare column
      (> (. c1.begin 2) (. c2.begin 2))
      true
      (< (. c1.begin 2) (. c2.begin 2))
      false
      ;; Equal
      false))

(fn ui.sort-coords [coords forward]
  "Sort coordinates by begin position. Returns new sorted table.
  forward: true for ascending, false for descending."
  (let [sorted (copy coords)]
    (table.sort sorted
      (if forward
          ui.compare-coords-forward
          ui.compare-coords-backward))
    sorted))

(fn ui.find-next-coord [cur-pos sorted-coords forward]
  "Find the next/previous coordinate from a sorted list.
  cur-pos: [line col] tuple (1-indexed)
  sorted-coords: sorted array of coordinate tables
  forward: true for forward search, false for backward
  Returns coordinate table or nil."
  (var found nil)
  (for [i 1 (length sorted-coords)]
    (when (not found)
      (let [c (. sorted-coords i)
            c-begin (. c :begin)
            matches (if forward
                        (or (> (. c-begin 1) (. cur-pos 1))
                            (and (= (. c-begin 1) (. cur-pos 1))
                                 (> (. c-begin 2) (. cur-pos 2))))
                        (or (< (. c-begin 1) (. cur-pos 1))
                            (and (= (. c-begin 1) (. cur-pos 1))
                                 (< (. c-begin 2) (. cur-pos 2)))))]
        (when matches
          (set found c)))))
  found)

(fn ui.coords-to-match-pos [coords]
  "Convert coordinate list to matchaddpos format.
  coords: array of {:begin [line col] :end [line col]}
  Returns array of matchaddpos position specs."
  (let [pos-list []]
    (each [_ co (ipairs coords)]
      (let [cb (. co :begin)
            ce (. co :end)]
        (if (= (. cb 1) (. ce 1))
            ;; Single-line highlight
            (let [cline (. cb 1)
                  col (. cb 2)
                  len (+ (- (. ce 2) (. cb 2)) 1)]
              (table.insert pos-list [cline col len]))
            ;; Multi-line highlight
            (for [ln (. cb 1) (+ (. ce 1) 1)]
              (if (= ln (. cb 1))
                  ;; First line: from begin col to end of line
                  (let [col (. cb 2)
                        len (+ (- (length (getline ln)) (. cb 2)) 1)]
                    (table.insert pos-list [ln col len]))
                  (= ln (. ce 1))
                  ;; Last line: from start to end col
                  (let [col 1
                        len (. ce 2)]
                    (table.insert pos-list [ln col len]))
                  ;; Middle lines: entire line
                  (table.insert pos-list ln))))))
    pos-list))

(fn ui.match-add-coords [group coords]
  "Add highlight matches using matchaddpos.
  group: highlight group name
  coords: array of coordinate tables
  Returns array of match IDs."
  (let [pos-list (ui.coords-to-match-pos coords)
        match-list []
        stride 8
        total-len (length pos-list)]
    (for [i 0 (- total-len 1) stride]
      (let [slice []
            end (min (+ i stride) total-len)]
        (for [j (+ i 1) end]
          (table.insert slice (. pos-list j)))
        (if (= group "nvlime_replCoord")
            (table.insert match-list (matchaddpos group slice -1))
            (table.insert match-list (matchaddpos group slice)))))
    match-list))

(fn ui.match-delete-list [match-list]
  "Delete highlight matches. Ignores E803 (no such match ID).
  match-list: array of match IDs."
  (each [_ m (ipairs match-list)]
    (pcall matchdelete m)))

;;; ============================================================================
;;; File navigation
;;; ============================================================================

(fn ui.in-comment [cur-pos]
  "Check if cursor position is inside a comment.
  cur-pos: [bufnum lnum col off curswant] (from getcurpos)."
  (let [has-syntax (> (synstack (. cur-pos 2) (. cur-pos 3)) 0)
        syn-name (when has-syntax
                   (synIDattr (. (synstack (. cur-pos 2) (. cur-pos 3)) 1) :name))]
    (if (and has-syntax syn-name)
        (not (not (string.find syn-name "[Cc]omment")))
        ;; No syntax info — use searchpair
        (when (> (searchpair "#|" "" "|#" "bnW") 0)
          (values true)))))

(fn ui.in-string [cur-pos]
  "Check if cursor position is inside a string literal.
  cur-pos: [bufnum lnum col off curswant] (from getcurpos)."
  (let [has-syntax (> (synstack (. cur-pos 2) (. cur-pos 3)) 0)
        syn-name (when has-syntax
                   (synIDattr (. (synstack (. cur-pos 2) (. cur-pos 3)) 1) :name))]
    (if (and has-syntax syn-name)
        (not (not (string.find syn-name "[Ss]tring")))
        ;; Fallback: count unescaped quotes backwards
        (let [pattern "\\v((^|[^\\\\])@<=\")|(((^|[^\\\\])((\\\\\\\\)+))@<=\")"
              old-pos (getcurpos)]
          (var quote-count 0)
          (var quote-pos (searchpos pattern "bW"))
          (while (and (> (. quote-pos 1) 0) (> (. quote-pos 2) 0))
            (set quote-count (+ quote-count 1))
            (set quote-pos (searchpos pattern "bW")))
          (setpos "." old-pos)
          (> (math.fmod quote-count 2) 0)))))

(fn ui.normalize-package-name [name]
  "Normalize a Common Lisp package name string.
  Handles prefixes like #:, :, ' and double-quote wrappers.
  Returns uppercase package name."
  ;; Pattern 1: #?:... or ':... or '...
  (let [matches (matchlist name "^%(#[%:]?%:%)%(%.%+%)")]
    (if (> (length matches) 3)
        (string.upper (. matches 3))
        (let [matches2 (matchlist name "^\"%(%.%+%)\"")]
          (if (> (length matches2) 1)
              (string.upper (. matches2 1))
              "")))))

(fn ui.jump-to-or-open-file [file-path byte-pos snippet edit-cmd force-open]
  "Navigate to a file/buffer at a specific byte position.
  file-path: file path string or buffer number
  byte-pos: byte position within file (or nil)
  snippet: source snippet to search for (or nil)
  edit-cmd: Vim edit command (e.g., 'hide edit')
  force-open: if true, always open a new window."
  ;; Determine if buffer already exists and is visible
  (var buf-exists false)
  (when (not force-open)
    (let [file-buf (bufnr file-path)]
      (when (> file-buf 0)
        (let [buf-win (bufwinid file-buf)]
          (if (> buf-win 0)
              ;; Buffer visible
              (do
                (nvim_set_current_win buf-win)
                (set buf-exists true))
              (let [win-list (win_findbuf file-buf)]
                (when (> (length win-list) 0)
                  (nvim_set_current_win (. win-list 1))
                  (set buf-exists true))))))))

  (if buf-exists
      (vim.cmd "normal! m'")
      ;; Open the file
      (do
        (vim.cmd "normal! m'")
        (if (= (type file-path) "number")
            ;; Numeric buffer reference
            (let [existing-buf (bufnr file-path true)]
              (if (> existing-buf 0)
                  (let [pcall-result (pcall vim.cmd (.. edit-cmd " #" file-path))]
                    (when (not (. pcall-result 1))
                      ;; Check if we ended up in the right buffer
                      (let [cur-buf (bufnr "%")]
                        (when (not= cur-buf file-path)
                          (error (. pcall-result 2))))))
                  (do
                    (ui.err-msg (.. "Buffer " file-path " does not exist."))
                    (values))))
            ;; String path
            (if (= (string.sub file-path 1 7) "sftp://")
                (let [esc-path (escape file-path " \\")]
                  (vim.cmd (.. edit-cmd " " esc-path)))
                (if (filereadable file-path)
                    (let [esc-path (escape file-path " \\")]
                      (vim.cmd (.. edit-cmd " " esc-path)))
                    (do
                      (ui.err-msg (.. "Not readable: " file-path))
                      (values))))))))

  ;; Navigate to byte position
  (when byte-pos
    (let [src-line (byte2line byte-pos)]
      (setpos "." [0 src-line 1 0 1])
      (let [cur-byte (+ (line2byte ".") (vim.fn.col ".") -1)]
        (when (> (- byte-pos cur-byte) 0)
          (setpos "." [0 src-line (+ (- byte-pos cur-byte) 1) 0])))
      ;; Search for snippet
      (when snippet
        (let [first-line (string.match snippet "[^\n]*")
              escaped (string.gsub first-line "\\" "\\\\")
              to-search (.. "\\V" escaped)]
          (setpos "." [src-line 1 0 1])
          (search to-search "cW")))
      (vim.cmd "redraw")))

(fn ui.show-source [conn loc edit-cmd force-open]
  "Show source code at a location.
  conn: connection object
  loc: [file-name byte-pos snippet] tuple
  edit-cmd: Vim edit command (default: 'hide edit')
  force-open: if true, force open new window (default: false)."
  (let [edit-cmd (or edit-cmd "hide edit")
        force-open (or force-open false)
        file-name (. loc 1)
        byte-pos (. loc 2)
        snippet (. loc 3)]
    (if (not file-name)
        ;; No file — show in documentation window
        (vim.fn.luaeval "require\"nvlime.window.documentation\".open(_A)"
                        (.. "Source form:\n\n" snippet))
        ;; Navigate to file
        (ui.jump-to-or-open-file file-name byte-pos snippet edit-cmd force-open))))

;;; ============================================================================
;;; Module export
;;; ============================================================================

;;; Hyphen/underscore compatibility for VimScript shim
(setmetatable ui
  {:__index (fn [self key]
              (. self (string.gsub key "_" "-")))})

ui
