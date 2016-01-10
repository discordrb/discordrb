require 'websocket-client-simple'
require 'resolv'
require 'socket'
require 'json'

module Discordrb::Voice
  # Represents a UDP connection to a voice server
  class VoiceUDP
    # Only creates a socket as the discovery reply may come before the data is initialized.
    def initialize
      @socket = UDPSocket.new
    end

    # Initializes the data from opcode 2
    def connect(endpoint, port, ssrc)
      @endpoint = endpoint
      @endpoint = @endpoint[6..-1] if @endpoint.start_with? 'wss://'
      @endpoint.gsub!(':80', '') # The endpoint may contain a port, we don't want that
      @endpoint = Resolv.getaddress @endpoint

      @port = port
      @ssrc = ssrc
    end

    def receive_discovery_reply
      # Wait for a UDP message
      message = @socket.recvmsg.first
      ip = message[4..-3].delete("\0")
      port = message[-2..-1].to_i
      [ip, port]
    end

    def send_audio(buf, sequence, time)
      packet = [0x80, 0x78, sequence, time, @ssrc].pack('CCnNN') + buf
      send_packet(packet)
    end

    def send_discovery
      discovery_packet = [@ssrc].pack('N')

      # Add 66 zeroes so the packet is 70 bytes long
      discovery_packet += "\0" * 66
      send_packet(discovery_packet)
    end

    private

    def send_packet(packet)
      @socket.send(packet, 0, @endpoint, @port)
    end
  end

  # Represents a websocket connection to the voice server
  class VoiceWS
    attr_reader :udp

    def initialize(channel, bot, token, session, endpoint)
      @channel = channel
      @bot = bot
      @token = token
      @session = session

      @endpoint = endpoint
      @endpoint.gsub!(':80', '')

      @udp = VoiceUDP.new
    end

    # Send a connection init packet (op 0)
    def send_init(server_id, bot_user_id, session_id, token)
      @client.send({
        op: 0,
        d: {
          server_id: server_id,
          user_id: bot_user_id,
          session_id: session_id,
          token: token
        }
      }.to_json)
    end

    # Sends the UDP connection packet (op 1)
    def send_udp_connection(ip, port, mode)
      @client.send({
        op: 1,
        d: {
          protocol: 'udp',
          data: {
            address: ip,
            port: port,
            mode: mode
          }
        }
      }.to_json)
    end

    # Send a heartbeat (op 3), has to be done every @heartbeat_interval seconds or the connection will terminate
    def send_heartbeat
      millis = Time.now.strftime('%s%L').to_i
      @bot.debug("Sending voice heartbeat at #{millis}")

      @client.send({
        'op' => 3,
        'd' => nil
      }.to_json)
    end

    # Send a speaking packet (op 5). This determines the green circle around the avatar in the voice channel
    def send_speaking(value)
      @bot.debug("Speaking: #{value}")
      @client.send({
        op: 5,
        d: {
          speaking: value,
          delay: 0
        }
      }.to_json)
    end

    # Event handlers; public for websocket-simple to work correctly
    def websocket_open
      # Send the init packet
      send_init(@channel.server.id, @bot.bot_user.id, @session, @token)
    end

    def websocket_message(msg)
      @bot.debug("Received VWS message! #{msg}")
      packet = JSON.parse(msg)

      case packet['op']
      when 2
        # Opcode 2 contains data to initialize the UDP connection
        @ws_data = packet['d']

        @heartbeat_interval = @ws_data['heartbeat_interval']
        @ssrc = @ws_data['ssrc']
        @port = @ws_data['port']
        @udp_mode = @ws_data['modes'][0]

        @udp.connect(@endpoint, @port, @ssrc)
        @udp.send_discovery
      when 4
        # I'm not 100% sure what this packet does, but I'm keeping it for future compatibility.
        @ws_data = packet['d']
        @ready = true
        @mode = @ws_data['mode']
      end
    end

    # Communication goes like this:
    # me                    discord
    #   |                      |
    # websocket connect ->     |
    #   |                      |
    #   |     <- websocket opcode 2
    #   |                      |
    # UDP discovery ->         |
    #   |                      |
    #   |       <- UDP reply packet
    #   |                      |
    # websocket opcode 1 ->    |
    #   |                      |
    # ...
    def connect
      # Connect websocket
      @thread = Thread.new do
        Thread.current[:discordrb_name] = 'vws'
        init_ws
      end

      @bot.debug('Started websocket initialization, now waiting for UDP discovery reply')

      # Now wait for opcode 2 and the resulting UDP reply packet
      ip, port = @udp.receive_discovery_reply
      @bot.debug("UDP discovery reply received! #{ip} #{port}")

      # Send UDP init packet with received UDP data
      send_udp_connection(ip, port, @udp_mode)
    end

    def destroy
      @thread.kill if @thread
    end

    private

    def heartbeat_loop
      loop do
        if @heartbeat_interval
          sleep @heartbeat_interval / 1000.0
          send_heartbeat
        else
          # If no interval has been set yet, sleep a second and check again
          sleep 1
        end
      end
    end

    def init_ws
      host = "wss://#{@endpoint}:443"
      @bot.debug("Connecting VWS to host: #{host}")
      @client = WebSocket::Client::Simple.connect(host)

      # Change some instance to local variables for the blocks
      instance = self

      @client.on(:open) { instance.websocket_open }
      @client.on(:message) { |msg| instance.websocket_message(msg.data) }
      @client.on(:error) { |e| puts e.to_s }
      @client.on(:close) { |e| puts e.to_s }

      # Block any further execution
      heartbeat_loop
    end
  end
end
