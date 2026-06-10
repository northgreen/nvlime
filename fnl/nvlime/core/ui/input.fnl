"Input module — Fennel migration of autoload/nvlime/ui/input.vim (145 lines).
Provides buffer-based and inline input dialogs for nvlime."

(local {: nvim_buf_delete}
       vim.api)

(local {: luaeval
         : bufnr
         : getline
         : cursor
         : mode}
        vim.fn)

(local ui (require "nvlime.core.ui"))

(local input {})

;;; ============================================================================
;;; Global variables
;;; ============================================================================

(tset vim.g :nvlime_input_history [])

;;; ============================================================================
;;; Private helpers
;;; ============================================================================

(fn input.check-input-validity [str-val cb cancellable]
  "Validate input string and call cb with the result.
  If str-val is empty, fall back to last history item.
  If no history and cancellable, show an error."
  (when (> (length str-val) 0)
    (cb str-val)
    (return))
  (let [history-len (length vim.g.nvlime_input_history)]
    (when (> history-len 0)
      (cb (. vim.g.nvlime_input_history history-len)))
    (when (and (= history-len 0) cancellable)
      (ui.err-msg "Canceled."))))

;;; ============================================================================
;;; Public API
;;; ============================================================================

(fn input.from-buffer [conn prompt init-val complete-cb]
  "Open an input buffer window and set up completion callback.
  conn: connection object
  prompt: string to show as window title
  init-val: initial text content
  complete-cb: function called when user submits input"
  (let [[_win-id buf-nr] (luaeval
                           "require(\"nvlime.window.input\").open(_A[1], _A[2])"
                           [init-val
                            {:conn-name (. (. conn :cb_data) :name)
                             :prompt prompt}])]
    (vim.fn.setbufvar buf-nr "nvlime_input_complete_cb" complete-cb)
    (cursor "$" (+ (length (getline "$")) 1))))

(fn input.maybe-input [str str-cb prompt default conn comp-type]
  "Get input from user via inline prompt or input buffer.
  str: pre-provided string (nil to prompt)
  str-cb: callback receiving the input string
  prompt: prompt text
  default: default value
  conn: connection object (nil for inline input)
  comp-type: completion type for inline input (nil for no completion)"
  (let [default (or default "")
        comp-type (or comp-type nil)]
    (if (not str)
        ;; str is nil — need to prompt user
        (if (not conn)
            ;; No connection — use inline vim.fn.input
            (let [content (if comp-type
                            (vim.fn.input prompt default comp-type)
                            (vim.fn.input prompt default))]
              (input.check-input-validity content str-cb true))
            ;; Has connection — use buffer-based input
            (let [cur-package (conn:get-current-package)
                  cur-buf (bufnr "%")
                  callback (fn []
                             (input.check-input-validity
                              (ui.cur-buffer-content true)
                              (fn [s]
                                (ui.with-buffer cur-buf
                                                (fn [] (str-cb s))))
                              true))]
              (input.from-buffer conn prompt default callback)
              (when (not= (bufnr "%") cur-buf)
                (conn:set-current-package cur-package))))
        ;; str is provided — validate directly
        (input.check-input-validity str str-cb false))))

(fn input.from-buffer-complete []
  "Complete the current input buffer session.
  Saves to history, stops insert mode, calls callback, and deletes buffer."
  (let [buf (bufnr "%")
        callback (vim.fn.getbufvar buf "nvlime_input_complete_cb" nil)]
    (when (not callback)
      (return))
    (let [content (ui.cur-buffer-content true)]
      (when (> (length content) 0)
        (input.save-history content)))
    (when (string.match (mode) "^i")
      (vim.cmd "stopinsert"))
    (callback)
    (when (vim.fn.bufloaded buf)
      (nvim_buf_delete buf {:force true}))))

(fn input.save-history [text]
  "Add text to input history, removing duplicates and respecting limit."
  (let [max-items (or vim.g.nvlime_options.input_history_limit 100)]
    (var history vim.g.nvlime_input_history)
    ;; Skip if same as last entry
    (when (and (> (length history) 0)
               (= (. history (length history)) text))
      (return))
    ;; Remove all previous occurrences
    (var prev-idx (vim.fn.index history text))
    (while (>= prev-idx 0)
      (vim.fn.remove history prev-idx)
      (set prev-idx (vim.fn.index history text)))
    ;; Append and trim
    (table.insert history text)
    (when (> (length history) max-items)
      (let [delta (- (length history) max-items)]
        (set history (vim.fn.slice history delta))))
    (tset vim.g :nvlime_input_history history)))

(fn input.get-history [backward idx]
  "Navigate input history backward or forward.
  backward: true for older entries, false for newer
  idx: current position (nil for end of history)
  Returns [next-idx text] pair."
  (let [history-len (length vim.g.nvlime_input_history)]
    (if (= history-len 0)
        [0 ""]
        (let [idx (or idx history-len)]
          (if backward
              (do
                (if (<= idx 0)
                    [0 ""]
                    (let [idx (if (> idx history-len) history-len idx)]
                      [(- idx 1) (. vim.g.nvlime_input_history idx)])))
              (do
                (if (>= idx (- history-len 1))
                    [history-len ""]
                    (let [idx (if (< idx -1) -1 idx)]
                      [(+ idx 1) (. vim.g.nvlime_input_history (+ idx 2))]))))))))

(fn input.next-history-item [backward]
  "Replace buffer content with previous/next history entry.
  backward: true for older entries, false for newer."
  (let [backward (or backward true)]
    (let [(next-idx text) (if (vim.fn.exists "b:nvlime_input_history_idx")
                            (input.get-history backward
                                               vim.b.nvlime_input_history_idx)
                            (do
                              (set vim.b.nvlime_input_orig_text
                                   (ui.cur-buffer-content true))
                              (input.get-history backward)))]
      (set vim.b.nvlime_input_history_idx next-idx)
      (if (> (length text) 0)
          (do
            ((. vim.fn "nvlime#ClearCurrentBuffer"))
            (ui.append-string text nil))
          (when (and (> next-idx 0)
                     (vim.fn.exists "b:nvlime_input_orig_text"))
            (vim.fn.unlet "b:nvlime_input_history_idx")
            ((. vim.fn "nvlime#ClearCurrentBuffer"))
            (ui.append-string vim.b.nvlime_input_orig_text nil)
            (vim.fn.unlet "b:nvlime_input_orig_text")))
      (cursor "$" (+ (length (getline "$")) 1)))))

;;; ============================================================================
;;; Module export
;;; ============================================================================

input
