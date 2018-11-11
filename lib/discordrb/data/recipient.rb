# frozen_string_literal: true

module Discordrb
  # Recipients are members on private channels - they exist for completeness purposes, but all
  # the attributes will be empty.
  class Recipient < DelegateClass(User)
    include MemberAttributes

    # @return [Channel] the private channel this recipient is the recipient of.
    attr_reader :channel

    # @!visibility private
    def initialize(user, channel, bot)
      @bot = bot
      @channel = channel
      raise ArgumentError, 'Tried to create a recipient for a public channel!' unless @channel.private?

      @user = user
      super @user

      # Member attributes
      @mute = @deaf = @self_mute = @self_deaf = false
      @voice_channel = nil
      @server = nil
      @roles = []
      @joined_at = @channel.creation_time
    end

    # Overwriting inspect for debug purposes
    def inspect
      "<Recipient user=#{@user.inspect} channel=#{@channel.inspect}>"
    end
  end
end
