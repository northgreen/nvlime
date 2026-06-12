(local {: nvim_err_writeln
        : nvim_get_chan_info
        : nvim_buf_set_lines
        : nvim_get_option_value
        : nvim_set_option_value}
       vim.api)

(local {: sockconnect
        : chansend
        : jobstart
        : termopen
        : bufnr}
       vim.fn)

(local buffer (require "nvlime.buffer"))
(local logger (require "nvlime.logger"))

(local async {})

;;; Module-level registry: chan_id -> chan_obj
;;; Required because Neovim chan callbacks receive (chan-id data event),
;;; not a `self` parameter. We map chan_id back to the channel object.
(local chan-registry {})

;;; Internal: Max message ID (2^16)
(local max-id 65536)

;;; Internal: Increment message ID with wrap at 65536
(fn inc-msg-id [chan]
  (if (>= chan.next_msg_id max-id)
      (set chan.next_msg_id 1)
      (set chan.next_msg_id (+ chan.next_msg_id 1))))

;;; Internal: Dispatch a parsed JSON object to the appropriate callback
(fn dispatch-msg [chan json-obj]
  (let [msg-id (. json-obj 1)
        payload (. json-obj 2)]
    (when msg-id
      (let [CB (if (= msg-id 0)
                      chan.chan_callback
                      (let [cb (. chan.msg_callbacks msg-id)]
                        (tset chan.msg_callbacks msg-id nil)
                        cb))]
        (if CB
            (let [(ok err) (pcall CB chan payload)]
              (when (not ok)
                 (logger.warn (.. "callback failed: " (tostring err)))
                (nvim_err_writeln
                  (.. "nvlime: callback failed: "
                      (tostring err)))))
             (logger.warn (.. "dispatch: NO CALLBACK for msg-id=" (tostring msg-id))))))))

;;; Internal: JSON buffer parser (replaces s:ChanInputCB)
;;; Accumulates data fragments, parses complete JSON messages, dispatches
(fn chan-input-cb [chan-id data event]
  (let [chan (. chan-registry chan-id)]
    (when chan
      (var obj-list [])
      (var buffered (or chan.recv_buffer ""))
      (each [_ frag (ipairs data)]
        (let [(ok result) (pcall vim.json.decode (.. buffered frag))]
          (if ok
              (do
                (table.insert obj-list result)
                (set buffered ""))
              (set buffered (.. buffered frag)))))
      (set chan.recv_buffer buffered)
      (each [_ json-obj (ipairs obj-list)]
        (dispatch-msg chan json-obj)))))

;;; string integer ?fn ?integer -> {ch_id :hostname :port :is_connected ...}
(fn async.ch-open [host port callback timeout]
  "Open TCP channel to SWANK server.
Returns channel object. On failure ch_id is nil and is_connected is false."
  (let [chan-obj {:hostname host
                  :port port
                  :on_data chan-input-cb
                  :next_msg_id 1
                  :msg_callbacks {}}]
    (when callback
      (tset chan-obj :chan_callback callback))
    (let [(ok ch-id) (pcall sockconnect "tcp"
                              (.. host ":" (tostring port))
                              chan-obj)]
      (if ok
          (do
            (set chan-obj.ch_id ch-id)
            (set chan-obj.is_connected true)
            (tset chan-registry ch-id chan-obj))
          (do
            (set chan-obj.ch_id nil)
            (set chan-obj.is_connected false))))
    ;; Wait for channel to be ready
    (let [waittime (if timeout (+ timeout 500) 500)]
      (vim.cmd (.. "sleep " waittime "m")))
    chan-obj))

;;; {ch_id ...} any fn -> any
(fn async.ch-sendexpr [chan expr callback]
  "Send expression via channel. Registers callback for response.
Throws on channel send failure. Always uses the authoritative
channel object from chan-registry to avoid callback mismatch
when chan is a deserialized copy from nvim_buf_get_var."
  (let [real-chan (. chan-registry chan.ch_id)]
    (when (not real-chan)
      (error (.. "async.ch-sendexpr: channel " chan.ch_id " not in registry, connection may be closed")))
      (let [msg [real-chan.next_msg_id expr]]
        (when callback
          (tset real-chan.msg_callbacks real-chan.next_msg_id callback))
        (inc-msg-id real-chan)
        (let [ret (chansend real-chan.ch_id
                          (.. (vim.json.encode msg) "\n"))]
          (when (= ret 0)
            (set real-chan.is_connected false)
            (error "async.ch-sendexpr: chansend() failed"))
          ret))))

;;; [string] {buf_name callback exit_cb use_terminal} -> {job_id ...}
(fn async.job-start [cmd opts]
  "Start a job. Two modes: terminal (use_terminal=true) or buffer.
Returns job object."
  (let [buf-name opts.buf_name
        callback opts.callback
        exit-cb opts.exit_cb]
    (if opts.use_terminal
        (let [job-obj {:use_terminal true}]
          (tset job-obj :on_stdout
                (fn [job-id data event-name]
                  (when callback (callback data))))
          (tset job-obj :on_exit
                (fn [job-id exit-code event-name]
                  (when exit-cb (exit-cb exit-code))))
          (set job-obj.job_id (termopen cmd job-obj))
          (set job-obj.out_buf (bufnr "$"))
          job-obj)
         (let [buf (bufnr buf-name true)]
           (nvim_set_option_value "buftype" "nofile" {:buf buf})
           (nvim_set_option_value "bufhidden" "hide" {:buf buf})
           (nvim_set_option_value "swapfile" false {:buf buf})
           (nvim_set_option_value "buflisted" true {:buf buf})
           (nvim_set_option_value "modifiable" false {:buf buf})
           (let [job-obj {:use_terminal false
                          :out_name buf-name
                          :err_name buf-name
                          :out_buf buf
                          :err_buf buf}]
             (tset job-obj :on_stdout
                   (fn [job-id data event-name]
                     (when callback (callback data))
                     (buffer.with-modifiable buf
                       (nvim_buf_set_lines buf -1 -1 false data))))
             (tset job-obj :on_stderr
                   (fn [job-id data event-name]
                     (when callback (callback data))
                     (buffer.with-modifiable buf
                       (nvim_buf_set_lines buf -1 -1 false data))))
             (tset job-obj :on_exit
                   (fn [job-id exit-code event-name]
                     (when exit-cb (exit-cb exit-code))))
             (set job-obj.job_id (jobstart cmd job-obj))
             job-obj)))))

;;; {job_id} -> boolean
(fn async.job-is-active [job]
  "Check if job is still running."
  (let [job-info (nvim_get_chan_info job.job_id)]
    (not (vim.tbl_isempty job-info))))

;;; {out_buf} -> BufNr
(fn async.job-getbufnr [job]
  "Return output buffer number."
  (or job.out_buf 0))

;;; Hyphen/underscore compatibility for VimScript shim
(setmetatable async
  {:__index (fn [self key]
              (let [new-key (string.gsub key "_" "-")]
                (if (= new-key key)
                    nil
                    (. self new-key))))})

async
