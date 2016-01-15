begin
  require 'opus-ruby'
  OPUS_AVAILABLE = true
rescue LoadError
  OPUS_AVAILABLE = false
end

# Discord voice chat support
module Discordrb::Voice
  # Wrapper class around opus-ruby
  class Encoder
    attr_accessor :volume, :use_avconv

    def initialize
      @sample_rate = 48_000
      @frame_size = 960
      @channels = 2
      @volume = 1.0

      if OPUS_AVAILABLE
        @opus = Opus::Encoder.new(@sample_rate, @frame_size, @channels)
      else
        fail LoadError, 'Opus unavailable - voice not supported! Please install opus for voice support to work.'
      end
    end

    def encode(buffer)
      @opus.encode(buffer, 1920)
    end

    def destroy
      @opus.destroy
    end

    def encode_file(file)
      command = "#{ffmpeg_command} -loglevel 0 -i \"#{file}\" -f s16le -ar 48000 -ac 2 #{ffmpeg_volume} pipe:1"
      IO.popen(command)
    end

    def encode_io(io)
      ret_io, writer = IO.pipe
      command = "#{ffmpeg_command} -loglevel 0 -i - -f s16le -ar 48000 -ac 2 #{ffmpeg_volume} pipe:1"
      spawn(command, in: io, out: writer)
      ret_io
    end

    private

    def ffmpeg_command
      @use_avconv ? 'avconv' : 'ffmpeg'
    end

    def ffmpeg_volume
      @use_avconv ? "-vol #{(@volume * 256).ceil}" : "-af volume=#{@volume}"
    end
  end
end
