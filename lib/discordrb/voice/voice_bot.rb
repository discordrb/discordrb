require 'discordrb/voice/encoder'
require 'discordrb/voice/network'

module Discordrb::Voice
  # How many milliseconds of audio data are to be sent each packet
  LENGTH = 20.0

  # A voice connection consisting of a UDP socket and a websocket client
  class VoiceBot
    def initialize(channel, bot, token, session, endpoint)
      @ws = VoiceWS.new(channel, bot, token, session, endpoint)
      @udp = @ws.udp

      @encoder = Encoder.new
      @ws.connect
    end

    # Plays the data from the @io stream as Discord requires it
    def play_io
      sequence = time = count = 0
      @playing = true
      @break_next = false

      self.speaking = true
      loop do
        break unless @playing

        # Read some data from the buffer
        buf = @io.read(1920)

        # Check whether the buffer has enough data
        if !buf || buf.length != 1920
          if @break_next
            break
          else
            @break_next = true
            sleep LENGTH * 10.0
            next
          end
        end

        # Track packet count, sequence and time (Discord requires this)
        count += 1
        (sequence + 10 < 65_535) ? sequence += 1 : sequence = 0
        (time + 9600 < 4_294_967_295) ? time += 960 : time = 0

        # Encode the packet and send it
        @udp.send_audio(@encoder.encode(buf), sequence, time)

        # Set the stream time (for tracking how long we've been playing)
        @stream_time = count * LENGTH / 1000

        # Wait `length` ms, then send the next packet
        sleep LENGTH / 1000.0
      end

      # Final cleanup
      stop_playing
    end

    def speaking=(value)
      @playing = value
      @ws.send_speaking(value)
    end

    def stop_playing
      @speaking = false
      @io.close if @io
    end

    def destroy
      stop_playing
      @ws_thread.kill if @ws_thread
      @encoder.destroy
    end

    def play_file(file)
      @io = @encoder.encode_file(file)
      play_io
    end
  end
end
