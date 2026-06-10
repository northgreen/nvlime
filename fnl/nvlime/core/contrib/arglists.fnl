;;; nvlime.core.contrib.arglists --- SWANK-ARGUMENTS-SLICE contrib module
;;; Provides autodoc (argument list) support via SWANK's AUTODOC RPC.

(local connection (require "nvlime.core.connection"))

(fn connection.autodoc [self raw-form margin callback]
  "Get autodoc string for RAW-FORM with optional PRINT-RIGHT-MARGIN.
  Returns results via ASYNC callback: (callback self results)."
  (let [cmd (if (not= margin nil)
              [(connection.sym "SWANK" "AUTODOC") raw-form
               (connection.kw "PRINT-RIGHT-MARGIN") margin]
              [(connection.sym "SWANK" "AUTODOC") raw-form])]
    (self:send (self:emacs-rex cmd)
               (fn [chan msg]
                 (self:simple-send-cb callback "nvlime#contrib#arglists#Autodoc" chan msg)))))

(fn connection.init-arglists [self]
  "Register autodoc method on connection object."
  (tset self :Autodoc connection.autodoc)
  self)

connection
