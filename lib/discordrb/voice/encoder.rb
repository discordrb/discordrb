require 'opus-ruby'

# Discord voice chat support
module Discordrb::Voice
  # Wrapper class around opus-ruby
  class Encoder
    attr_accessor :volume

    def initialize
      @sample_rate = 48_000
      @frame_size = 960
      @channels = 2
      @volume = 1.0
      @opus = Opus::Encoder.new(@sample_rate, @frame_size, @channels)
    end

    def encode(buffer)
      @opus.encode(buffer, 1920)
    end

    def destroy
      @opus.destroy
    end

    def encode_file(file)
      command = "ffmpeg -loglevel 0 -i #{file.path} -f s16le -ar 48000 -ac 2 -af volume=#{@volume} pipe:1"
      IO.popen(command)
    end
  end
end
