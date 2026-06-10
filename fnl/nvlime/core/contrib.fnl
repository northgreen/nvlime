;;; nvlime.core.contrib --- Contrib registration center
;;; Maps contrib names to their Init functions and provides call-initializers.

(local connection (require "nvlime.core.connection"))

;;; Ensure all contrib modules are loaded (mixin pattern - each adds methods to connection)
;;; Use pcall for modules that may not be migrated to Fennel yet
(local repl (require "nvlime.core.contrib.repl"))
(local presentations (require "nvlime.core.contrib.presentations"))
(local presentation-streams (require "nvlime.core.contrib.presentation-streams"))
(local fuzzy (require "nvlime.core.contrib.fuzzy"))
(local arglists (require "nvlime.core.contrib.arglists"))

(local mrepl (let [(ok mod) (pcall require "nvlime.core.contrib.mrepl")]
               (if ok mod nil)))
(local trace-dialog (let [(ok mod) (pcall require "nvlime.core.contrib.trace-dialog")]
                      (if ok mod nil)))

;;; Contrib name -> Init function mapping
(local contrib-initializers
  {"SWANK-REPL" repl.init-repl
   "SWANK-PRESENTATIONS" presentations.init-presentations
   "SWANK-PRESENTATION-STREAMS" presentation-streams.init-presentation-streams
   "SWANK-FUZZY" fuzzy.init-fuzzy
   "SWANK-ARGLISTS" arglists.init-arglists})

;; Add optional contribs if modules are available
(when mrepl (tset contrib-initializers "SWANK-MREPL" mrepl.init-mrepl))
(when trace-dialog (tset contrib-initializers "SWANK-TRACE-DIALOG" trace-dialog.init-trace-dialog))

(fn connection.call-initializers [self &optional contribs callback]
  "Iterates over CONTRIBS list and calls the appropriate init function for each.
   If CONTRIBS is nil, uses self.cb_data.contribs.
   Calls CALLBACK(self) after all initializers complete."
  (let [contribs (or contribs (. self.cb_data :contribs) [])]
    (for [_ contrib (ipairs contribs)]
      (let [init-fn (. contrib-initializers contrib)]
        (when init-fn
          (init-fn self)))))
  (when (= (type callback) "function")
    (callback self))
  self)

connection
