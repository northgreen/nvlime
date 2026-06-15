"Cursor/Expression helpers — migrated from autoload/nvlime/ui.vim (lines 480-934).
Provides functions for extracting text under cursor, finding expression boundaries,
and navigating Common Lisp S-expressions."

(local search (require "nvlime.search"))

(local ui-cursors {})

;;; ============================================================================
;;; Character / Atom under cursor
;;; ============================================================================

(fn cur-char []
  "Get character under cursor."
  (vim.fn.matchstr (vim.fn.getline ".")
                   (.. "\\%" (vim.fn.col ".") "c.")))

(fn cur-atom []
  "Get atom under cursor (with expanded iskeyword for Lisp operators)."
  (let [old-kw vim.o.iskeyword]
    (set vim.o.iskeyword
         (.. old-kw ",+,-,*,/,%,<,=,>,:,$,?,!,@-@,94,~,#,|,&,.,{,},[,]"))
    (let [result (vim.fn.expand "<cword>")]
      (set vim.o.iskeyword old-kw)
      result)))

(fn cur-symbol []
  "Get symbol at cursor (quote + atom)."
  (let [sym (cur-atom)]
    (if (> (length sym) 0)
        (.. "'" sym)
        "")))

;;; ============================================================================
;;; Text extraction
;;; ============================================================================

(fn get-text [from-pos to-pos]
  "Get text between two positions [line, col]."
  (let [s-line (. from-pos 1)
        s-col (. from-pos 2)
        e-line (. to-pos 1)
        e-col (. to-pos 2)
        lines (vim.fn.getline s-line e-line)]
    (if (= (length lines) 1)
        (tset lines 1
              (vim.fn.strpart (. lines 1) (- s-col 1) (+ (- e-col s-col) 1)))
        (> (length lines) 1)
        (do
          (tset lines 1 (vim.fn.strpart (. lines 1) (- s-col 1)))
          (tset lines (length lines)
                (vim.fn.strpart (. lines (length lines)) 0 e-col))))
    (table.concat lines "\n")))

;;; ============================================================================
;;; Skip region detection
;;; ============================================================================

(fn in-skip-region? [line col]
  "Check if cursor is inside a skip region (string, comment, etc.)."
  (when (not= vim.b.current_syntax nil)
    (let [skip-groups ["string" "character" "comment" "singlequote"
                       "escape" "symbol"]
          synstack (vim.fn.synstack line col)
          len (length synstack)
          ids [(. synstack len)
               (. synstack (math.max 1 (- len 1)))
               (. synstack (math.max 1 (- len 2)))]]
      (var found false)
      (each [_ synid (ipairs ids) &until found]
        (let [name (string.lower (vim.fn.synIDattr synid "name"))]
          (each [_ pattern (ipairs skip-groups) &until found]
            (when (string.find name pattern 1 true)
              (set found true)))))
      found)))

;;; ============================================================================
;;; Expression position
;;; ============================================================================

(local cur-expr-pos-search-flags
  {:begin ["cbnW" "bnW" "bnW"]
   :end ["nW" "cnW" "nW"]})

(fn cur-expr-pos [cur-char-val side]
  "Find expression position (begin or end)."
  (let [side (or side "begin")
        flags (if (= cur-char-val "(")
                  (. cur-expr-pos-search-flags side 1)
                  (= cur-char-val ")")
                  (. cur-expr-pos-search-flags side 2)
                  (. cur-expr-pos-search-flags side 3))]
    (vim.fn.searchpairpos "(" "" ")" flags "0")))

(fn cur-expr [return-pos]
  "Get expression under cursor."
  (let [return-pos (or return-pos false)
        cur-ch (cur-char)
        from-pos (cur-expr-pos cur-ch "begin")
        to-pos (cur-expr-pos cur-ch "end")
        expr (get-text from-pos to-pos)]
    (if return-pos
        (values expr from-pos to-pos)
        expr)))

;;; ============================================================================
;;; Top-level expression position
;;; ============================================================================

(fn cur-top-expr-pos [side]
  "Get top-level expression position."
  (let [side (or side "begin")
        search-flags (if (= side "begin") "bW" "W")
        old-cur-pos (vim.fn.getcurpos)]
    (var last-pos [0 0])
    (var cur-level 1)
    (while true
      (let [cur-pos (vim.fn.searchpairpos "(" "" ")" search-flags "0")]
        (when (or (<= (. cur-pos 1) 0) (<= (. cur-pos 2) 0))
          (lua "break"))
        (when (not (in-skip-region? (. cur-pos 1) (. cur-pos 2)))
          (set last-pos cur-pos)
          (set cur-level (+ cur-level 1)))
        (when (> cur-level 1000)
          (lua "break"))))
    (vim.fn.setpos "." old-cur-pos)
    (if (and (> (. last-pos 1) 0) (> (. last-pos 2) 0))
        last-pos
        (let [ch (cur-char)]
          (if (or (= ch "(") (= ch ")"))
              (vim.fn.searchpairpos "(" "" ")" (.. search-flags "c") "0")
              [0 0])))))

(fn cur-top-expr [return-pos]
  "Get top-level expression under cursor."
  (let [return-pos (or return-pos false)
        top-pos (cur-top-expr-pos "begin")
        s-line (. top-pos 1)
        s-col (. top-pos 2)]
    (if (and (> s-line 0) (> s-col 0))
        (let [old-cur-pos (vim.fn.getcurpos)]
          (vim.fn.setpos "." [0 s-line s-col 0])
          (let [result (if return-pos
                           (let [(expr from-pos to-pos) (cur-expr true)]
                             [expr from-pos to-pos])
                           (cur-expr))]
            (vim.fn.setpos "." old-cur-pos)
            result))
        (if return-pos
            (values "" [0 0] [0 0])
            ""))))

;;; ============================================================================
;;; Expression or atom
;;; ============================================================================

(fn cur-expr-or-atom []
  "Get expression or fall back to atom."
  (let [str (cur-expr)]
    (if (> (length str) 0)
        str
        (cur-atom))))

;;; ============================================================================
;;; Visual selection
;;; ============================================================================

(fn cur-selection [return-pos]
  "Get visual selection text."
  (let [return-pos (or return-pos false)
        sel-start (vim.fn.getpos "'<")
        sel-end (vim.fn.getpos "'>")
        lines (vim.fn.getline (. sel-start 1) (. sel-end 1))]
    (if (= (. sel-start 1) (. sel-end 1))
        (tset lines 1
              (vim.fn.strpart (. lines 1) (- (. sel-start 2) 1)
                              (+ (- (. sel-end 2) (. sel-start 2)) 1)))
        (do
          (tset lines 1 (vim.fn.strpart (. lines 1) (- (. sel-start 2) 1)))
          (let [last-idx (length lines)]
            (tset lines last-idx
                  (vim.fn.strpart (. lines last-idx) 0 (. sel-end 2))))))
    (if return-pos
        (values (table.concat lines "\n")
                [(. sel-start 1) (. sel-start 2)]
                [(. sel-end 1) (. sel-end 2)])
        (table.concat lines "\n"))))

;;; ============================================================================
;;; Operator detection
;;; ============================================================================

(fn cur-operator []
  "Get operator at cursor (same-column constraint)."
  (let [cur-pos (vim.fn.getcurpos)
        line (. cur-pos 1)
        col (. cur-pos 2)
        result (search.pair_paren line col {:backward true :same-column? true})
        s-line (. result 1)
        s-col (. result 2)]
    (if (and (> s-line 0) (> s-col 0))
        (let [full-line (vim.fn.getline s-line)
              rest (string.sub full-line s-col)
              m (string.match rest "^%(%s*(%S+)")]
          (or m ""))
        "")))

(fn surrounding-operator []
  "Get surrounding operator (no same-column constraint)."
  (let [cur-pos (vim.fn.getcurpos)
        line (. cur-pos 1)
        col (. cur-pos 2)
        result (search.pair_paren line col {:backward true})
        s-line (. result 1)
        s-col (. result 2)]
    (if (and (> s-line 0) (> s-col 0))
        (let [full-line (vim.fn.getline s-line)
              rest (string.sub full-line s-col)
              m (string.match rest "^%(%s*(%S+)")]
          (or m ""))
        "")))

;;; ============================================================================
;;; Public API
;;; ============================================================================

(tset ui-cursors :cur_char cur-char)
(tset ui-cursors :cur_atom cur-atom)
(tset ui-cursors :cur_symbol cur-symbol)
(tset ui-cursors :get_text get-text)
(tset ui-cursors :cur_expr_pos cur-expr-pos)
(tset ui-cursors :cur_expr cur-expr)
(tset ui-cursors :cur_top_expr_pos cur-top-expr-pos)
(tset ui-cursors :cur_top_expr cur-top-expr)
(tset ui-cursors :cur_expr_or_atom cur-expr-or-atom)
(tset ui-cursors :cur_selection cur-selection)
(tset ui-cursors :cur_operator cur-operator)
(tset ui-cursors :surrounding_operator surrounding-operator)

ui-cursors
