(local connection (require "nvlime.core.connection"))
(local logger (require "nvlime.logger"))
(local {: nvim_buf_set_lines
        : nvim_err_writeln}
       vim.api)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Utility Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn connection.parse-source-location [self loc]
  "Parses a SWANK source location plist into a dict.
  Returns dict with FILE, POSITION, SNIPPET, BUFFER, OFFSET, COLUMN, FROM, TO keys."
  (when (or (not= (type (. loc 1)) "table")
            (not= (. (. loc 1) :name) "LOCATION"))
    (error (.. "nvlime#ParseSourceLocation: invalid location: " (vim.inspect loc))))
  (let [loc-obj {}]
    (do
      (for [i 2 (length loc)]
        (let [p (. loc i)]
          (when (= (type p) "table")
            (let [key-dict (. p 1)]
              (when key-dict
                (let [key (. key-dict :name)]
                  (match (length p)
                    1 (tset loc-obj key nil)
                    2 (tset loc-obj key (. p 2))
                    _ (tset loc-obj key
                            (let [result []]
                              (for [j 3 (length p)]
                                (table.insert result (. p j)))
                              result))))))))))
      loc-obj))

(fn connection.get-valid-source-location [self loc]
  "Normalizes a parsed location to [file-or-buffer, offset-or-position, snippet].
  Handles FILE, BUFFER-AND-FILE, BUFFER, SOURCE-FORM types."
  (let [loc-file (connection.get loc "FILE" nil)
        loc-buffer (connection.get loc "BUFFER" nil)
        loc-buf-and-file (connection.get loc "BUFFER-AND-FILE" nil)
        loc-src-form (connection.get loc "SOURCE-FORM" nil)]
    (cond
      loc-file
      (let [loc-pos (connection.get loc "POSITION" nil)
            loc-snippet (connection.get loc "SNIPPET" nil)]
        [loc-file loc-pos loc-snippet])

      loc-buffer
      (let [loc-offset (connection.get loc "OFFSET" nil)
            loc-snippet (connection.get loc "SNIPPET" nil)
            loc-offset (if loc-offset
                          (let [a (. loc-offset 1)
                                b (. loc-offset 2)]
                            (if (or (< a 0) (< b 0))
                                nil
                                (+ a b)))
                          nil)]
         [loc-buffer loc-offset loc-snippet])

      loc-buf-and-file
      (let [loc-offset (connection.get loc "OFFSET" nil)
            loc-snippet (connection.get loc "SNIPPET" nil)
            loc-offset (if loc-offset
                          (let [a (. loc-offset 1)
                                b (. loc-offset 2)]
                            (if (or (< a 0) (< b 0))
                                nil
                                (+ a b)))
                          nil)]
         [(or (. loc-buf-and-file 1) nil) loc-offset loc-snippet])

      loc-src-form [nil 1 loc-src-form]
      :else [])))

;;; Helper: ReadRawFormString
(fn connection.read-raw-form-string [self expr mark]
  "Reads a quoted string from expr starting at mark char.
  Returns [str delta] or throws on unterminated string."
  (if (= (. expr 1) mark)
      (loop [idx 2
             str-chars []]
        (if (< idx (length expr))
            (let [ch (. expr idx)]
              (if (= ch "\\")
                  (let [next-idx (+ idx 1)]
                    (if (< next-idx (length expr))
                        (recur next-idx (.. str-chars (. expr next-idx)))
                        (error "ReadRawFormString: early eof")))
                  (if (= ch mark)
                      [str-chars (+ idx 1)]
                      (recur (+ idx 1) (.. str-chars ch)))))
            (error "ReadRawFormString: unterminated string")))
      ["" 0]))

;;; Helper: ReadRawFormSharp
(fn connection.read-raw-form-sharp [self expr]
  "Reads a # reader macro from expr.
  Returns [str delta]."
  (if (= (. expr 1) "#")
      (if (<= (length expr) 1)
          [expr (length expr)]
          (let [ch2 (. expr 2)]
            (cond
              (= ch2 "(")  ["" 1]
              (= ch2 "\\") (if (< (length expr) 3)
                              (error "ReadRawFormSharp: early eof")
                              [(.. "#" "\\" (. expr 3)) 3])
              (= ch2 ".")  ["" 2]
              (vim.fn.match ch2 "\\_s") [(. expr 1) 1]
              :else [(.. "#" ch2) 2])))
      ["" 0]))

;;; Helper: ReadRawFormSemiColon
(fn connection.read-raw-form-semicolon [self expr]
  "Reads a ; comment from expr.
  Returns delta (number of chars to skip)."
  (if (= (. expr 1) ";")
      (loop [idx 2]
        (if (and (<= idx (length expr))
                 (not= (. expr idx) "\n"))
            (recur (+ idx 1))
            (+ idx 1)))
      0))

(fn connection.to-raw-form [self expr]
  "Parses a Lisp expression string into raw form for Autodoc.
  Complex hand-written tokenizer. Returns [form idx sub-form-complete]."
  (var form [])
  (var paren-level 0)
  (var idx 1)
  (var cur-token "")
  (while (<= idx (length expr))
    (var delta 1)
    (let [ch (. expr idx)]
      ;; Process character and update delta
      (cond
        (= ch "(")
        (set paren-level (+ paren-level 1))

        (= ch ")")
        (set paren-level (- paren-level 1))

        (vim.fn.match ch "\\_s")
        nil

        (or (= ch "\"") (= ch "|"))
        (let [result (pcall (fn [] [(self:read-raw-form-string (string.sub expr idx) ch)]))]
          (if (. result 1)
              (let [[str read-delta] (. result 2)]
                ;; Escape backslashes first, then the delimiter character
                (let [escaped (string.gsub (string.gsub str "\\" "\\\\") ch (.. "\\" ch))]
                  (set cur-token (.. cur-token ch escaped ch))
                  (set delta read-delta)))
              ;; Graceful degradation: skip remaining input
              (set delta (- (length expr) idx))))

        (= ch "#")
        (let [result (pcall (fn [] [(self:read-raw-form-sharp (string.sub expr idx))]))]
          (if (. result 1)
              (let [[str read-delta] (. result 2)]
                (set cur-token (.. cur-token str))
                (set delta read-delta))
              ;; Graceful degradation: skip remaining input
              (set delta (- (length expr) idx))))

        (or (= ch "'") (= ch "`") (= ch ","))
        (when (and (< (+ idx 1) (length expr))
                   (not= (. expr (+ idx 1)) "("))
          (set cur-token (.. cur-token ch)))

        (= ch "\\")
        (if (< (+ idx 1) (length expr))
            (do
              (set cur-token (.. cur-token (. expr idx) (. expr (+ idx 1))))
              (set delta 2))
            (set delta (- (length expr) (+ idx 1))))

        (= ch ";")
        (set delta (self:read-raw-form-semicolon (string.sub expr idx)))

        :else
        (set cur-token (.. cur-token ch)))

      ;; Check if we hit a delimiter and have accumulated a token
      (when (and (or (= ch "(") (= ch ")")
                     (vim.fn.match ch "\\_s")
                     (= ch ";"))
                 (> (length cur-token) 0))
        (table.insert form cur-token)
        (set cur-token ""))

      ;; Handle nested sub-forms
      (if (> paren-level 1)
          (let [(sub-form sub-delta sub-complete)
                (self:to-raw-form (string.sub expr idx))]
            (table.insert form sub-form)
            (set paren-level (- paren-level 1))
            (set delta sub-delta))

          (when (<= paren-level 0)
            (values [form (+ idx 1) true])))

      (set idx (+ idx delta))))

  ;; End of expression reached
  (when (= paren-level 0)
    (table.insert form "")
    (table.insert form (connection.sym self "SWANK" "%CURSOR-MARKER%")))

  [form (length expr) (= paren-level 0)])

(fn connection.memoize [self func key cache scope cache-limit]
  "Memoization with random eviction.
  Stores result under key in cache dict within scope.
  If cache-limit is specified and cache is full, randomly evicts entries."
  (let [cache-table (. scope cache)]
    (let [cache-table (if cache-table cache-table {})]
      (match (pcall (fn [] (. cache-table key)))
        (true result) result
        _ (let [new-result (func)
              cache-limit (or cache-limit nil)]
          (when (and cache-limit (> cache-limit 0)
                     (>= (length cache-table) cache-limit))
            (let [keys (keys cache-table)]
              (while (>= (length keys) cache-limit)
                (let [raw-idx (% (self:rand) (length keys))
                      idx (if (= raw-idx 0) 1 raw-idx)
                      rm-key (. keys idx)]
                  (tset cache-table rm-key nil)
                  (table.remove keys idx)))))
           (tset cache-table key new-result)
           (tset scope cache cache-table)
           new-result)))))

(fn connection.rand [self]
  "Returns random integer 1-99999."
  (+ (math.random 99998) 1))

(fn connection.keyword-list-2-dict [self input]
  "Converts keyword list to dict.
  Only includes elements where the key is a KEYWORD symbol."
  (if (= (type input) "table")
      (let [dct {}]
        (each [_ el (ipairs input)]
          (when (and (= (type el) "table")
                     (= (type (. el 1)) "table"))
            (let [package (. (. el 1) :package)]
              (when (or (= package "KEYWORD") (= package "keyword"))
                (tset dct (. (. el 1) :name) (. el 2))))))
        dct)
      nil))

(fn connection.clear-current-buffer [self]
  "Deletes all buffer lines via nvim_buf_set_lines."
  (nvim_buf_set_lines 0 0 -1 false []))

(fn connection.dummy-cb [self result]
  "Debug callback: echos result."
  (print "---------------------------")
  (print (vim.inspect result)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Server Event Handlers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(fn connection.on-ping [self msg]
  "Handles PING → calls self:pong."
  (let [thread (. msg 2)
        ttag (. msg 3)]
    (self:pong thread ttag)))

(fn connection.on-new-package [self msg]
  "Updates current package from msg[2]."
  (self:set-current-package [(or (. msg 1) nil) (or (. msg 2) nil)]))

(fn connection.on-debug [self msg]
  "Activates debugger UI via self.ui:on-debug."
  (logger.debug "connection.on-debug: ENTER")
  (when self.ui
    (let [thread (. msg 2)
          level (. msg 3)
          condition (. msg 4)
          restarts (. msg 5)
          frames (. msg 6)
          conts (. msg 7)]
      (logger.debug (.. "connection.on-debug: calling ui.on-debug, thread=" (tostring thread) " level=" (tostring level)))
      (self.ui:on-debug self thread level condition restarts frames conts)
      (logger.debug "connection.on-debug: AFTER ui.on-debug call")))
  (logger.debug "connection.on-debug: EXIT"))

(fn connection.on-debug-activate [self msg]
  "Debug activate."
  (when self.ui
    (let [thread (. msg 2)
          level (. msg 3)
          select (if (= (length msg) 4)
                    (. msg 4)
                    nil)]
      (self.ui:on-debug-activate self thread level select))))

(fn connection.on-debug-return [self msg]
  "Debug return."
  (when self.ui
    (let [thread (. msg 2)
          level (. msg 3)
          stepping (. msg 4)]
      (self.ui:on-debug-return self thread level stepping))))

(fn connection.on-write-string [self msg]
  "Writes output to UI."
  (when self.ui
    (let [str (. msg 2)
          str-type (if (>= (length msg) 3) (. msg 3) nil)
          thread (if (>= (length msg) 4) (. msg 4) nil)]
       (logger.debug (.. "on-write-string: len=" (tostring (length str)) " thread=" (tostring thread)))
      (self.ui:on-write-string self str str-type thread))))

(fn connection.on-read-string [self msg]
  "Reads string from UI."
  (when self.ui
    (let [thread (. msg 2)
          ttag (. msg 3)]
      (self.ui:on-read-string self thread ttag))))

(fn connection.on-read-from-minibuffer [self msg]
  "Reads from minibuffer."
  (when self.ui
    (let [thread (. msg 2)
          ttag (. msg 3)
          prompt (. msg 4)
          init-val (. msg 5)]
      (self.ui:on-read-from-minibuffer self thread ttag prompt init-val))))

(fn connection.on-indentation-update [self msg]
  "Updates indentation info."
  (when self.ui
    (let [indent-info (. msg 2)]
      (self.ui:on-indentation-update self indent-info))))

(fn connection.on-new-features [self msg]
  "Handles new features."
  (when self.ui
    (let [new-features (. msg 2)]
      (self.ui:on-new-features self new-features))))

(fn connection.on-invalid-rpc [self msg]
  "Handles invalid RPC."
  (when self.ui
    (let [id (. msg 2)
          err-msg (. msg 3)]
      (self.ui:on-invalid-rpc self id err-msg))))

(fn connection.on-inspect [self msg]
  "Activates inspector UI."
  (when self.ui
    (let [i-content (. msg 2)
          i-thread (. msg 3)
          i-tag (. msg 4)]
      (self.ui:on-inspect self i-content i-thread i-tag))))

(fn connection.on-channel-send [self msg]
  "Dispatches to local channel callback."
  (let [chan-id (. msg 2)
        msg-body (. msg 3)
        chan-obj (. self.local_channels chan-id)]
    (logger.debug (.. "channel-send: chan-id=" (tostring chan-id)))
    (if chan-obj
        (if chan-obj.callback
            (chan-obj.callback self chan-obj msg-body)
            (when (or vim.g._nvlime_debug false)
              (print (.. "Unhandled message: " (vim.inspect msg)))))
        (when (or vim.g._nvlime_debug false)
          (print (.. "Unknown channel: " (vim.inspect msg)))))))

(fn connection.setup_event_handlers [self]
  "Populates server_event_handlers with Lua callbacks.
  Called by VimScript shim after connection creation."
  (set self.server_event_handlers
    {"PING" (fn [self msg] (self:on-ping msg))
     "NEW-PACKAGE" (fn [self msg] (self:on-new-package msg))
     "DEBUG" (fn [self msg] (self:on-debug msg))
     "DEBUG-ACTIVATE" (fn [self msg] (self:on-debug-activate msg))
     "DEBUG-RETURN" (fn [self msg] (self:on-debug-return msg))
     "WRITE-STRING" (fn [self msg] (self:on-write-string msg))
     "READ-STRING" (fn [self msg] (self:on-read-string msg))
     "READ-FROM-MINIBUFFER" (fn [self msg] (self:on-read-from-minibuffer msg))
     "INDENTATION-UPDATE" (fn [self msg] (self:on-indentation-update msg))
     "NEW-FEATURES" (fn [self msg] (self:on-new-features msg))
     "INVALID-RPC" (fn [self msg] (self:on-invalid-rpc msg))
     "INSPECT" (fn [self msg] (self:on-inspect msg))
     "CHANNEL-SEND" (fn [self msg] (self:on-channel-send msg))}))

connection
