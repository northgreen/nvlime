(local {: chanclose}
       vim.fn)

(local async (require "nvlime.core.async"))
(local logger (require "nvlime.logger"))

(local connection {})

;;; Symbol constructors - SWANK protocol helpers

(fn connection.sym [package name]
  "Creates a symbol dict for SWANK protocol."
  {:name name :package package})

(fn connection.kw [name]
  "Creates a keyword symbol."
  (connection.sym "KEYWORD" name))

(fn connection.cl [name]
  "Creates a COMMON-LISP symbol."
  (connection.sym "COMMON-LISP" name))

;;; Case-insensitive dict access (for *PRINT-CASE* compatibility)

(fn connection.has-key [dict key]
  "Checks if dict has key (case-insensitive)."
  (if (= (type key) "string")
      (or (. dict key) (. dict (string.upper key)) (. dict (string.lower key)))
      (. dict key)))

(fn connection.get [dict key default]
  "Gets dict value by key (case-insensitive), returns default if not found."
  (if (= (type key) "string")
      (or (. dict key) (. dict (string.upper key)) (. dict (string.lower key)) default)
      (or (. dict key) default)))

;;; Connection factory

(fn connection.new [cb_data ui]
  "Creates a new NvlimeConnection object.
  cb_data: arbitrary user data
  ui: NvlimeUI instance (or nil)"
  (let [self {:cb_data cb_data
              :channel nil
              :remote_prefix ""
              :ping_tag 1
              :next_local_channel_id 1
              :local_channels {}
              :remote_channels {}
              :ui ui
              :server_event_handlers {}}]
    ;; Load all mixin modules to register their methods on the connection module.
    ;; require is idempotent - safe to call on every new() after first load.
    (require "nvlime.core.connection.channels")
    (require "nvlime.core.connection.messages")
    (require "nvlime.core.connection.sldb")
    (require "nvlime.core.connection.inspector")
    (require "nvlime.core.connection.swank")
    (require "nvlime.core.connection.events")
    ;; Copy all methods from the connection MODULE directly onto the instance.
    ;; This ensures methods survive when metatable is lost via vim.b.* storage.
    (each [k v (pairs connection)]
      (when (= (type v) "function")
        (tset self k v)))
    ;; Still set metatable as fallback for dynamically added methods
    (setmetatable self {:__index connection})
    ;; Register all server event handlers (WRITE-STRING, DEBUG, etc.)
    (connection.setup_event_handlers self)
    self))

;;; Core connection methods

(fn connection.connect [self host port prefix timeout]
  "Opens TCP connection to SWANK server.
  Throws on failure."
  (let [callback (fn [chan msg] (self:on-server-event chan msg))]
    (set self.channel (async.ch-open host port callback timeout)))
  (when (not self.channel.is_connected)
    (self:close)
    (error "nvlime#Connect: failed to open channel"))
  (set self.remote_prefix (or prefix ""))
  self)

(fn connection.close [self]
  "Closes the connection channel."
  (when (and self.channel self.channel.ch_id)
    (pcall chanclose self.channel.ch_id)
    (set self.channel nil))
  self)

(fn connection.is-connected [self]
  "Checks if channel is connected."
  (and self.channel self.channel.is_connected))

(fn connection.call [self msg]
  "Synchronous send - returns result directly.
  Uses vim.fn.ch_evalexpr as placeholder until async.fnl adds ch-evalexpr."
  (let [encoded (vim.json.encode msg)
        (ok result) (pcall vim.fn.ch_evalexpr self.channel.ch_id encoded)]
    (if ok result
        (error (.. "nvlime#Call: " (tostring result))))))

(fn connection.send [self msg callback]
  "Asynchronous send via channel."
  (async.ch-sendexpr self.channel msg callback))

;;; Path fixing - remote/local path conversion

(fn connection.fix-remote-path [self path]
  "Prepends remote_prefix to path.
  Handles both plain strings and Swank LOCATION objects."
  (let [prefix (or self.remote_prefix "")]
    (if (= (string.len prefix) 0)
        path
        (match (type path)
          "string" (.. prefix path)
          "table"  (let [loc-data (. path 2)]
                     (if loc-data
                         (let [loc-type (. loc-data 1)]
                           (when (= loc-type "FILE")
                             (tset loc-data 2 (.. prefix (. loc-data 2))))
                           (when (= loc-type "BUFFER-AND-FILE")
                             (tset loc-data 3 (.. prefix (. loc-data 3))))
                           path)
                         (error (.. "nvlime#FixRemotePath: unknown path: " (tostring path)))))
          _ (error (.. "nvlime#FixRemotePath: unknown path: " (tostring path)))))))

(fn connection.fix-local-path [self path]
  "Strips remote_prefix from path.
  Returns path unchanged if not a string or prefix not present."
  (if (not (= (type path) "string"))
      path
      (let [prefix (or self.remote_prefix "")
            prefix-len (string.len prefix)]
        (if (and (> prefix-len 0)
                 (= (string.sub path 1 prefix-len) prefix))
            (string.sub path (+ prefix-len 1))
            path))))

;;; Context methods - delegate to UI

(fn connection.get-current-package [self]
  "Returns the current Common Lisp package bound to the buffer.
   Falls back to CL-USER when no UI is attached."
  (if self.ui
      (self.ui:get-current-package)
       ;; Default package when no UI context - matches SWANK's default behavior
       ["COMMON-LISP-USER" "CL-USER"]))

(fn connection.set-current-package [self package]
  "Binds a Common Lisp package to the current buffer."
  (when self.ui (self.ui:set-current-package package)))

(fn connection.get-current-thread [self]
  "Returns the thread bound to the current buffer.
  Returns true (not nil) when no UI is present - matches original behavior."
  (if self.ui (self.ui:get-current-thread) true))

(fn connection.set-current-thread [self thread]
  "Binds a thread to the current buffer."
  (when self.ui (self.ui:set-current-thread thread)))

(fn connection.with-thread [self thread func]
  "Temporarily sets thread, runs func, restores original thread."
  (let [old-thread (self:get-current-thread)]
    (self:set-current-thread thread)
    (let [result (func)]
      (self:set-current-thread old-thread)
      result)))

(fn connection.with-package [self package func]
  "Temporarily sets package, runs func, restores original package."
  (let [old-package (self:get-current-package)]
    (self:set-current-package [package package])
    (let [result (func)]
      (self:set-current-package old-package)
      result)))

;;; VimScript shim dispatcher

(fn connection._call [conn-ref method-name args]
  "Generic method dispatcher for VimScript shim.
  Loads all mixin modules and converts PascalCase method names to kebab-case."
  ;; Ensure all mixin modules are loaded (idempotent require)
  (require "nvlime.core.connection.channels")
  (require "nvlime.core.connection.messages")
  (require "nvlime.core.connection.sldb")
  (require "nvlime.core.connection.inspector")
  (require "nvlime.core.connection.swank")
  (require "nvlime.core.connection.events")
  (let [name (string.gsub method-name "([a-z%d])([A-Z])" "%1-%2")]
    (let [name (string.gsub name "([A-Z]+)([A-Z][a-z])" "%1-%2")]
      (let [kebab-name (string.lower name)]
        (let [method (. connection kebab-name)]
          (when method
            (method conn-ref (unpack args))))))))

;;; Event routing

(fn connection.on-server-event [self chan msg]
  "Routes server events to appropriate handlers.
  First element of msg is the symbol dict identifying the event type."
  (logger.debug (.. "on-server-event: received msg len=" (tostring (length msg))))
  (let [msg-type (. msg 1)]
    (when msg-type
      (let [event-name (if (= (type msg-type) "table")
                           msg-type.name
                           (and (= (type msg-type) "string") msg-type))
            handler (. self.server_event_handlers event-name)]
        (logger.debug (.. "on-server-event: msg-type-type=" (tostring (type msg-type)) " event-name=" (tostring event-name)))
        (when (= (type handler) "function")
          (logger.debug (.. "on-server-event: HANDLER FOUND for " (tostring event-name)))
          (handler self msg))
        (when (and (not handler) event-name)
          (logger.warn (.. "on-server-event: NO HANDLER for event=" (tostring event-name))))))))

connection
