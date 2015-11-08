require 'opus-ruby'

# Discord voice chat support
module Discordrb::Voice
  # Wrapper class around opus-ruby
  class Encoder
    def initialize
      @opus = Opus::Encoder.new(48_000, 1920, 1)
    end

    def encode(buffer)
      @opus.encode(buffer, 1920)
    end

    def encode_file(file)
      command = "ffmpeg -i #{file.path} -f s16le -ar 48000 -ac 1 -af volume=1 pipe:1"
      IO.popen(command)
    end
  end
end
