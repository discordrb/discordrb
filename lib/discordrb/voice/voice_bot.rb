require 'discordrb/voice/encoder'

require 'websocket-client-simple'

require 'resolv'
require 'socket'
require 'json'

module Discordrb::Voice
  # A voice connection consisting of a UDP socket and a websocket client
  class VoiceBot
    def initialize(channel, bot, token, session, endpoint)
      @channel = channel
      @bot = bot
      @token = token
      @session = session
      @endpoint = endpoint
      @endpoint.delete(':80')

      @encoder = Encoder.new
      init_connections
    end

    def speaking=(value)
      @playing = value
      data = {
        op: 5,
        d: {
          speaking: value,
          delay: 0
        }
      }
      @ws.send(data.to_json)
    end

    def play_raw(io)
      sequence = time = count = 0
      length = 20.0
      @playing = true
      @on_warning = false

      self.speaking = true
      loop do
        unless @playing
          self.speaking = false
          break
        end

        buf = io.read(1920)

        unless buf
          sleep length * 10.0
          continue
        end

        if buf.length != 1920
          if @on_warning
            io.close
            self.speaking = false
            break
          else
            @on_warning = true
            sleep length * 10.0
            continue
          end
        end

        count += 1

        (sequence + 10 < 65_535) ? sequence += 1 : sequence = 0
        (time + 9600 < 4_294_967_295) ? time += 960 : time = 0

        send_buffer(buf, sequence, time)

        self.speaking = true unless @playing

        @stream_time = count * length / 1000
        sleep length / 1000.0
      end
    end

    def send_packet(packet)
      @udp.send(packet, 0, @endpoint, @port)
    end

    def make_packet(buf, sequence, time, ssrc)
      header = [0x80, 0x78, sequence, time, ssrc].pack('CCnNN')
      header + buf
    end

    def send_buffer(raw_buf, sequence, time)
      encoded = @encoder.encode(raw_buf)
      packet = make_packet(encoded, sequence, time, @ssrc)
      send_packet(packet)
    end

    def stop_playing
      @file_io.close if @file_io
      @ws_thread.kill if @ws_thread
      @encoder.destroy
      @playing = false
    end

    alias_method :destroy, :stop_playing

    def play_file(file)
      @file_io = @encoder.encode_file(file)
      play_raw(@file_io)
    end

    # these are public so they can be accessed from within ws-simple's events

    def websocket_open
      # Send init packet
      data = {
        op: 0,
        d: {
          server_id: @channel.server.id,
          user_id: @bot.bot_user.id,
          session_id: @session,
          token: @token
        }
      }

      @ws.send(data.to_json)
    end

    def websocket_message(msg)
      packet = JSON.parse(msg)

      case packet['op']
        # Opcode 2 (see below)
      when 2
        @ws_data = packet['d']

        @heartbeat_interval = @ws_data['heartbeat_interval']
        @ssrc = @ws_data['ssrc']
        @port = @ws_data['port']

        to_send = [@ssrc].pack('N')

        # Add 66 zeros so the buffer is 70 long
        to_send += "\0" * 66

        # Send UDP discovery
        @udp.send(to_send, 0, @endpoint, @port)
      when 4
        @ws_data = packet['d']
        @ready = true
        @mode = @ws_data['mode']
      end
    end

    private

    def lookup_endpoint
      @orig_endpoint = @endpoint
      @endpoint = @endpoint[6..-1] if @endpoint.start_with? 'wss://'
      @endpoint.delete!(':80') # The endpoint may contain a port, we don't want that
      @endpoint = Resolv.getaddress @endpoint
    end

    def init_udp
      @udp = UDPSocket.new
    end

    def init_ws
      host = "wss://#{@orig_endpoint}:443"
      @ws = WebSocket::Client::Simple.connect(host)

      # Change some instance to local variables for the blocks
      voice_bot = self

      @ws.on(:open) { voice_bot.websocket_open }
      @ws.on(:message) { |msg| voice_bot.websocket_message(msg.data) }
      @ws.on(:error) { |e| puts e.to_s }
      @ws.on(:close) { |e| puts e.to_s }

      loop do
        if @heartbeat_interval
          sleep @heartbeat_interval / 1000.0
          send_heartbeat
        else
          sleep 1
        end
      end
    end

    def send_heartbeat
      millis = Time.now.strftime('%s%L').to_i
      @bot.debug("Sending voice heartbeat at #{millis}")
      data = {
        'op' => 3,
        'd' => nil
      }

      @ws.send(data.to_json)
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
    def init_connections
      lookup_endpoint
      init_udp
      # Connect websocket
      @ws_thread = Thread.new { init_ws }

      # Now wait for opcode 2 and the resulting UDP reply packet
      message = @udp.recvmsg.first
      ip = message[4..-3].delete("\0")
      port = message[-2..-1].to_i

      # Send ws init packet (opcode 1)
      data = {
        op: 1,
        d: {
          protocol: 'udp',
          data: {
            address: ip,
            port: port,
            mode: @ws_data['modes'][0]
          }
        }
      }

      @ws.send(data.to_json)
    end
  end
end
