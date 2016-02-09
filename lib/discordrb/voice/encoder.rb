# This makes opus an optional dependency
begin
  require 'opus-ruby'
  OPUS_AVAILABLE = true
rescue LoadError
  OPUS_AVAILABLE = false
end

# Discord voice chat support
module Discordrb::Voice
  # This class conveniently abstracts opus and ffmpeg/avconv, for easy implementation of voice sending. It's not very
  # useful for most users, but I guess it can be useful sometimes.
  class Encoder
    # The volume that should be used with future ffmpeg conversions. If ffmpeg is used, this can be specified as:
    #
    #  * A number, where `1` is no change in volume, `0` is completely silent, `0.5` is half the default volume and `2` is twice the default.
    #  * A string representation of the above number.
    #  * A string representing a change in gain given in decibels, in the format `-6dB` or `6dB`.
    #
    # If avconv is used (see #use_avconv) then it can only be given as a number from `0` to `1`, where `1` is no change
    # and `0` is completely silent.
    # @return [String, Number] the volume for future playbacks, `1.0` by default.
    attr_accessor :volume

    # Whether or not avconv should be used instead of ffmpeg. If possible, it is recommended to use ffmpeg instead,
    # as it is better supported and has a wider range of possible volume settings (see #volume).
    # @return [true, false] whether avconv should be used instead of ffmpeg.
    attr_accessor :use_avconv

    # Create a new encoder
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

    # Encodes the given buffer using opus.
    # @param buffer [String] An unencoded PCM (s16le) buffer.
    # @return [String] A buffer encoded using opus.
    def encode(buffer)
      @opus.encode(buffer, 1920)
    end

    # Destroys this encoder and the opus connection, preventing any future encodings.
    def destroy
      @opus.destroy
    end

    # Adjusts the volume of a given buffer of s16le PCM data.
    # @param buf [String] An unencoded PCM (s16le) buffer.
    # @param mult [Float] The volume multiplier, 1 for same volume.
    # @return [String] The buffer with adjusted volume, s16le again
    def adjust_volume(buf, mult)
      # buf is s16le so use 's<' for signed, 16 bit, LE
      result = buf.unpack('s<').map do |sample|
        sample *= mult

        # clamp to s16 range
        sample = [32767, [-32768, sample].max].min
      end

      # After modification, make it s16le again
      result.pack('s<')
    end

    # Encodes a given file (or rather, decodes it) using ffmpeg. This accepts pretty much any format, even videos with
    # an audio track. For a list of supported formats, see https://ffmpeg.org/general.html#Audio-Codecs. It even accepts
    # URLs, though encoding them is pretty slow - I recommend to make a stream of it and then use {#encode_io} instead.
    # @param file [String] The path or URL to encode.
    # @return [IO] the audio, encoded as s16le PCM
    def encode_file(file)
      command = "#{ffmpeg_command} -loglevel 0 -i \"#{file}\" -f s16le -ar 48000 -ac 2 #{ffmpeg_volume} pipe:1"
      IO.popen(command)
    end

    # Encodes an arbitrary IO audio stream using ffmpeg. Accepts pretty much any media format, even videos with audio
    # tracks. For a list of supported audio formats, see https://ffmpeg.org/general.html#Audio-Codecs.
    # @param io [IO] The stream to encode.
    # @return [IO] the audio, encoded as s16le PCM
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
