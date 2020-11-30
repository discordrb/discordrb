# frozen_string_literal: true

require 'websocket-client-simple'
require 'socket'
require 'json'

require 'discordrb/websocket'

begin
  LIBSODIUM_AVAILABLE = if ENV['DISCORDRB_NONACL']
                          false
                        else
                          require 'discordrb/voice/sodium'
                        end
rescue LoadError
  puts "libsodium not available! You can continue to use discordrb as normal but voice support won't work.
        Read https://github.com/shardlab/discordrb/wiki/Installing-libsodium for more details."
  LIBSODIUM_AVAILABLE = false
end

module Discordrb::Voice
  # Signifies to Discord that encryption should be used
  # @deprecated Discord now supports multiple encryption options.
  # TODO: Resolve replacement for this constant.
  ENCRYPTED_MODE = 'xsalsa20_poly1305'

  # Signifies to Discord that no encryption should be used
  # @deprecated Discord no longer supports unencrypted voice communication.
  PLAIN_MODE = 'plain'

  # Encryption modes supported by Discord
  ENCRYPTION_MODES = %w[xsalsa20_poly1305_lite xsalsa20_poly1305_suffix xsalsa20_poly1305].freeze

  # Represents a UDP connection to a voice server. This connection is used to send the actual audio data.
  class VoiceUDP
    # @return [true, false] whether or not UDP communications are encrypted.
    # @deprecated Discord no longer supports unencrypted voice communication.
    attr_accessor :encrypted
    alias_method :encrypted?, :encrypted

    # Sets the secret key used for encryption
    attr_writer :secret_key

    # The UDP encryption mode
    attr_reader :mode # rubocop:disable Style/BisectedAttrAccessor

    # @!visibility private
    attr_writer :mode # rubocop:disable Style/BisectedAttrAccessor

    # Creates a new UDP connection. Only creates a socket as the discovery reply may come before the data is
    # initialized.
    def initialize
      @socket = UDPSocket.new
      @encrypted = true
    end

    # Initializes the UDP socket with data obtained from opcode 2.
    # @param ip [String] The IP address to connect to.
    # @param port [Integer] The port to connect to.
    # @param ssrc [Integer] The Super Secret Relay Code (SSRC). Discord uses this to identify different voice users
    #   on the same endpoint.
    def connect(ip, port, ssrc)
      @ip = ip
      @port = port
      @ssrc = ssrc
    end

    # Waits for a UDP discovery reply, and returns the sent data.
    # @return [Array(String, Integer)] the IP and port received from the discovery reply.
    def receive_discovery_reply
      # Wait for a UDP message
      message = @socket.recv(70)
      ip = message[4..-3].delete("\0")
      port = message[-2..-1].unpack1('n')
      [ip, port]
    end

    # Makes an audio packet from a buffer and sends it to Discord.
    # @param buf [String] The audio data to send, must be exactly one Opus frame
    # @param sequence [Integer] The packet sequence number, incremented by one for subsequent packets
    # @param time [Integer] When this packet should be played back, in no particular unit (essentially just the
    #   sequence number multiplied by 960)
    def send_audio(buf, sequence, time)
      # Header of the audio packet
      header = [0x80, 0x78, sequence, time, @ssrc].pack('CCnNN')

      nonce = generate_nonce(header)
      buf = encrypt_audio(buf, nonce)

      data = header + buf

      # xsalsa20_poly1305 does not require an appended nonce
      data += nonce unless @mode == 'xsalsa20_poly1305'

      send_packet(data)
    end

    # Sends the UDP discovery packet with the internally stored SSRC. Discord will send a reply afterwards which can
    # be received using {#receive_discovery_reply}
    def send_discovery
      discovery_packet = [@ssrc].pack('N')

      # Add 66 zeroes so the packet is 70 bytes long
      discovery_packet += "\0" * 66
      send_packet(discovery_packet)
    end

    private

    # Encrypts audio data using libsodium
    # @param buf [String] The encoded audio data to be encrypted
    # @param nonce [String] The nonce to be used to encrypt the data
    # @return [String] the audio data, encrypted
    def encrypt_audio(buf, nonce)
      raise 'No secret key found, despite encryption being enabled!' unless @secret_key

      secret_box = Discordrb::Voice::SecretBox.new(@secret_key)

      # Nonces must be 24 bytes in length. We right pad with null bytes for poly1305 and poly1305_lite
      secret_box.box(nonce.ljust(24, "\0"), buf)
    end

    def send_packet(packet)
      @socket.send(packet, 0, @ip, @port)
    end

    # @param header [String] The header of the packet, to be used as the nonce
    # @return [String]
    # @note
    #   The nonce generated depends on the encryption mode.
    #   In xsalsa20_poly1305 the nonce is the header plus twelve null bytes for padding.
    #   In xsalsa20_poly1305_suffix, the nonce is 24 random bytes
    #   In xsalsa20_poly1305_lite, the nonce is an incremental 4 byte int.
    def generate_nonce(header)
      case @mode
      when 'xsalsa20_poly1305'
        header
      when 'xsalsa20_poly1305_suffix'
        Random.urandom(24)
      when 'xsalsa20_poly1305_lite'
        case @lite_nonce
        when nil, 0xff_ff_ff_ff
          @lite_nonce = 0
        else
          @lite_nonce += 1
        end
        [@lite_nonce].pack('N')
      else
        raise "`#{@mode}' is not a supported encryption mode"
      end
    end
  end

  # Represents a websocket client connection to the voice server. The websocket connection (sometimes called vWS) is
  # used to manage general data about the connection, such as sending the speaking packet, which determines the green
  # circle around users on Discord, and obtaining UDP connection info.
  class VoiceWS
    # The version of the voice gateway that's supposed to be used.
    VOICE_GATEWAY_VERSION = 4

    # @return [VoiceUDP] the UDP voice connection over which the actual audio data is sent.
    attr_reader :udp

    # Makes a new voice websocket client, but doesn't connect it (see {#connect} for that)
    # @param channel [Channel] The voice channel to connect to
    # @param bot [Bot] The regular bot to which this vWS is bound
    # @param token [String] The authentication token which is also used for REST requests
    # @param session [String] The voice session ID Discord sends over the regular websocket
    # @param endpoint [String] The endpoint URL to connect to
    def initialize(channel, bot, token, session, endpoint)
      raise 'libsodium is unavailable - unable to create voice bot! Please read https://github.com/shardlab/discordrb/wiki/Installing-libsodium' unless LIBSODIUM_AVAILABLE

      @channel = channel
      @bot = bot
      @token = token
      @session = session

      @endpoint = endpoint.split(':').first

      @udp = VoiceUDP.new
    end

    # Send a connection init packet (op 0)
    # @param server_id [Integer] The ID of the server to connect to
    # @param bot_user_id [Integer] The ID of the bot that is connecting
    # @param session_id [String] The voice session ID
    # @param token [String] The Discord authentication token
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
    # @param ip [String] The IP to bind UDP to
    # @param port [Integer] The port to bind UDP to
    # @param mode [Object] Which mode to use for the voice connection
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
        op: 3,
        d: millis
      }.to_json)
    end

    # Send a speaking packet (op 5). This determines the green circle around the avatar in the voice channel
    # @param value [true, false, Integer] Whether or not the bot should be speaking, can also be a bitmask denoting audio type.
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
    # @!visibility private
    def websocket_open
      # Give the current thread a name ('Voice Web Socket Internal')
      Thread.current[:discordrb_name] = 'vws-i'

      # Send the init packet
      send_init(@channel.server.id, @bot.profile.id, @session, @token)
    end

    # @!visibility private
    def websocket_message(msg)
      @bot.debug("Received VWS message! #{msg}")
      packet = JSON.parse(msg)

      case packet['op']
      when 2
        # Opcode 2 contains data to initialize the UDP connection
        @ws_data = packet['d']

        @ssrc = @ws_data['ssrc']
        @port = @ws_data['port']

        @udp_mode = (ENCRYPTION_MODES & @ws_data['modes']).first

        @udp.connect(@ws_data['ip'], @port, @ssrc)
        @udp.send_discovery
      when 4
        # Opcode 4 sends the secret key used for encryption
        @ws_data = packet['d']

        @ready = true
        @udp.secret_key = @ws_data['secret_key'].pack('C*')
        @udp.mode = @ws_data['mode']
      when 8
        # Opcode 8 contains the heartbeat interval.
        @heartbeat_interval = packet['d']['heartbeat_interval']
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

      @bot.debug('Waiting for op 4 now')

      # Wait for op 4, then finish
      sleep 0.05 until @ready
    end

    # Disconnects the websocket and kills the thread
    def destroy
      @heartbeat_running = false
    end

    private

    def heartbeat_loop
      @heartbeat_running = true
      while @heartbeat_running
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
      host = "wss://#{@endpoint}:443/?v=#{VOICE_GATEWAY_VERSION}"
      @bot.debug("Connecting VWS to host: #{host}")

      # Connect the WS
      @client = Discordrb::WebSocket.new(
        host,
        method(:websocket_open),
        method(:websocket_message),
        proc { |e| Discordrb::LOGGER.error "VWS error: #{e}" },
        proc { |e| Discordrb::LOGGER.warn "VWS close: #{e}" }
      )

      @bot.debug('VWS connected')

      # Block any further execution
      heartbeat_loop
    end
  end
end
