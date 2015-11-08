require 'discordrb/voice/encoder'

require 'faye/websocket'

require 'resolv'
require 'socket'
require 'json'

module Discordrb::Voice
  # A voice connection consisting of a UDP socket and a websocket client
  class VoiceBot
    def initialize(channel, bot, session, endpoint)
      @channel = channel
      @bot = bot
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
      start_time = Time.now.to_f
      sequence = time = count = 0
      length = 20.0
      @playing = true
      @on_warning = false

      self.speaking = true
      loop do
        unless playing
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
            sleep length * 10.0
            continue
          end
        end

        count += 1

        (sequence + 10 < 65_535) ? sequence += 1 : sequence = 0
        (time + 9600 < 4_294_967_295) ? time += 960 : time = 0

        send_buffer(buf, sequence, time)

        @stream_time = count * length
        next_time = start_time + @stream_time
        delay = length + (next_time - Time.now.to_f)

        self.speaking = true unless @playing

        sleep delay
      end
    end

    def send_packet(packet)
      @playing = true
      @udp.send(packet, 0, @ws_data['port'], @endpoint)
    rescue
      @playing = false
      nil
    end

    def make_packet(buf, sequence, time, ssrc)
      [0x80, 0x78, sequence, time, ssrc].pack('CCnNN') + buf
    end

    def send_buffer(raw_buf, sequence, time)
      @playing = true
      packet = make_packet(@encoder.encode(raw_buf), sequence, time, @ws_data['ssrc'])
      send_packet(packet)
    rescue
      nil
    end

    def stop_playing
      @file_io.close if @file_io
      @ws_thread.kill if @ws_thread
      @heartbeat_thread.kill if @heartbeat_thread
      @playing = false
    end

    def play_file(file)
      @file_io = @encoder.encode_file(file)
      play_raw(@file_io)
    end

    private

    def lookup_endpoint
      @endpoint = @endpoint[6..-1] if @endpoint.start_with? 'wss://'
      @endpoint = Resolv.getaddress @endpoint
    end

    def init_udp
      @udp = UDPSocket.new

      # Receive one message, then parse it
      message = @udp.recvmsg
      ip = message[4..message.index("\0")].delete("\0")
      port = message[-2..-1].to_i

      [ip, port]
    end

    def init_ws
      EM.run do
        @ws = Faye::WebSocket::Client.new(@endpoint)

        @ws.on(:open) do
          # Send init packet
          data = {
            op: 0,
            d: {
              server_id: @channel.server.id,
              user_id: @bot.bot_user.id,
              session_id: @session,
              token: @bot.token
            }
          }

          @ws.send(data.to_json)
        end
        @ws.on(:message) { |event| websocket_message(event) }
      end
    end

    def send_heartbeat
      millis = Time.now.strftime('%s%L').to_i
      debug("Sending voice heartbeat at #{millis}")
      data = {
        'op' => 3,
        'd' => nil
      }

      @ws.send(data.to_json)
    end

    def websocket_message(event)
      packet = JSON.parse(event.data)

      case packet['op']
      when 2
        @ws_data = packet['d']

        @heartbeat_interval = @ws_data['heartbeat_interval']
        @heartbeat_thread = Thread.new do
          loop do
            sleep @heartbeat_interval
            send_heartbeat
          end
        end

        to_send = [@ws_data['ssrc']].pack('N')
        @udp.send(to_send, 0, @endpoint, @ws_data['port'])
      when 4
        @ws_data = packet['d']
        @ready = true
        @mode = @ws_data['mode']
      end
    end

    def init_connections
      lookup_endpoint
      ip, port = init_udp
      @ws_thread = Thread.new { init_ws }

      # Send ws init packet
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
