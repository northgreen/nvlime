(local blink-types (require "blink.cmp.types"))
(local buffer (require "nvlime.buffer"))
(local opts (require "nvlime.config"))

(var has-fuzzy? false)
(each [_ v (ipairs opts.contribs)]
  (when (= "SWANK-FUZZY" v) (set has-fuzzy? true)))
(local +fuzzy?+ has-fuzzy?)

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
    (each [_ kind (ipairs kind-precedence)]
      (when (. kinds kind)
        (values kind)))))

;;; {any} (fn [nil]) ->
(fn set-documentation [item callback]
  (let [get-documentation (. vim.fn "nvlime#cmp#get_docs")]
    (get-documentation
      item.label
      #(do
         (tset item :documentation
               {:kind "markdown"
                :value (string.gsub $ "^Documentation for the symbol.-\n\n" "" 1)})
         (callback item)))))

(local get-lsp-kind
       (if +fuzzy?+
           (fn [item]
             (let [flags (. item 4)]
               {:label (. item 1)
                :labelDetails {:detail flags}
                :kind (or (flags->kind flags)
                          blink-types.CompletionItemKind.Keyword)}))
           (fn [item]
             {:label item})))

(local get-completion
       (. vim.fn (if +fuzzy?+
                     "nvlime#cmp#get_fuzzy"
                     "nvlime#cmp#get_simple")))

;; blink.cmp Source class
(local Source {:__index Source})

(fn Source.new [_ opts]
  (local self (setmetatable {} Source))
  (tset self :opts (or opts {}))
  self)

(fn Source.enabled [self]
  (let [conn (buffer.get-conn-var! 0)]
    (not (= conn nil))))

(fn Source.get_trigger_characters [self]
  [":"])

(fn Source.get_completions [self ctx callback]
  (var called false)
  (let [cursor-line (. ctx.cursor 1)
        cursor-col (. ctx.cursor 2)
        keyword (or ctx.keyword "")
        start-col (- cursor-col (# keyword))]
    (local on-done (fn [candidates]
      (when (not called)
        (set called true)
        (local items [])
        (each [_ c (ipairs (or candidates []))]
          (let [item (get-lsp-kind c)]
            (when item
              (tset item :textEdit
                    {:newText item.label
                     :range {:start {:line (- cursor-line 1)
                                     :character start-col}
                             :end {:line (- cursor-line 1)
                                   :character cursor-col}}})
               (table.insert items item)))))
        (callback {:items items
                   :is_incomplete_backward false
                   :is_incomplete_forward false})))
    (get-completion keyword on-done)
    nil))

(fn Source.resolve [self item callback]
  (set-documentation (vim.deepcopy item) callback))

(tset Source "flags->kind" flags->kind)
Source
