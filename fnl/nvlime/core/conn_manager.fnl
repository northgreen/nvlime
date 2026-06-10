;;; Connection manager - global registry of Nvlime connections.
;;; NOT the Connection object itself (that's in connection.fnl).
;;; This module manages creating, retrieving, and selecting connections.

(local {: nvim_err_writeln}
       vim.api)

(local {: inputlist}
       vim.fn)

(local conn (require "nvlime.core.connection"))

;;; Module-level state

(local connections {})
(var next-conn-id 1)

;;; Module table

(local conn-manager {})

;;; Private helpers

(fn conn-manager.normalize-conn-id [id]
  "Extract numeric connection ID from either a connection object or raw ID."
  (if (= (type id) "table")
      id.cb_data.id
      id))

;;; Public API

(fn conn-manager.new [name]
  "Create a new Nvlime connection, register it, and return it.
  If name is nil, auto-generate 'nvlime-{id}'."
  (let [conn-name (or name (.. "nvlime-" next-conn-id))
        new-conn (conn.new {:id next-conn-id :name conn-name} nil)]
    (tset connections next-conn-id new-conn)
    (set next-conn-id (+ next-conn-id 1))
    new-conn))

(fn conn-manager.close [c]
  "Close and unregister a connection.
  c: connection object or numeric ID."
  (let [conn-id (conn-manager.normalize-conn-id c)
        r-conn (. connections conn-id)]
    (when r-conn
      (tset connections conn-id nil)
      (conn.close r-conn))))

(fn conn-manager.rename [conn new-name]
  "Rename a connection.
  conn: connection object or numeric ID."
  (let [conn-id (conn-manager.normalize-conn-id conn)
        r-conn (. connections conn-id)]
    (when r-conn
      (tset r-conn.cb_data :name new-name))))

(fn conn-manager.select [quiet]
  "Interactively select a connection from a numbered menu.
  Returns the selected connection, or nil if canceled/none available.
  If quiet is true, suppresses error messages."
  (if (not (next connections))
      (do
        (when (not quiet)
          (nvim_err_writeln "Nvlime not connected."))
        nil)
      (let [cur-conn vim.b.nvlime_conn
            cur-conn-id (if cur-conn cur-conn.cb_data.id -1)
            sorted-ids []]
        ;; Collect and sort connection IDs numerically
        (each [k _ (pairs connections)]
          (table.insert sorted-ids k))
        (table.sort sorted-ids)
        ;; Build display list
        (var display-names [])
        (each [_ k (ipairs sorted-ids)]
          (let [c (. connections k)]
            (var disp-name (.. k ". " c.cb_data.name
                               " (" c.channel.hostname ":"
                               c.channel.port ")"))
            (when (= cur-conn-id c.cb_data.id)
              (set disp-name (.. disp-name " *")))
            (table.insert display-names disp-name)))
        ;; Show interactive menu
        (vim.cmd "echohl Question")
        (vim.cmd "echom 'Which connection to use?'")
        (vim.cmd "echohl None")
        (let [conn-nr (inputlist display-names)]
          (if (= conn-nr 0)
              (do
                (when (not quiet)
                  (nvim_err_writeln "Canceled."))
                nil)
              (let [c (. connections conn-nr)]
                (if c
                    c
                    (do
                      (when (not quiet)
                        (nvim_err_writeln
                          (.. "Invalid connection ID: " (tostring conn-nr))))
                      nil))))))))

(fn conn-manager.get [quiet]
  "Get the connection bound to the current buffer.
  If no connection is bound or it's disconnected, auto-select the first
  available connection or prompt the user.
  If quiet is true, suppresses error messages."
  (let [buf-conn vim.b.nvlime_conn]
    (if (or (not vim.b.nvlime_conn)
            (and buf-conn (not (conn.is-connected buf-conn)))
            (and (not buf-conn) (not quiet)))
        (do
          ;; Try to auto-select first available connection
          (if (next connections)
              (do
                (var first-id nil)
                (each [k _ (pairs connections)]
                  (when (or (not first-id) (< k first-id))
                    (set first-id k)))
                (set vim.b.nvlime_conn (. connections first-id)))
              ;; No connections available - prompt user
              (let [selected (conn-manager.select quiet)]
                (if selected
                    (set vim.b.nvlime_conn selected)
                    quiet
                    (set vim.b.nvlime_conn nil)
                    ;; quiet is false and selection was canceled/failed
                    (values nil)))))
        ;; Buffer already has a valid connection - nothing to do
        )
    vim.b.nvlime_conn))

;;; Hyphen/underscore compatibility for VimScript shim
(setmetatable conn-manager
  {:__index (fn [self key]
              (. self (string.gsub key "_" "-")))})

conn-manager
