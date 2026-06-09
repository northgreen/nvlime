;;; Channel management methods for NvlimeConnection.
;;; Mixin module - requires connection.fnl and adds channel CRUD methods.
;;; Provides local/remote channel management and channel-send message construction.

(local connection (require "nvlime.core.connection"))

;;; Connection methods

(fn connection.make-local-channel [self chan-id callback]
  "Creates a local channel entry in self.local_channels.
  Auto-assigns ID from next-local-channel-id if chan-id is nil.
  Throws error if channel already exists.
  Returns the channel object."
  (let [c-id (or chan-id self.next-local-channel-id)]
    (when (= chan-id nil)
      (set self.next-local-channel-id (+ self.next-local-channel-id 1)))
    (when (. self.local_channels c-id)
      (error (.. "nvlime#MakeLocalChannel: channel " (tostring c-id) " already exists")))
    (let [chan-obj {:id c-id :callback callback}]
      (tset self.local_channels c-id chan-obj)
      chan-obj)))

(fn connection.remove-local-channel [self chan-id]
  "Removes a local channel entry from self.local_channels.
  Returns self for chaining."
  (tset self.local_channels chan-id nil)
  self)

(fn connection.make-remote-channel [self chan-id]
  "Creates a remote channel entry in self.remote_channels.
  Does NOT send network messages - just manages local state.
  Throws error if channel already exists.
  Returns the channel object."
  (when (. self.remote_channels chan-id)
    (error (.. "nvlime#MakeRemoteChannel: channel " (tostring chan-id) " already exists")))
  (let [chan-obj {:id chan-id}]
    (tset self.remote_channels chan-id chan-obj)
    chan-obj))

(fn connection.remove-remote-channel [self chan-id]
  "Removes a remote channel entry from self.remote_channels.
  Does NOT send network messages.
  Returns self for chaining."
  (tset self.remote_channels chan-id nil)
  self)

(fn connection.emacs-channel-send [self chan-id msg]
  "Constructs an :EMACS-CHANNEL-SEND message.
  Does NOT send the message - returns the message for the caller to send.
  Returns nil if channel doesn't exist."
  (when (self:get self.remote_channels chan-id nil)
    [(connection.kw "EMACS-CHANNEL-SEND") chan-id msg]))

connection
