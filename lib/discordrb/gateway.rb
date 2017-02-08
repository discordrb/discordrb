# This file uses code from Websocket::Client::Simple, licensed under the following license:
#
# Copyright (c) 2013-2014 Sho Hashimoto
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
#                                  distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'thread'

module Discordrb
  # Gateway packet opcodes
  module Opcodes
    # **Received** when Discord dispatches an event to the gateway (like MESSAGE_CREATE, PRESENCE_UPDATE or whatever).
    # The vast majority of received packets will have this opcode.
    DISPATCH = 0

    # **Two-way**: The client has to send a packet with this opcode every ~40 seconds (actual interval specified in
    # READY or RESUMED) and the current sequence number, otherwise it will be disconnected from the gateway. In certain
    # cases Discord may also send one, specifically if two clients are connected at once.
    HEARTBEAT = 1

    # **Sent**: This is one of the two possible ways to initiate a session after connecting to the gateway. It
    # should contain the authentication token along with other stuff the server has to know right from the start, such
    # as large_threshold and, for older gateway versions, the desired version.
    IDENTIFY = 2

    # **Sent**: Packets with this opcode are used to change the user's status and played game. (Sending this is never
    # necessary for a gateway client to behave correctly)
    PRESENCE = 3

    # **Sent**: Packets with this opcode are used to change a user's voice state (mute/deaf/unmute/undeaf/etc.). It is
    # also used to connect to a voice server in the first place. (Sending this is never necessary for a gateway client
    # to behave correctly)
    VOICE_STATE = 4

    # **Sent**: This opcode is used to ping a voice server, whatever that means. The functionality of this opcode isn't
    # known well but non-user clients should never send it.
    VOICE_PING = 5

    # **Sent**: This is the other of two possible ways to initiate a gateway session (other than {IDENTIFY}). Rather
    # than starting an entirely new session, it resumes an existing session by replaying all events from a given
    # sequence number. It should be used to recover from a connection error or anything like that when the session is
    # still valid - sending this with an invalid session will cause an error to occur.
    RESUME = 6

    # **Received**: Discord sends this opcode to indicate that the client should reconnect to a different gateway
    # server because the old one is currently being decommissioned. Counterintuitively, this opcode also invalidates the
    # session - the client has to create an entirely new session with the new gateway instead of resuming the old one.
    RECONNECT = 7

    # **Sent**: This opcode identifies packets used to retrieve a list of members from a particular server. There is
    # also a REST endpoint available for this, but it is inconvenient to use because the client has to implement
    # pagination itself, whereas sending this opcode lets Discord handle the pagination and the client can just add
    # members when it receives them. (Sending this is never necessary for a gateway client to behave correctly)
    REQUEST_MEMBERS = 8

    # **Received**: Sent by Discord when the session becomes invalid for any reason. This may include improperly
    # resuming existing sessions, attempting to start sessions with invalid data, or something else entirely. The client
    # should handle this by simply starting a new session.
    INVALIDATE_SESSION = 9

    # **Received**: Sent immediately for any opened connection; tells the client to start heartbeating early on, so the
    # server can safely search for a session server to handle the connection without the connection being terminated.
    # As a side-effect, large bots are less likely to disconnect because of very large READY parse times.
    HELLO = 10

    # **Received**: Returned after a heartbeat was sent to the server. This allows clients to identify and deal with
    # zombie connections that don't dispatch any events anymore.
    HEARTBEAT_ACK = 11
  end

  # This class stores the data of an active gateway session. Note that this is different from a websocket connection -
  # there may be multiple sessions per connection or one session may persist over multiple connections.
  class Session
    attr_reader :session_id
    attr_accessor :sequence

    def initialize(session_id)
      @session_id = session_id
      @sequence = 0
      @suspended = false
      @invalid = false
    end

    def suspend
      @suspended = true
    end

    def suspended?
      @suspended
    end

    def resume
      @suspended = false
    end

    def invalidate
      @invalid = true
    end

    def invalid?
      @invalid
    end

    def should_resume?
      suspended? && !invalid?
    end
  end

  # Client for the Discord gateway protocol
  class Gateway
    # How many members there need to be in a server for it to count as "large"
    LARGE_THRESHOLD = 100

    # The version of the gateway that's supposed to be used.
    GATEWAY_VERSION = 6

    # Heartbeat ACKs are Discord's way of verifying on the client side whether the connection is still alive. If this is
    # set to true (default value) the gateway client will use that functionality to detect zombie connections and
    # reconnect in such a case; however it may lead to instability if there's some problem with the ACKs. If this occurs
    # it can simply be set to false.
    # @return [true, false] whether or not this gateway should check for heartbeat ACKs.
    attr_accessor :check_heartbeat_acks

    def initialize(bot, token, shard_key = nil)
      @token = token
      @bot = bot

      @shard_key = shard_key

      @getc_mutex = Mutex.new

      # Whether the connection to the gateway has succeeded yet
      @ws_success = false

      @check_heartbeat_acks = true
    end

    # Connect to the gateway server in a separate thread
    def run_async
      @ws_thread = Thread.new do
        Thread.current[:discordrb_name] = 'websocket'
        connect_loop
        LOGGER.warn('The WS loop exited! Not sure if this is a good thing')
      end

      LOGGER.debug('WS thread created! Now waiting for confirmation that everything worked')
      sleep(0.5) until @ws_success
      LOGGER.debug('Confirmation received! Exiting run.')
    end

    # Prevents all further execution until the websocket thread stops (e. g. through a closed connection).
    def sync
      @ws_thread.join
    end

    # Whether the WebSocket connection to the gateway is currently open
    def open?
      @handshake && @handshake.finished? && !@closed
    end

    # Stops the bot gracefully, disconnecting the websocket without immediately killing the thread. This means that
    # Discord is immediately aware of the closed connection and makes the bot appear offline instantly.
    #
    # If this method doesn't work or you're looking for something more drastic, use {#kill} instead.
    def stop(no_sync = false)
      @should_reconnect = false
      close(no_sync)

      # Return nil so command bots don't send a message
      nil
    end

    # Kills the websocket thread, stopping all connections to Discord.
    def kill
      @ws_thread.kill
    end

    # Notifies the {#run_async} method that everything is ready and the caller can now continue (i.e. with syncing,
    # or with doing processing and then syncing)
    def notify_ready
      @ws_success = true
    end

    # Injects a reconnect event (op 7) into the event processor, causing Discord to reconnect to the given gateway URL.
    # If the URL is set to nil, it will reconnect and get an entirely new gateway URL. This method has not much use
    # outside of testing and implementing highly custom reconnect logic.
    # @param url [String, nil] the URL to connect to or nil if one should be obtained from Discord.
    def inject_reconnect(url = nil)
      # When no URL is specified, the data should be nil, as is the case with Discord-sent packets.
      data = url ? { url: url } : nil

      handle_message({
        op: Opcodes::RECONNECT,
        d: data
      }.to_json)
    end

    # Injects a resume packet (op 6) into the gateway. If this is done with a running connection, it will cause an
    # error. It has no use outside of testing stuff that I know of, but if you want to use it anyway for some reason,
    # here it is.
    # @param seq [Integer, nil] The sequence ID to inject, or nil if the currently tracked one should be used.
    def inject_resume(seq)
      send_resume(raw_token, @session_id, seq || @sequence)
    end

    # Injects a terminal gateway error into the handler. Useful for testing the reconnect logic.
    # @param e [Exception] The exception object to inject.
    def inject_error(e)
      handle_internal_close(e)
    end

    # Sends a heartbeat with the last received packet's seq (to acknowledge that we have received it and all packets
    # before it), or if none have been received yet, with 0.
    # @see #send_heartbeat
    def heartbeat
      if check_heartbeat_acks
        unless @last_heartbeat_acked
          # We're in a bad situation - apparently the last heartbeat wasn't acked, which means the connection is likely
          # a zombie. Reconnect
          LOGGER.warn('Last heartbeat was not acked, so this is a zombie connection! Reconnecting')

          # We can't send anything on zombie connections
          @pipe_broken = true
          reconnect
          return
        end

        @last_heartbeat_acked = false
      end

      send_heartbeat(@session ? @session.sequence : 0)
    end

    # Sends a heartbeat packet (op 1). This tells Discord that the current connection is still active and that the last
    # packets until the given sequence have been processed (in case of a resume).
    # @param sequence [Integer] The sequence number for which to send a heartbeat.
    def send_heartbeat(sequence)
      send_packet(Opcodes::HEARTBEAT, sequence)
    end

    # Identifies to Discord with the default parameters.
    # @see #send_identify
    def identify
      send_identify(@token, {
                      :'$os' => RUBY_PLATFORM,
                      :'$browser' => 'discordrb',
                      :'$device' => 'discordrb',
                      :'$referrer' => '',
                      :'$referring_domain' => ''
                    }, true, 100, @shard_key)
    end

    # Sends an identify packet (op 2). This starts a new session on the current connection and tells Discord who we are.
    # This can only be done once a connection.
    # @param token [String] The token with which to authorise the session. If it belongs to a bot account, it must be
    #   prefixed with "Bot ".
    # @param properties [Hash<Symbol => String>] A list of properties for Discord to use in analytics. The following
    #   keys are recognised:
    #
    #    - "$os" (recommended value: the operating system the bot is running on)
    #    - "$browser" (recommended value: library name)
    #    - "$device" (recommended value: library name)
    #    - "$referrer" (recommended value: empty)
    #    - "$referring_domain" (recommended value: empty)
    #
    # @param compress [true, false] Whether certain large packets should be compressed using zlib.
    # @param large_threshold [Integer] The member threshold after which a server counts as large and will have to have
    #   its member list chunked.
    # @param shard_key [Array(Integer, Integer), nil] The shard key to use for sharding, represented as
    #   [shard_id, num_shards], or nil if the bot should not be sharded.
    def send_identify(token, properties, compress, large_threshold, shard_key = nil)
      data = {
        # Don't send a v anymore as it's entirely determined by the URL now
        token: token,
        properties: properties,
        compress: compress,
        large_threshold: large_threshold
      }

      # Don't include the shard key at all if it is nil as Discord checks for its mere existence
      data[:shard] = shard_key if shard_key

      send_packet(Opcodes::IDENTIFY, data)
    end

    # Sends a status update packet (op 3). This sets the bot user's status (online/idle/...) and game playing/streaming.
    # @param status [String] The status that should be set (`online`, `idle`, `dnd`, `invisible`).
    # @param since [Integer] The unix timestamp in milliseconds when the status was set. Should only be provided when
    #   `afk` is true.
    # @param game [Hash<Symbol => Object>, nil] `nil` if no game should be played, or a hash of `:game => "name"` if a
    #   game should be played. The hash can also contain additional attributes for streaming statuses.
    # @param afk [true, false] Whether the status was set due to inactivity on the user's part.
    def send_status_update(status, since, game, afk)
      data = {
        status: status,
        since: since,
        game: game,
        afk: afk
      }

      send_packet(Opcodes::PRESENCE, data)
    end

    # Sends a voice state update packet (op 4). This packet can connect a user to a voice channel, update self mute/deaf
    # status in an existing voice connection, move the user to a new voice channel on the same server or disconnect an
    # existing voice connection.
    # @param server_id [Integer] The ID of the server on which this action should occur.
    # @param channel_id [Integer, nil] The channel ID to connect/move to, or `nil` to disconnect.
    # @param self_mute [true, false] Whether the user should itself be muted to everyone else.
    # @param self_deaf [true, false] Whether the user should be deaf towards other users.
    def send_voice_state_update(server_id, channel_id, self_mute, self_deaf)
      data = {
        guild_id: server_id,
        channel_id: channel_id,
        self_mute: self_mute,
        self_deaf: self_deaf
      }

      send_packet(Opcodes::VOICE_STATE, data)
    end

    # Resumes the session from the last recorded point.
    # @see #send_resume
    def resume
      send_resume(@token, @session.session_id, @session.sequence)
    end

    # Reconnects the gateway connection in a controlled manner.
    # @param attempt_resume [true, false] Whether a resume should be attempted after the reconnection.
    def reconnect(attempt_resume = true)
      @session.suspend if attempt_resume

      @instant_reconnect = true
      @should_reconnect = true

      close
    end

    # Sends a resume packet (op 6). This replays all events from a previous point specified by its packet sequence. This
    # will not work if the packet to resume from has already been acknowledged using a heartbeat, or if the session ID
    # belongs to a now invalid session.
    #
    # If this packet is sent at the beginning of a connection, it will act similarly to an {#identify} in that it
    # creates a session on the current connection. Unlike identify however, this packet can also be sent in an existing
    # session and will just replay some of the events.
    # @param token [String] The token that was used to identify the session to resume.
    # @param session_id [String] The session ID of the session to resume.
    # @param seq [Integer] The packet sequence of the packet after which the events should be replayed.
    def send_resume(token, session_id, seq)
      data = {
        token: token,
        session_id: session_id,
        seq: seq
      }

      send_packet(Opcodes::RESUME, data)
    end

    # Sends a request members packet (op 8). This will order Discord to gradually sent all requested members as dispatch
    # events with type `GUILD_MEMBERS_CHUNK`. It is necessary to use this method in order to get all members of a large
    # server (see `large_threshold` in {#send_identify}), however it can also be used for other purposes.
    # @param server_id [Integer] The ID of the server whose members to query.
    # @param query [String] If this string is not empty, only members whose username starts with this string will be
    #   returned.
    # @param limit [Integer] How many members to send at maximum, or `0` to send all members.
    def send_request_members(server_id, query, limit)
      data = {
        guild_id: server_id,
        query: query,
        limit: limit
      }

      send_packet(Opcodes::REQUEST_MEMBERS, data)
    end

    private

    def setup_heartbeats(interval)
      # Make sure to reset ACK handling, so we don't keep reconnecting
      @last_heartbeat_acked = true

      # We don't want to have redundant heartbeat threads, so if one already exists, don't start a new one
      return if @heartbeat_thread

      @heartbeat_interval = interval
      @heartbeat_thread = Thread.new do
        Thread.current[:discordrb_name] = 'heartbeat'
        loop do
          begin
            # Send a heartbeat if heartbeats are active and either no session exists yet, or an existing session is
            # suspended (e.g. after op7)
            if (@session && !@session.suspended?) || !@session
              sleep @heartbeat_interval
              @bot.raise_heartbeat_event
              heartbeat
            else
              sleep 1
            end
          rescue => e
            LOGGER.error('An error occurred while heartbeating!')
            LOGGER.log_exception(e)
          end
        end
      end
    end

    def connect_loop
      # Initialize falloff so we wait for more time before reconnecting each time
      @falloff = 1.0

      @should_reconnect = true
      loop do
        connect

        break unless @should_reconnect

        if @instant_reconnect
          LOGGER.info('Instant reconnection flag was set - reconnecting right away')
          @instant_reconnect = false
        else
          wait_for_reconnect
        end

        # Restart the loop, i. e. reconnect
      end
    end

    # Separate method to wait an ever-increasing amount of time before reconnecting after being disconnected in an
    # unexpected way
    def wait_for_reconnect
      # We disconnected in an unexpected way! Wait before reconnecting so we don't spam Discord's servers.
      LOGGER.debug("Attempting to reconnect in #{@falloff} seconds.")
      sleep @falloff

      # Calculate new falloff
      @falloff *= 1.5
      @falloff = 115 + (rand * 10) if @falloff > 120 # Cap the falloff at 120 seconds and then add some random jitter
    end

    # Create and connect a socket using a URI
    def obtain_socket(uri)
      socket = TCPSocket.new(uri.host, uri.port || socket_port(uri))

      if secure_uri?(uri)
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.ssl_version = 'SSLv23'
        ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE # use VERIFY_PEER for verification

        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths
        ctx.cert_store = cert_store

        socket = ::OpenSSL::SSL::SSLSocket.new(socket, ctx)
        socket.connect
      end

      socket
    end

    # Whether the URI is secure (connection should be encrypted)
    def secure_uri?(uri)
      %w(https wss).include? uri.scheme
    end

    # The port we should connect to, if the URI doesn't have one set.
    def socket_port(uri)
      secure_uri?(uri) ? 443 : 80
    end

    def find_gateway
      response = API.gateway(@token)
      JSON.parse(response)['url']
    end

    def process_gateway
      raw_url = find_gateway

      # Append a slash in case it's not there (I'm not sure how well WSCS handles it otherwise)
      raw_url += '/' unless raw_url.end_with? '/'

      # Add the parameters we want
      raw_url + "?encoding=json&v=#{GATEWAY_VERSION}"
    end

    def connect
      LOGGER.debug('Connecting')

      # Get the URI we should connect to
      url = process_gateway
      LOGGER.debug("Gateway URL: #{url}")

      # Parse it
      gateway_uri = URI.parse(url)

      # Connect to the obtained URI with a socket
      @socket = obtain_socket(gateway_uri)
      LOGGER.debug('Obtained socket')

      # Initialise some properties
      @handshake = ::WebSocket::Handshake::Client.new(url: url) # Represents the handshake between us and the server
      @handshaked = false # Whether the handshake has finished yet
      @pipe_broken = false # Whether we've received an EPIPE at any time
      @closed = false # Whether the websocket is currently closed

      # We're done! Delegate to the websocket loop
      websocket_loop
    rescue => e
      LOGGER.error('An error occurred while connecting to the websocket!')
      LOGGER.log_exception(e)
    end

    def websocket_loop
      # Send the handshake data that we have so far
      @socket.write(@handshake.to_s)

      # Create a frame to handle received data
      frame = ::WebSocket::Frame::Incoming::Client.new

      until @closed
        begin
          recv_data = nil

          # Get some data from the socket, synchronised so the socket can't be closed during this
          # 24: remove locking
          @getc_mutex.synchronize { recv_data = @socket.getc }

          # Check if we actually got data
          unless recv_data
            # If we didn't, wait
            sleep 1
            next
          end

          # Check whether the handshake has finished yet
          if @handshaked
            # If it hasn't, add the received data to the current frame
            frame << recv_data

            # Try to parse a message from the frame
            msg = frame.next
            while msg
              # Check whether the message is a close frame, and if it is, handle accordingly
              if msg.respond_to?(:code) && msg.code
                handle_internal_close(msg)
                break
              end

              # If there is one, handle it and try again
              handle_message(msg.data)
              msg = frame.next
            end
          else
            # If the handshake hasn't finished, handle it
            handle_handshake_data(recv_data)
          end
        rescue => e
          handle_error(e)
        end
      end
    end

    def handle_handshake_data(recv_data)
      @handshake << recv_data
      return unless @handshake.finished?

      @handshaked = true
      handle_open
    end

    def handle_open; end

    def handle_error(e)
      LOGGER.error('An error occurred in the main websocket loop!')
      LOGGER.log_exception(e)
    end

    def handle_message(msg)
      if msg.byteslice(0) == 'x'
        # The message is compressed, inflate it
        msg = Zlib::Inflate.inflate(msg)
      end

      # Parse packet
      packet = JSON.parse(msg)
      op = packet['op'].to_i

      LOGGER.in(packet)

      # If the packet has a sequence defined (all dispatch packets have one), make sure to update that in the
      # session so it will be acknowledged next heartbeat.
      # Only do this, of course, if a session has been created already; for a READY dispatch (which has s=0 set but is
      # the packet that starts the session in the first place) we need not do any handling since initialising the
      # session will set it to 0 by default.
      @session.sequence = packet['s'] if packet['s'] && @session

      case op
      when Opcodes::DISPATCH
        handle_dispatch(packet)
      when Opcodes::HELLO
        handle_hello(packet)
      when Opcodes::RECONNECT
        handle_reconnect
      when Opcodes::INVALIDATE_SESSION
        handle_invalidate_session
      when Opcodes::HEARTBEAT_ACK
        handle_heartbeat_ack(packet)
      when Opcodes::HEARTBEAT
        handle_heartbeat(packet)
      else
        LOGGER.warn("Received invalid opcode #{op} - please report with this information: #{msg}")
      end
    end

    # Op 0
    def handle_dispatch(packet)
      data = packet['d']
      type = packet['t'].intern

      case type
      when :READY
        LOGGER.info("Discord using gateway protocol version: #{data['v']}, requested: #{GATEWAY_VERSION}")

        @session = Session.new(data['session_id'])
        @session.sequence = 0
      when :RESUMED
        # The RESUMED event is received after a successful op 6 (resume). It does nothing except tell the bot the
        # connection is initiated (like READY would). Starting with v5, it doesn't set a new heartbeat interval anymore
        # since that is handled by op 10 (HELLO).
        LOGGER.good 'Resumed'
        return
      end

      @bot.dispatch(type, data)
    end

    # Op 1
    def handle_heartbeat(packet)
      # If we receive a heartbeat, we have to resend one with the same sequence
      send_heartbeat(packet['s'])
    end

    # Op 7
    def handle_reconnect
      LOGGER.debug('Received op 7, reconnecting and attempting resume')
      reconnect
    end

    # Op 9
    def handle_invalidate_session
      LOGGER.debug('Received op 9, invalidating session and re-identifying.')

      if @session
        @session.invalidate
      else
        LOGGER.warn('Received op 9 without a running session! Not invalidating, we *should* be fine though.')
      end

      identify
    end

    # Op 10
    def handle_hello(packet)
      LOGGER.debug('Hello!')

      # The heartbeat interval is given in ms, so divide it by 1000 to get seconds
      interval = packet['d']['heartbeat_interval'].to_f / 1000.0
      setup_heartbeats(interval)

      LOGGER.debug("Trace: #{packet['d']['_trace']}")
      LOGGER.debug("Session: #{@session.inspect}")

      if @session && @session.should_resume?
        # Make sure we're sending heartbeats again
        @session.resume

        # Send the actual resume packet to get the missing events
        resume
      else
        identify
      end
    end

    # Op 11
    def handle_heartbeat_ack(packet)
      LOGGER.debug("Received heartbeat ack for packet: #{packet.inspect}")
      @last_heartbeat_acked = true if @check_heartbeat_acks
    end

    # Called when the websocket has been disconnected in some way - say due to a pipe error while sending
    def handle_internal_close(e)
      close
      handle_close(e)
    end

    def handle_close(e)
      if e.respond_to? :code
        # It is a proper close frame we're dealing with, print reason and message to console
        LOGGER.error('Websocket close frame received!')
        LOGGER.error("Code: #{e.code}")
        LOGGER.error("Message: #{e.data}")
      elsif e.is_a? Exception
        # Log the exception
        LOGGER.error('The websocket connection has closed due to an error!')
        LOGGER.log_exception(e)
      else
        LOGGER.error("The websocket connection has closed: #{e.inspect}")
      end
    end

    def send_packet(op, packet)
      data = {
        op: op,
        d: packet
      }

      send(data.to_json)
    end

    def send(data, type = :text)
      LOGGER.out(data)

      unless @handshaked && !@closed
        # If we're not handshaked or closed, it means there's no connection to send anything to
        raise 'Tried to send something to the websocket while not being connected!'
      end

      # Create the frame we're going to send
      frame = ::WebSocket::Frame::Outgoing::Client.new(data: data, type: type, version: @handshake.version)

      # Try to send it
      begin
        @socket.write frame.to_s
      rescue => e
        # There has been an error!
        @pipe_broken = true
        handle_internal_close(e)
      end
    end

    def close(no_sync = false)
      # If we're already closed, there's no need to do anything - return
      return if @closed

      # Suspend the session so we don't send heartbeats
      @session.suspend if @session

      # Send a close frame (if we can)
      send nil, :close unless @pipe_broken

      # We're officially closed, notify the main loop.
      # This needs to be synchronised with the getc mutex, so the notification, and especially the actual
      # close afterwards, don't coincide with the main loop reading something from the SSL socket.
      # This would cause a segfault due to (I suspect) Ruby bug #12292: https://bugs.ruby-lang.org/issues/12292
      if no_sync
        @closed = true
      else
        @getc_mutex.synchronize { @closed = true }
      end

      # Close the socket if possible
      @socket.close if @socket
      @socket = nil

      # Make sure we do necessary things as soon as we're closed
      handle_close(nil)
    end
  end
end
