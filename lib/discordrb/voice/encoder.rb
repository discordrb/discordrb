# frozen_string_literal: true

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
    # Whether or not avconv should be used instead of ffmpeg. If possible, it is recommended to use ffmpeg instead,
    # as it is better supported.
    # @return [true, false] whether avconv should be used instead of ffmpeg.
    attr_accessor :use_avconv

    # @see VoiceBot#filter_volume=
    # @return [Integer] the volume used as a filter to ffmpeg/avconv.
    attr_accessor :filter_volume

    # Create a new encoder
    def initialize
      @sample_rate = 48_000
      @frame_size = 960
      @channels = 2
      @filter_volume = 1

      raise LoadError, 'Opus unavailable - voice not supported! Please install opus for voice support to work.' unless OPUS_AVAILABLE
      @opus = Opus::Encoder.new(@sample_rate, @frame_size, @channels)
    end

    # Set the opus encoding bitrate
    # @param value [Integer] The new bitrate to use, in bits per second (so 64000 if you want 64 kbps)
    def bitrate=(value)
      @opus.bitrate = value
    end

    # Encodes the given buffer using opus.
    # @param buffer [String] An unencoded PCM (s16le) buffer.
    # @return [String] A buffer encoded using opus.
    def encode(buffer)
      @opus.encode(buffer, 1920)
    end

    # One frame of complete silence Opus encoded
    OPUS_SILENCE = [0xF8, 0xFF, 0xFE].pack('C*').freeze

    # Adjusts the volume of a given buffer of s16le PCM data.
    # @param buf [String] An unencoded PCM (s16le) buffer.
    # @param mult [Float] The volume multiplier, 1 for same volume.
    # @return [String] The buffer with adjusted volume, s16le again
    def adjust_volume(buf, mult)
      # We don't need to adjust anything if the buf is nil so just return in that case
      return unless buf

      # buf is s16le so use 's<' for signed, 16 bit, LE
      result = buf.unpack('s<*').map do |sample|
        sample *= mult

        # clamp to s16 range
        [32_767, [-32_768, sample].max].min
      end

      # After modification, make it s16le again
      result.pack('s<*')
    end

    # Encodes a given file (or rather, decodes it) using ffmpeg. This accepts pretty much any format, even videos with
    # an audio track. For a list of supported formats, see https://ffmpeg.org/general.html#Audio-Codecs. It even accepts
    # URLs, though encoding them is pretty slow - I recommend to make a stream of it and then use {#encode_io} instead.
    # @param file [String] The path or URL to encode.
    # @return [IO] the audio, encoded as s16le PCM
    def encode_file(file)
      command = "#{ffmpeg_command} -loglevel 0 -i \"#{file}\" -f s16le -ar 48000 -ac 2 #{filter_volume_argument} pipe:1"
      IO.popen(command)
    end

    # Encodes an arbitrary IO audio stream using ffmpeg. Accepts pretty much any media format, even videos with audio
    # tracks. For a list of supported audio formats, see https://ffmpeg.org/general.html#Audio-Codecs.
    # @param io [IO] The stream to encode.
    # @return [IO] the audio, encoded as s16le PCM
    def encode_io(io)
      ret_io, writer = IO.pipe
      command = "#{ffmpeg_command} -loglevel 0 -i - -f s16le -ar 48000 -ac 2 #{filter_volume_argument} pipe:1"
      spawn(command, in: io, out: writer)
      ret_io
    end

    private

    def ffmpeg_command
      @use_avconv ? 'avconv' : 'ffmpeg'
    end

    def filter_volume_argument
      return '' if @filter_volume == 1
      @use_avconv ? "-vol #{(@filter_volume * 256).ceil}" : "-af volume=#{@filter_volume}"
    end
  end
end
