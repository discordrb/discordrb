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

    # **Received**: The functionality of this opcode is less known than the others but it appears to specifically
    # tell the client to invalidate its local session and continue by {IDENTIFY}ing.
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
      @id = session_id
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

    def initialize(bot, token)
      @token = token
      @bot = bot

      # Whether the connection to the gateway has succeeded yet
      @ws_success = false
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
      @handshake.finished? && !@closed
    end

    # Stops the bot gracefully, disconnecting the websocket without immediately killing the thread. This means that
    # Discord is immediately aware of the closed connetion and makes the bot appear offline instantly.
    #
    # If this method doesn't work or you're looking for something more drastic, use {#kill} instead.
    def stop
      @should_reconnect = false
      @ws.close
    end

    # Kills the websocket thread, stopping all connections to Discord.
    def kill
      @ws_thread.kill
    end

    private

    def setup_heartbeats(interval)
      # We don't want to have redundant heartbeat threads, so if one already exists, don't start a new one
      return if @heartbeat_thread

      @heartbeat_interval = interval
      @heartbeat_thread = Thread.new do
        Thread.current[:discordrb_name] = 'heartbeat'
        loop do
          # Send a heartbeat if heartbeats are active and either no session exists yet, or an existing session is
          # suspended (e.g. after op7)
          if (@session && !@session.suspended?) || !@session
            send_heartbeat
            sleep @heartbeat_interval
          else
            sleep 1
          end
        end
      end
    end

    def connect_loop
      # Initialize falloff so we wait for more time before reconnecting each time
      @falloff = 1.0

      loop do
        @should_reconnect = true
        connect

        break unless @should_reconnect

        if @instant_reconnect
          # We got an op 7! Don't wait before reconnecting
          LOGGER.info('Got an op 7, reconnecting right away')
          @instant_reconnect = false
        else
          wait_for_reconnect
        end

        # Restart the loop, i. e. reconnect
      end
    end

    # Create and connect a socket using a URI
    def obtain_socket(uri)
      if secure_uri?(uri)
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.ssl_version = 'SSLv23'
        ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE # use VERIFY_PEER for verification

        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths
        ctx.cert_store = cert_store

        socket = ::OpenSSL::SSL::SSLSocket.new(@socket, ctx)
        socket.connect
      else
        socket = TCPSocket.new(uri.host, uri.port || socket_port(uri))
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
      response = API.gateway(token)
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
      # Get the URI we should connect to
      url = process_gateway

      # Parse it
      gateway_uri = URI.parse(url)

      # Connect to the obtained URI with a socket
      @socket = obtain_socket(gateway_uri)

      # Initialise some properties
      @handshake = ::WebSocket::Handshake::Client.new(url: url) # Represents the handshake between us and the server
      @handshaked = false # Whether the handshake has finished yet
      @pipe_broken = false # Whether we've received an EPIPE at any time

      # Connecting was apparently successful, tell the run method this
      @ws_success = true

      # We're done! Delegate to the websocket loop
      websocket_loop
    end

    def websocket_loop
      # Send the handshake data that we have so far
      @socket.write(@handshake.to_s)

      # Create a frame to handle received data
      frame = ::WebSocket::Frame::Incoming::Client.new

      until @closed
        begin
          # Get some data from the socket
          recv_data = @socket.getc

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
              # If there is one, handle it and try again
              handle_message(msg)
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

    def handle_open
    end

    def handle_error(e)
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
        LOGGER.debug('Connection resumed')
        return
      end

      @bot.dispatch(type, data)
    end

    # Op 7
    def handle_reconnect
      @instant_reconnect = true
      close

      # Suspend session so we resume afterwards
      @session.suspend
    end

    # Op 9
    def handle_invalidate_session
      LOGGER.debug('Received op 9, invalidating session and reidentifying.')
      @session.invalidate
      identify
    end

    # Op 10
    def handle_hello(packet)
      LOGGER.debug('Hello!')

      # The heartbeat interval is given in ms, so divide it by 1000 to get seconds
      interval = packet['d']['heartbeat_interval'].to_f / 1000.0
      setup_heartbeats(interval)

      LOGGER.debug("Trace: #{packet['d']['_trace']}")

      if @session && @session.should_resume?
        resume
      else
        identify
      end
    end

    # Op 11
    def handle_heartbeat_ack(packet)
      LOGGER.debug("Received heartbeat ack for packet: #{packet.inspect}")
    end

    def identify
      data = {
        # Don't send a v anymore as it's entirely determined by the URL now
        token: @token,
        properties: {
          :'$os' => RUBY_PLATFORM,
          :'$browser' => 'discordrb',
          :'$device' => 'discordrb',
          :'$referrer' => '',
          :'$referring_domain' => ''
        },
        compress: true,
        large_threshold: 100
      }

      send(data.to_json)
    end

    # Called when the websocket has been disconnected in some way - say due to a pipe error while sending
    def handle_internal_close(e)
      close
      handle_close(e)
    end

    def handle_close(e)
    end

    def send(data, type = :text)
      unless @handshaked && !@closed
        # If we're not handshaked or closed, it means there's no connection to send anything to
        raise 'Tried to send something to the websocket while not being connected!'
      end

      # Create the frame we're going to send
      frame = ::WebSocket::Frame::Outgoing::Client.new(data: data, type: type, version: @handshake.version)

      # Try to send it
      begin
        @socket.write frame.to_s
      rescue Errno::EPIPE => e
        # There has been an error!
        @pipe_broken = true
        handle_internal_close(e)
      end
    end

    def close
      # If we're already closed, there's no need to do anything - return
      return if @closed

      # Send a close frame (if we can)
      send nil, :close unless @pipe_broken

      # We're officially closed, notify the main loop
      @closed = true

      # Close the socket if possible
      @socket.close if @socket
      @socket = nil

      # Make sure we do necessary things as soon as we're closed
      handle_close(nil)
    end
  end
end
