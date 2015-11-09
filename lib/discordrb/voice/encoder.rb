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
    end

    def encode(buffer)
      # Create a new buffer each time so opus doesn't segfault. Don't ask me why
      # It still segfaults though
      opus = Opus::Encoder.new(@sample_rate, @frame_size, @channels)
      encoded = opus.encode(buffer, 1920)
      opus.destroy
      encoded
    end

    def encode_file(file)
      command = "ffmpeg -i #{file.path} -f s16le -ar 48000 -ac 1 -af volume=1 pipe:1"
      puts "Command: #{command}"
      IO.popen(command)
    end
  end
end
