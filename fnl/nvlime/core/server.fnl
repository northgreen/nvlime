;;; nvlime.core.server --- Lisp server management
;;; Migrated from autoload/nvlime/server.vim

(local {: nvim_buf_set_name
        : nvim_buf_set_var}
       vim.api)

(local {: bufnr
        : bufname
        : jobstop
        : inputlist
        : input
        : matchlist
        : search
        : getline
        : cursor
        : getcurpos
        : setpos
        : exists}
       vim.fn)

(local async (require "nvlime.core.async"))
(local ui (require "nvlime.core.ui"))

(local server {})

;;; ============================================================================
;;; Module-level state (global variables)
;;; ============================================================================

(when (not (pcall (fn [] vim.g.nvlime_cl_wait_interval)))
  (tset vim.g :nvlime_cl_wait_interval 500))

(when (not (pcall (fn [] vim.g.nvlime_servers)))
  (tset vim.g :nvlime_servers {}))

(when (not (pcall (fn [] vim.g.nvlime_next_server_id)))
  (tset vim.g :nvlime_next_server_id 1))

;;; ============================================================================
;;; Path computation (at module load time)
;;; ============================================================================

;; nvlime_home: project root directory
;; Derived from first runtimepath entry (points to nvlime plugin dir)
(local nvlime-home
  (let [rtp vim.o.runtimepath]
    (if (> (length rtp) 0)
        (let [first-entry (vim.split rtp "," {:trimempty true})]
          (. first-entry 1))
        (vim.fn.getcwd))))

;; Path separator: "/" works cross-platform in Neovim
(local path-sep "/")

;;; ============================================================================
;;; Builder functions (defined before server.new since fn is not hoisted)
;;; ============================================================================

(fn server.build-server-command-for-sbcl [loader eval-str]
  "Build SBCL server command."
  ["sbcl" "--load" loader "--eval" eval-str])

(fn server.build-server-command-for-ccl [loader eval-str]
  "Build CCL server command."
  ["ccl" "--load" loader "--eval" eval-str])

(fn server.build-server-command [cl-impl]
  "Generate SBCL/CCL server startup command.
  Checks for user-defined builder first (NvlimeBuildServerCommandFor_<impl>),
  then falls back to default builder.
  Throws if implementation is not supported."
  (let [cl-impl (or cl-impl
                    (. vim.g :nvlime_options :implementation))
        nvlime-loader (.. nvlime-home path-sep "lisp" path-sep "load-nvlime.lisp")]

    (cond
      ;; User-defined VimScript builder exists
      ((> (exists (.. "*" "NvlimeBuildServerCommandFor_" cl-impl)) 0)
       (let [user-func-name (.. "NvlimeBuildServerCommandFor_" cl-impl)
             Builder ((. vim.fn user-func-name))]
         (Builder nvlime-loader "(nvlime:main)")))

      ;; Default builders — call Fennel functions directly
      (= cl-impl "sbcl")
      (server.build-server-command-for-sbcl nvlime-loader "(nvlime:main)")

      (= cl-impl "ccl")
      (server.build-server-command-for-ccl nvlime-loader "(nvlime:main)")

      ;; No builder found
      :else
      (error (.. "nvlime.core.server.build-server-command: implementation "
                 ((. vim.fn "string") cl-impl) " not supported")))))

;;; ============================================================================
;;; Private helpers
;;; ============================================================================

(fn normalize-server-id [id]
  "Extract numeric server ID from dict or raw ID."
  (if (= (type id) "table")
      id.id
      id))

(fn match-server-created-port []
  "Search buffer for 'Server created' line and extract port number.
  Returns port as number, or nil if not found."
  (var port-line-nr 0)
  (let [old-pos (getcurpos)
        pattern "Server created: (#([[:digit:][:blank:]]\\+)\\s\\+\\(\\d\\+\\))"]
    ;; Move cursor to line 1 and search (result captured in port-line-nr)
    (pcall (fn []
             (cursor [1 1 0 1])
             (set port-line-nr (search pattern "n"))))
    ;; Always restore cursor position
    (setpos "." old-pos)
    ;; Extract port from matched line
    (if (> port-line-nr 0)
        (let [port-line (getline port-line-nr)
              matched (matchlist port-line pattern)]
          (tonumber (. matched 1)))
        nil)))

(fn server-output-cb [server-obj auto-connect data]
  "Callback for server job stdout.
  Parses 'Server created' messages to extract port number.
  If auto-connect is true, connects to the REPL automatically."
  ;; Guard: skip if port already discovered
  (when (> (or server-obj.port 0) 0)
    (values))

  (each [_ line (ipairs data)]
    (let [matched (matchlist line "Server created: (#([[:digit:][:blank:]]\\+)\\s\\+\\(\\d\\+\\))")]
      (when (> (length matched) 0)
        (let [port (tonumber (. matched 1))]
          (tset server-obj :port port)
          (vim.cmd (.. "echom 'Nvlime server listening on port " port "'"))

          ;; Auto-connect if requested
          (when auto-connect
            (let [auto-conn ((. vim.fn "nvlime#plugin#ConnectREPL") "127.0.0.1" port)]
              (when auto-conn
                (tset (. auto-conn :cb_data) :server server-obj)
                (tset server-obj :connections
                      {[(. auto-conn :cb_data :id)] auto-conn}))))

        (values)))))

(fn server-exit-cb [server-obj exit-status]
  "Callback for server job exit.
  Removes server from registry and closes all connections."
  (tset vim.g.nvlime_servers server-obj.id nil)
  (vim.cmd (.. "echom '" server-obj.name " stopped.'"))

  (let [conn-dict (or server-obj.connections {})
        conn-manager (require "nvlime.core.conn_manager")]
    (each [conn-id conn (pairs conn-dict)]
      (conn-manager.close conn))
    (tset server-obj :connections {})))

;;; ============================================================================
;;; Public API
;;; ============================================================================

(fn server.new [auto-connect use-terminal name cl-impl]
  "Create a new Lisp server.
  auto-connect: automatically connect REPL when server is ready (default: true)
  use-terminal: use terminal buffer for server output (default: false)
  name: server display name (default: auto-generated)
  cl-impl: Common Lisp implementation (default: from g:nvlime_options)
  Returns server object."
  (let [auto-connect (or auto-connect true)
        use-terminal (or use-terminal false)
        server-name (or name
                        (.. "nvlime server " vim.g.nvlime_next_server_id))
        server-id vim.g.nvlime_next_server_id]

     ;; Open server window, get [window-id bufnr]
    (let [[_win bufnr] ((. vim.fn "luaeval")
                         "require('nvlime.window.server').open(_A)"
                         server-name)

          server-obj {:id server-id
                      :name server-name
                      :auto_connect auto-connect
                      :use_terminal use-terminal
                      :cl_impl cl-impl}

          server-job (async.job-start
                       (server.build-server-command cl-impl)
                       {:buf_name (bufname bufnr)
                        :callback (fn [data]
                                    (server-output-cb server-obj auto-connect data))
                        :exit_cb (fn [exit-status]
                                   (server-exit-cb server-obj exit-status))
                        :use_terminal use-terminal})]

      ;; Fail fast: job must be active
      (when (not (async.job-is-active server-job))
        ((. vim.fn "luaeval")
         "require('nvlime.buffer')['fill!'](_A[1], _A[2])"
         [bufnr "Failed to start server."])
        (error "nvlime.core.server.new: failed to start server job"))

      ;; Store job and register server
      (tset server-obj :job server-job)
      (tset vim.g.nvlime_servers server-id server-obj)
      (tset vim.g :nvlime_next_server_id (+ server-id 1))

      ;; Bind server object to buffer
      (let [server-buf (async.job-getbufnr server-job)]
        (nvim_buf_set_var server-buf "nvlime_server" server-obj))

      server-obj)))

(fn server.stop [server]
  "Stop a running server and close its buffer."
  (let [server-id (normalize-server-id server)
        r-server (. vim.g.nvlime_servers server-id)]
    (jobstop (. r-server.job :job_id))
    (let [buf (async.job-getbufnr r-server.job)]
      (ui.close-buffer buf))))

(fn server.rename [server new-name]
  "Rename a server and update its buffer name."
  (let [server-id (normalize-server-id server)
        r-server (. vim.g.nvlime_servers server-id)
        old-buf-name (ui.server-buf-name r-server.name)]
    (tset r-server :name new-name)
    (let [old-buf (bufnr old-buf-name)]
      (when (> old-buf 0)
        (nvim_buf_set_name old-buf (ui.server-buf-name new-name))))))

(fn server.show [server]
  "Show the server output window."
  (let [server-id (normalize-server-id server)
        r-server (. vim.g.nvlime_servers server-id)]
    ((. vim.fn "luaeval")
     "require('nvlime.window.server').open(_A)"
     r-server.name)))

(fn server.select []
  "Interactively select a server from the registry.
  Returns selected server object, or nil if canceled/invalid."
  (when (= (length vim.g.nvlime_servers) 0)
    (ui.err-msg "No server started.")
    (values nil))

  ;; Build numbered list of servers
  (let [server-names []]
    (each [k _ (pairs (vim.fn.sort (vim.fn.keys vim.g.nvlime_servers) "n"))]
      (let [server (. vim.g.nvlime_servers k)
            port (or server.port 0)]
        (table.insert server-names
                      (.. k ". " server.name " (" port ")"))))

    ;; Prompt user
    (vim.cmd "echohl Question")
    (vim.cmd "echom 'Select server:'")
    (vim.cmd "echohl None")

    (let [server-nr (inputlist server-names)]
      (if (= server-nr 0)
          (do
            (ui.err-msg "Canceled.")
            nil)
          (let [server (. vim.g.nvlime_servers server-nr)]
            (if (not server)
                (do
                  (ui.err-msg (.. "Invalid server ID: " server-nr))
                  nil)
                server))))))

(fn server.connect-to-cur-server []
  "Connect current buffer's server to REPL."
  (var port nil)
  (if (async.job-is-active (. vim.b :nvlime_server :job))
      (do
        (set port (or (. vim.b :nvlime_server :port) nil))
        (when (not port)
          (ui.err-msg (.. (. vim.b :nvlime_server :name) " is not ready."))))
      (ui.err-msg (.. (. vim.b :nvlime_server :name) " is not running.")))

  (when (not port)
    (values))

  (let [conn ((. vim.fn "nvlime#plugin#ConnectREPL") "127.0.0.1" port)]
    (when conn
      (tset (. conn :cb_data) :server (. vim.b :nvlime_server))
      (let [conn-list (or (. vim.b :nvlime_server :connections) {})]
        (tset conn-list (. conn :cb_data :id) conn)
        (tset (. vim.b :nvlime_server) :connections conn-list)))))

(fn server.stop-cur-server []
  "Stop current buffer's server with confirmation prompt."
  (when (not (. vim.g.nvlime_servers (. vim.b :nvlime_server :id)))
    (ui.err-msg (.. (. vim.b :nvlime_server :name) " is not running."))
    (values))

  (let [answer (input (.. "Stop server "
                          ((. vim.fn "string") (. vim.b :nvlime_server :name))
                          "? (y/n) "))]
    (if (ui.is-yes-string answer)
        (server.stop (. vim.b :nvlime_server))
         (ui.err-msg "Canceled.")))))

;;; Hyphen/underscore compatibility for VimScript shim
(setmetatable server
  {:__index (fn [self key]
              (. self (string.gsub key "_" "-")))})

server
