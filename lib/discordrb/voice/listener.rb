# frozen_string_literal: true

require 'discordrb/voice/encoder'
require 'discordrb/logger'

# Discord voice chat support
module Discordrb::Voice
  # This class receives voice data from a UDP connection.
  class Listener
    # Create a listener
    def initialize(ws)
      @decoder = Decoder.new
      @ws = ws
      @udp = @ws.udp

      # We don't get SSRCs of users until after the first few packets, so we queue unmatched packets.
      @queue = {}
      @opus_blocks = []
      @pcm_blocks = []

      @udp.start_thread self
    end

    # Adds a handler for received opus data.
    # @yield The block is executed when a packet has been received.
    # @yieldparam data [String] The opus buffer.
    # @yieldparam user [User] The user that is sending the buffer (is speaking).
    def opus(&block)
      @opus_blocks.push(block)
    end

    # Adds a handler for received PCM data.
    # @yield The block is executed when a packet has been received.
    # @yieldparam data [String] The decoded buffer.
    # @yieldparam user [User] The user that is sending the buffer (is speaking).
    def pcm(&block)
      @pcm_blocks.push(block)
    end

    # Handles packets received by the UDP connection.
    # @note For internal use only
    # @visibility private
    def handle_packet(message)
      Discordrb::LOGGER.debug 'Received UDP packet'
      ssrc = (message[8] * 0x1000000) + ((message[8 + 1] << 16) | (message[8 + 2] << 8) | message[8 + 3]).to_s.to_i.abs
      Discordrb::LOGGER.debug "Found packet by SSRC #{ssrc}"
      user = @ws.users[ssrc]
      if user
        Discordrb::LOGGER.debug "Identified packet by #{user.username}##{user.discriminator} (#{user.id})"
        if @queue[ssrc].nil?
          decode_packet(message, user)
        else
          @queue[ssrc].push message
          @queue[ssrc].each { |m| decode_packet(m, user) }
          @queue.delete ssrc
        end
      else
        @queue[ssrc] ||= []
        @queue[ssrc].push message
      end
    end

    private

    def decode_packet(message, user)
      nonce = ([0] * 24)
      (0..11).each do |i|
        nonce[i] = message[i]
      end
      message.slice!(0..11)
      Discordrb::LOGGER.debug "Decoding packet by #{user.username}##{user.discriminator} (#{user.id})"
      raise 'No secret key found!' unless @udp.secret_key
      box = RbNaCl::SecretBox.new(@udp.secret_key)
      data = box.decrypt(nonce.pack('C*'), message.pack('C*'))
      @opus_blocks.each do |block|
        block.call(data, user)
      end
      pcm = @decoder.decode(data)
      @pcm_blocks.each do |block|
        block.call(pcm, user)
      end
    rescue RbNaCl::CryptoError => e
      Discordrb::LOGGER.warn 'Failed to decrypt voice packet'
      Discordrb::LOGGER.warn "Reason: #{e}"
    end
  end
end
