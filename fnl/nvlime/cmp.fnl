(local lsp-types (require "cmp.types.lsp"))
(local buffer (require "nvlime.buffer"))
(local opts (require "nvlime.config"))
(require "cmp.types.cmp")

(var has-fuzzy? false)
(each [_ v (ipairs opts.contribs)]
  (when (= "SWANK-FUZZY" v) (set has-fuzzy? true)))
(local +fuzzy?+ has-fuzzy?)

(local flag-kind
       {:b lsp-types.CompletionItemKind.Variable
        :f lsp-types.CompletionItemKind.Function
        :g lsp-types.CompletionItemKind.Method
        :c lsp-types.CompletionItemKind.Class
        :t lsp-types.CompletionItemKind.Class
        :m lsp-types.CompletionItemKind.Operator
        :s lsp-types.CompletionItemKind.Operator
        :p lsp-types.CompletionItemKind.Module})

(local kind-precedence
       [lsp-types.CompletionItemKind.Module
        lsp-types.CompletionItemKind.Class
        lsp-types.CompletionItemKind.Operator
        lsp-types.CompletionItemKind.Method
        lsp-types.CompletionItemKind.Function
        lsp-types.CompletionItemKind.Variable])

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

;;; {any} ->
(fn set-documentation [item]
  (let [get-documentation (. vim.fn "nvlime#cmp#get_docs")]
    (get-documentation
      item.label
      #(tset item :documentation
             (string.gsub $ "^Documentation for the symbol.-\n\n" "" 1)))))

(local get-lsp-kind
       (if +fuzzy?+
           (fn [item]
             (let [flags (. item 4)]
               {:label (. item 1)
                :labelDetails {:detail flags}
                :kind (or (flags->kind flags)
                          lsp-types.CompletionItemKind.Keyword)}))
           (fn [item] {:label item})))

(local get-completion
       (. vim.fn (if +fuzzy?+
                     "nvlime#cmp#get_fuzzy"
                     "nvlime#cmp#get_simple")))

(local source {})

(fn source.is_available [self]
  (not (= (buffer.get-conn-var! 0) nil)))

(fn source.get_debug_name [self]
  "CMP Nvlime")

(fn source.get_keyword_pattern [self]
  "\\k\\+")

(fn source.complete [self params callback]
  (var called false)
  (let [on-done (fn [candidates]
                  (when (not called)
                    (set called true)
                    (callback
                      (icollect [_ c (ipairs (or (. candidates 1) []))]
                        (get-lsp-kind c)))))
        input (string.sub params.context.cursor_before_line
                          params.offset)]
    (get-completion input on-done)))

(fn source.resolve [self item callback]
  (set-documentation (vim.deepcopy item))
  ;; defer_fn required for documentation to show up
  (vim.defer_fn #(callback item) 5))

source
