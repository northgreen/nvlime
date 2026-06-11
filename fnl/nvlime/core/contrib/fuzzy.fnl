;;; nvlime.core.contrib.fuzzy --- SWANK-FUZZY contrib module
;;; Provides fuzzy completion support via SWANK's FUZZY-COMPLETIONS RPC.

(local connection (require "nvlime.core.connection"))

(fn connection.fuzzy-completions [self symbol callback]
  "Get fuzzy completion list for SYMBOL in the current package.
  Returns results via ASYNC callback: (callback self results)."
  (let [cur-package (let [pkg-info (connection.get-current-package self)]
                      (if pkg-info
                          (. pkg-info 1)
                          nil))]
    (connection.send self (connection.emacs-rex self
                 [(connection.sym "SWANK" "FUZZY-COMPLETIONS") symbol cur-package])
                 (fn [chan msg]
                   (connection.simple-send-cb self callback "nvlime#contrib#fuzzy#FuzzyCompletions" chan msg)))))


(fn connection.init-fuzzy [self]
  "Register fuzzy completion method on connection object."
  (tset self :FuzzyCompletions connection.fuzzy-completions)
  self)

connection
