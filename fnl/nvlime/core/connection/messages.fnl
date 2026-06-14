;;; Message construction and communication methods for NvlimeConnection.
;;; Mixin module - requires connection.fnl and adds functions to it.

(local connection (require "nvlime.core.connection"))
(local logger (require "nvlime.logger"))

;;; Module-level helpers

(fn check-return-status [return-msg caller]
  "Validates return status is OK. Throws on failure."
  (let [status (. return-msg 2 1)]
    (when (not (= status.name "OK"))
      (let [payload (. return-msg 2)]
        (error (.. caller " returned: " (vim.inspect payload)))))))

(fn try-to-call [callback args]
  "Calls callback with args if it is a function."
  (when (= (type callback) "function")
    (callback (unpack args))))

;;; Connection methods

(fn connection.emacs-rex [self cmd]
  "Constructs an [:EMACS-REX cmd pkg thread] message.
  Uses current package and thread from UI context."
  (let [pkg-info (self:get-current-package)
        pkg (if (not= (type pkg-info) "table")
                  nil
                  (. pkg-info 1))
        thread (self:get-current-thread)
        msg [(connection.kw "EMACS-REX") cmd pkg thread]]
    (logger.debug (.. "emacs-rex: sending message=" (vim.inspect msg)))
    msg))

(fn connection.ping [self]
  "Sends PING request and validates response.
  Updates ping_tag with wrap at 65536."
  (let [cur-tag self.ping_tag]
    (set self.ping_tag (if (>= self.ping_tag 65536) 1 (+ self.ping_tag 1)))
    (let [result (self:call
                    (self:emacs-rex
                      [(connection.sym "SWANK" "PING") cur-tag]))]
      (when (and (= (type result) "string") (= (string.len result) 0))
        (error "nvlime#Ping: failed"))
      (check-return-status result "nvlime#Ping")
      (when (not= (. result 2 2) cur-tag)
        (error "nvlime#Ping: bad tag")))))

(fn connection.pong [self thread ttag]
  "Replies to server PING with [:EMACS-PONG thread ttag]."
  (self:send [(connection.kw "EMACS-PONG") thread ttag] nil))

(fn connection.connection-info [self return-dict callback]
  "Gets server connection info.
  If return-dict (default true), converts result plist to dict before callback."
  (let [return-dict (or return-dict true)
        callback (or callback nil)
        cb-wrapper (fn [chan msg]
                     (let [(ok err) (pcall check-return-status msg "nvlime#ConnectionInfo")]
                       (when (not ok)
                             (logger.warn (.. "msg: " (tostring err)))
                           (return))
                       (if return-dict
                         (try-to-call callback
                           [self (self:plist-to-dict (. msg 2 2))])
                         (try-to-call callback
                            [self (. msg 2 2)]))))]
    (self:send (self:emacs-rex
                 [(connection.sym "SWANK" "CONNECTION-INFO")])
               cb-wrapper)))

(fn connection.swank-require [self contrib callback]
  "Loads Swank contrib modules.
  contrib can be string or list of strings."
  (let [required (if (= (type contrib) "table")
                       [(connection.cl "QUOTE")
                        (vim.tbl_map
                          (fn [name] (connection.kw name))
                          contrib)]
                       (connection.kw contrib))]
    (self:send (self:emacs-rex
                 [(connection.sym "SWANK" "SWANK-REQUIRE") required])
               (fn [chan msg]
                 (self:simple-send-cb callback "nvlime#SwankRequire" chan msg)))))

(fn connection.interrupt [self thread]
  "Interrupts a thread by sending [:EMACS-INTERRUPT thread]."
  (self:send [(connection.kw "EMACS-INTERRUPT") thread] nil))

(fn connection.simple-send-cb [self callback caller chan msg]
  "Generic callback wrapper. Checks return status, calls callback with result."
  (let [status (. msg 2 1)]
    (let [(ok err) (pcall check-return-status msg caller)]
      (when (not ok)
          (logger.warn (.. "msg: " (tostring err)))
        ;; 错误情况下传空列表给回调，让补全显示为空而非完全无响应
        (try-to-call callback [self []])
        (return)))
    (try-to-call callback [self (. msg 2 2)])))

(fn connection.sldb-send-cb [self callback caller chan msg]
  "SLDB-specific callback wrapper.
  Accepts ABORT or OK status, throws on other status."
  (let [status (. msg 2 1)]
    (when (and (not= status.name "ABORT") (not= status.name "OK"))
      (let [payload (. msg 2)]
        (error (.. caller " returned: " (vim.inspect payload))))))
  (try-to-call callback [self (. msg 2 2)]))

(fn connection.plist-to-dict [self plist]
  "Converts plist (alternating key-value list) to dict.
  Uses .name of keyword symbols as dict keys."
  (if (not plist)
      {}
      (let [d {}]
        (for [i 1 (length plist) 2]
          (tset d (. plist i :name) (. plist (+ i 1))))
        d)))

(fn connection.chain-callbacks [self ...]
  "Chains async calls sequentially.
  Variadic: f1 cb1 f2 cb2 f3 cb3 ...
  Each fn receives a continuation callback.
  When cb finishes, continuation calls next fn."
  (let [cbs [...]]
    (when (< (length cbs) 1)
      (values))
    (fn chain-cb [remaining ...]
      (when (< (length remaining) 1)
        (values))
      (let [cb (. remaining 1)]
        (when cb
          (cb (fn [...]
                (when (>= (length remaining) 2)
                  (chain-cb (vim.list_slice remaining 2) ...)))))))
    (let [first-fn (. cbs 1)]
      (first-fn (fn [...]
                    (chain-cb (vim.list_slice cbs 2) ...))))))

(set connection.check-return-status check-return-status)
(set connection.try-to-call try-to-call)
connection
