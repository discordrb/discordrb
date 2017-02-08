# frozen_string_literal: true

require 'discordrb/voice/encoder'
require 'discordrb/voice/network'
require 'discordrb/logger'

# Voice support
module Discordrb::Voice
  # How long one voice packet should ideally be (20 ms as defined by Discord)
  IDEAL_LENGTH = 20.0

  # How many bytes of data to read (1920 bytes * 2 channels) from audio PCM data
  DATA_LENGTH = 1920 * 2

  # This class represents a connection to a Discord voice server and channel. It can be used to play audio files and
  # streams and to control playback on currently playing tracks. The method {Bot#voice_connect} can be used to connect
  # to a voice channel.
  #
  # discordrb does latency adjustments every now and then to improve playback quality. I made sure to put useful
  # defaults for the adjustment parameters, but if the sound is patchy or too fast (or the speed varies a lot) you
  # should check the parameters and adjust them to your connection: {VoiceBot#adjust_interval},
  # {VoiceBot#adjust_offset}, and {VoiceBot#adjust_average}.
  class VoiceBot
    # @return [Channel] the current voice channel
    attr_reader :channel

    # @return [Integer, nil] the amount of time the stream has been playing, or `nil` if nothing has been played yet.
    attr_reader :stream_time

    # @return [Encoder] the encoder used to encode audio files into the format required by Discord.
    attr_reader :encoder

    # discordrb will occasionally measure the time it takes to send a packet, and adjust future delay times based
    # on that data. This makes voice playback more smooth, because if packets are sent too slowly, the audio will
    # sound patchy, and if they're sent too quickly, packets will "pile up" and occasionally skip some data or
    # play parts back too fast. How often these measurements should be done depends a lot on the system, and if it's
    # done too quickly, especially on slow connections, the playback speed will vary wildly; if it's done too slowly
    # however, small errors will cause quality problems for a longer time.
    # @return [Integer] how frequently audio length adjustments should be done, in ideal packets (20 ms).
    attr_accessor :adjust_interval

    # This particular value is also important because ffmpeg may take longer to process the first few packets. It is
    # recommended to set this to 10 at maximum, otherwise it will take too long to make the first adjustment, but it
    # shouldn't be any higher than {#adjust_interval}, otherwise no adjustments will take place. If {#adjust_interval}
    # is at a value higher than 10, this value should not be changed at all.
    # @see #adjust_interval
    # @return [Integer] the packet number (1 packet = 20 ms) at which length adjustments should start.
    attr_accessor :adjust_offset

    # This value determines whether or not the adjustment length should be averaged with the previous value. This may
    # be useful on slower connections where latencies vary a lot. In general, it will make adjustments more smooth,
    # but whether that is desired behaviour should be tried on a case-by-case basis.
    # @see #adjust_interval
    # @return [true, false] whether adjustment lengths should be averaged with the respective previous value.
    attr_accessor :adjust_average

    # Disable the debug message for length adjustment specifically, as it can get quite spammy with very low intervals
    # @see #adjust_interval
    # @return [true, false] whether length adjustment debug messages should be printed
    attr_accessor :adjust_debug

    # If this value is set, no length adjustments will ever be done and this value will always be used as the length
    # (i. e. packets will be sent every N seconds). Be careful not to set it too low as to not spam Discord's servers.
    # The ideal length is 20 ms (accessible by the {Discordrb::Voice::IDEAL_LENGTH} constant), this value should be
    # slightly lower than that because encoding + sending takes time. Note that sending DCA files is significantly
    # faster than sending regular audio files (usually about four times as fast), so you might want to set this value
    # to something else if you're sending a DCA file.
    # @return [Float] the packet length that should be used instead of calculating it during the adjustments, in ms.
    attr_accessor :length_override

    # The factor the audio's volume should be multiplied with. `1` is no change in volume, `0` is completely silent,
    # `0.5` is half the default volume and `2` is twice the default.
    # @return [Float] the volume for audio playback, `1.0` by default.
    attr_accessor :volume

    # @!visibility private
    def initialize(channel, bot, token, session, endpoint, encrypted)
      @bot = bot
      @channel = channel

      @ws = VoiceWS.new(channel, bot, token, session, endpoint)
      @udp = @ws.udp
      @udp.encrypted = encrypted

      @sequence = @time = 0
      @skips = 0

      @adjust_interval = 100
      @adjust_offset = 10
      @adjust_average = false
      @adjust_debug = true

      @volume = 1.0
      @playing = false

      @encoder = Encoder.new
      @ws.connect
    rescue => e
      Discordrb::LOGGER.log_exception(e)
      raise
    end

    # @return [true, false] whether audio data sent will be encrypted.
    def encrypted?
      @udp.encrypted?
    end

    # Set the filter volume. This volume is applied as a filter for decoded audio data. It has the advantage that using
    # it is much faster than regular volume, but it can only be changed before starting to play something.
    # @param value [Integer] The value to set the volume to. For possible values, see {#volume}
    def filter_volume=(value)
      @encoder.filter_volume = value
    end

    # @see #filter_volume=
    # @return [Integer] the volume used as a filter for ffmpeg/avconv.
    def filter_volume
      @encoder.filter_volume
    end

    # Pause playback. This is not instant; it may take up to 20 ms for this change to take effect. (This is usually
    # negligible.)
    def pause
      @paused = true
    end

    # @see #play
    # @return [true, false] Whether it is playing sound or not.
    def playing?
      @playing
    end

    alias_method :isplaying?, :playing?

    # Continue playback. This change may take up to 100 ms to take effect, which is usually negligible.
    def continue
      @paused = false
    end

    # Skips to a later time in the song. It's impossible to go back without replaying the song.
    # @param secs [Float] How many seconds to skip forwards. Skipping will always be done in discrete intervals of
    #   0.05 seconds, so if the given amount is smaller than that, it will be rounded up.
    def skip(secs)
      @skips += (secs * (1000 / IDEAL_LENGTH)).ceil
    end

    # Sets whether or not the bot is speaking (green circle around user).
    # @param value [true, false] whether or not the bot should be speaking.
    def speaking=(value)
      @playing = value
      @ws.send_speaking(value)
    end

    # Stops the current playback entirely.
    # @param wait_for_confirmation [true, false] Whether the method should wait for confirmation from the playback
    #   method that the playback has actually stopped.
    def stop_playing(wait_for_confirmation = false)
      @was_playing_before = @playing
      @speaking = false
      @playing = false
      sleep IDEAL_LENGTH / 1000.0 if @was_playing_before

      return unless wait_for_confirmation
      @has_stopped_playing = false
      sleep IDEAL_LENGTH / 1000.0 until @has_stopped_playing
      @has_stopped_playing = false
    end

    # Permanently disconnects from the voice channel; to reconnect you will have to call {Bot#voice_connect} again.
    def destroy
      stop_playing
      @bot.voice_destroy(@channel.server.id, false)
      @ws.destroy
    end

    # Plays a stream of raw data to the channel. All playback methods are blocking, i. e. they wait for the playback to
    # finish before exiting the method. This doesn't cause a problem if you just use discordrb events/commands to
    # play stuff, as these are fully threaded, but if you don't want this behaviour anyway, be sure to call these
    # methods in separate threads.
    # @param encoded_io [IO] A stream of raw PCM data (s16le)
    def play(encoded_io)
      stop_playing(true) if @playing
      @retry_attempts = 3
      @first_packet = true

      play_internal do
        buf = nil

        # Read some data from the buffer
        begin
          buf = encoded_io.readpartial(DATA_LENGTH) if encoded_io
        rescue EOFError
          raise IOError, 'File or stream not found!' if @first_packet

          @bot.debug('EOF while reading, breaking immediately')
          next :stop
        end

        # Check whether the buffer has enough data
        if !buf || buf.length != DATA_LENGTH
          @bot.debug("No data is available! Retrying #{@retry_attempts} more times")
          next :stop if @retry_attempts.zero?

          @retry_attempts -= 1
          next
        end

        # Adjust volume
        buf = @encoder.adjust_volume(buf, @volume) if @volume != 1.0

        @first_packet = false

        # Encode data
        @encoder.encode(buf)
      end

      # If the stream is a process, kill it
      if encoded_io.respond_to? :pid
        Discordrb::LOGGER.debug("Killing ffmpeg process with pid #{encoded_io.pid.inspect}")

        begin
          Process.kill('TERM', encoded_io.pid)
        rescue => e
          Discordrb::LOGGER.warn('Failed to kill ffmpeg process! You *might* have a process leak now.')
          Discordrb::LOGGER.warn("Reason: #{e}")
        end
      end

      # Close the stream
      encoded_io.close
    end

    # Plays an encoded audio file of arbitrary format to the channel.
    # @see Encoder#encode_file
    # @see #play
    def play_file(file)
      play @encoder.encode_file(file)
    end

    # Plays a stream of encoded audio data of arbitrary format to the channel.
    # @see Encoder#encode_io
    # @see #play
    def play_io(io)
      play @encoder.encode_io(io)
    end

    # Plays a stream of audio data in the DCA format. This format has the advantage that no recoding has to be
    # done - the file contains the data exactly as Discord needs it.
    # @note DCA playback will not be affected by the volume modifier ({#volume}) because the modifier operates on raw
    #   PCM, not opus data. Modifying the volume of DCA data would involve decoding it, multiplying the samples and
    #   re-encoding it, which defeats its entire purpose (no recoding).
    # @see https://github.com/bwmarrin/dca
    # @see #play
    def play_dca(file)
      stop_playing(true) if @playing

      @bot.debug "Reading DCA file #{file}"
      input_stream = open(file)

      magic = input_stream.read(4)
      raise ArgumentError, 'Not a DCA1 file! The file might have been corrupted, please recreate it.' unless magic == 'DCA1'

      # Read the metadata header, then read the metadata and discard it as we don't care about it
      metadata_header = input_stream.read(4).unpack('l<')[0]
      input_stream.read(metadata_header)

      # Play the data, without re-encoding it to opus
      play_internal do
        begin
          # Read header
          header_str = input_stream.read(2)

          unless header_str
            @bot.debug 'Finished DCA parsing (header is nil)'
            next :stop
          end

          header = header_str.unpack('s<')[0]

          raise 'Negative header in DCA file! Your file is likely corrupted.' if header < 0
        rescue EOFError
          @bot.debug 'Finished DCA parsing (EOFError)'
          next :stop
        end

        # Read bytes
        input_stream.read(header)
      end
    end

    alias_method :play_stream, :play_io

    private

    # Plays the data from the @io stream as Discord requires it
    def play_internal
      count = 0
      @playing = true

      # Default play length (ms), will be adjusted later
      @length = IDEAL_LENGTH

      self.speaking = true
      loop do
        # Starting from the tenth packet, perform length adjustment every 100 packets (2 seconds)
        should_adjust_this_packet = (count % @adjust_interval == @adjust_offset)

        # If we should adjust, start now
        @length_adjust = Time.now.nsec if should_adjust_this_packet

        break unless @playing

        # If we should skip, get some data, discard it and go to the next iteration
        if @skips > 0
          @skips -= 1
          yield
          next
        end

        # Track packet count, sequence and time (Discord requires this)
        count += 1
        increment_packet_headers

        # Get packet data
        buf = yield

        # Stop doing anything if the stop signal was sent
        break if buf == :stop

        # Proceed to the next packet if we got nil
        next unless buf

        # Track intermediate adjustment so we can measure how much encoding contributes to the total time
        @intermediate_adjust = Time.now.nsec if should_adjust_this_packet

        # Send the packet
        @udp.send_audio(buf, @sequence, @time)

        # Set the stream time (for tracking how long we've been playing)
        @stream_time = count * @length / 1000

        if @length_override # Don't do adjustment because the user has manually specified an override value
          @length = @length_override
        elsif @length_adjust # Perform length adjustment
          # Define the time once so it doesn't get inaccurate
          now = Time.now.nsec

          # Difference between length_adjust and now in ms
          ms_diff = (now - @length_adjust) / 1_000_000.0
          if ms_diff >= 0
            @length = if @adjust_average
                        (IDEAL_LENGTH - ms_diff + @length) / 2.0
                      else
                        IDEAL_LENGTH - ms_diff
                      end

            # Track the time it took to encode
            encode_ms = (@intermediate_adjust - @length_adjust) / 1_000_000.0
            @bot.debug("Length adjustment: new length #{@length} (measured #{ms_diff}, #{(100 * encode_ms) / ms_diff}% encoding)") if @adjust_debug
          end
          @length_adjust = nil
        end

        # If paused, wait
        sleep 0.1 while @paused

        if @length > 0
          # Wait `length` ms, then send the next packet
          sleep @length / 1000.0
        else
          Discordrb::LOGGER.warn('Audio encoding and sending together took longer than Discord expects one packet to be (20 ms)! This may be indicative of network problems.')
        end
      end

      @bot.debug('Sending five silent frames to clear out buffers')

      5.times do
        increment_packet_headers
        @udp.send_audio(Encoder::OPUS_SILENCE, @sequence, @time)

        # Length adjustments don't matter here, we can just wait 20 ms since nobody is going to hear it anyway
        sleep IDEAL_LENGTH / 1000.0
      end

      @bot.debug('Performing final cleanup after stream ended')

      # Final cleanup
      stop_playing

      # Notify any stop_playing methods running right now that we have actually stopped
      @has_stopped_playing = true
    end

    # Increment sequence and time
    def increment_packet_headers
      @sequence + 10 < 65_535 ? @sequence += 1 : @sequence = 0
      @time + 9600 < 4_294_967_295 ? @time += 960 : @time = 0
    end
  end
end
