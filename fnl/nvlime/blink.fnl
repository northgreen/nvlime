(local blink-types (require "blink.cmp.types"))
(local buffer (require "nvlime.buffer"))
(local opts (require "nvlime.config"))

;; Load connection mixin modules to ensure methods are registered
(require "nvlime.core.connection.swank")
(require "nvlime.core.contrib.fuzzy")
(local connection (require "nvlime.core.connection"))

(var has-fuzzy? false)
(each [_ v (ipairs opts.contribs)]
  (when (= "SWANK-FUZZY" v) (set has-fuzzy? true)))
(local +fuzzy?+ has-fuzzy?)

(fn server-has-fuzzy? [conn]
  "Check if SWANK-FUZZY is actually loaded on the server."
  (let [contribs (. conn.cb_data :contribs)]
    (and contribs (>= (vim.fn.index contribs "SWANK-FUZZY") 0))))

(vim.notify (.. "nvlime blink: MODULE LOADED, fuzzy=" (if +fuzzy?+ "yes" "no")) vim.log.levels.DEBUG)

(local flag-kind
       {:b blink-types.CompletionItemKind.Variable
        :f blink-types.CompletionItemKind.Function
        :g blink-types.CompletionItemKind.Method
        :c blink-types.CompletionItemKind.Class
        :t blink-types.CompletionItemKind.Class
        :m blink-types.CompletionItemKind.Operator
        :s blink-types.CompletionItemKind.Operator
        :p blink-types.CompletionItemKind.Module})

(local kind-precedence
       [blink-types.CompletionItemKind.Module
        blink-types.CompletionItemKind.Class
        blink-types.CompletionItemKind.Operator
        blink-types.CompletionItemKind.Method
        blink-types.CompletionItemKind.Function
        blink-types.CompletionItemKind.Variable])

;;; string -> ?number
(fn flags->kind [flags]
  (when (and flags (> (length flags) 0))
    (local kinds {})
    (for [i 1 (length flags)]
      (let [kind (. flag-kind (flags:sub i i))]
        (when kind
          (tset kinds kind true))))
    (accumulate [result nil
                 _ kind (ipairs kind-precedence)
                 &until result]
      (if (. kinds kind) kind result))))

;;; connection {any} (fn [nil]) ->
(fn set-documentation [conn item callback]
  (conn:documentation-symbol
    item.label
    (fn [_self doc-string]
      (tset item :documentation
            {:kind "markdown"
             :value (string.gsub doc-string "^Documentation for the symbol.-\n\n" "" 1)})
      (callback item))))

(fn get-lsp-kind [use-fuzzy? item]
  (if use-fuzzy?
      (let [flags (. item 4)]
        {:label (. item 1)
         :labelDetails {:detail flags}
         :kind (or (flags->kind flags)
                   blink-types.CompletionItemKind.Keyword)})
      {:label item}))


;; blink.cmp Source class
(local Source {})
(tset Source :__index Source)

(fn Source.new [_ opts]
  (local self (setmetatable {} Source))
  (tset self :opts (or opts {}))
  self)

(fn Source.enabled [self]
  (let [conn (buffer.get-conn-var! 0)]
    (not (= conn nil))))

(fn Source.get_trigger_characters [self]
  [])

(fn Source.get_completions [self ctx callback]
  (var called false)
  (let [cursor-line (. ctx.cursor 1)
        cursor-col (. ctx.cursor 2)
        keyword (or (ctx:get_keyword) "")
        start-col (- cursor-col (# keyword))
        conn (buffer.get-conn-var! 0)]
    (when conn
       (local use-fuzzy? (and +fuzzy?+ (server-has-fuzzy? conn)))
       (local completion-fn (if use-fuzzy?
                                connection.fuzzy-completions
                                connection.simple-completions))
       (local on-done (fn [_self candidates]
         (when (not called)
           (set called true)
           (let [raw-items (or (if use-fuzzy? (vim.list_slice candidates 2) candidates) [])]
             (let [items (icollect [_ c (ipairs raw-items)]
                          (let [item (get-lsp-kind use-fuzzy? c)]
                             (when item
                               (tset item :textEdit
                                     {:newText item.label
                                      :range {:start {:line (- cursor-line 1)
                                                      :character start-col}
                                              :end {:line (- cursor-line 1)
                                                    :character cursor-col}}})
                               item)))]
               (callback {:items items
                         :is_incomplete_backward false
                         :is_incomplete_forward false}))))))
      (completion-fn conn keyword on-done)))
  nil)

(fn Source.resolve [self item callback]
  (let [conn (buffer.get-conn-var! 0)]
    (set-documentation conn (vim.deepcopy item) callback)))

(tset Source "flags->kind" flags->kind)
Source
