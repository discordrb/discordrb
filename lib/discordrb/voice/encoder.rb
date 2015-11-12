require 'opus-ruby'

# Discord voice chat support
module Discordrb::Voice
  # Wrapper class around opus-ruby
  class Encoder
    def initialize
      @sample_rate = 48_000
      @frame_size = 960
      # Mono because Discord would make it mono on playback anyway
      @channels = 1
      @opus = Opus::Encoder.new(@sample_rate, @frame_size, @channels)
    end

    def encode(buffer)
      @opus.encode(buffer, 1920)
    end

    def destroy
      @opus.destroy
    end

    def encode_file(file)
      command = "ffmpeg -i #{file.path} -f s16le -ar 48000 -ac 1 -af volume=1 pipe:1"
      IO.popen(command)
    end
  end
end
