require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Event raised when a user's voice state updates
  class VoiceStateUpdateEvent
    attr_reader :user
    attr_reader :token
    attr_reader :suppress
    attr_reader :session_id
    attr_reader :self_mute
    attr_reader :self_deaf
    attr_reader :mute
    attr_reader :deaf
    attr_reader :server
    attr_reader :channel

    def initialize(data, bot)
      @token = data['token']
      @suppress = data['suppress']
      @session_id = data['session_id']
      @self_mute = data['self_mute']
      @self_deaf = data['self_deaf']
      @mute = data['mute']
      @deaf = data['deaf']
      @server = bot.server(data['guild_id'].to_i)
      return unless @server

      @channel = bot.channel(data['channel_id'].to_i) if data['channel_id']
      @user = bot.user(data['user_id'].to_i)
    end
  end

  # Event handler for VoiceStateUpdateEvent
  class VoiceStateUpdateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? VoiceStateUpdateEvent

      [
        matches_all(@attributes[:from], event.user) do |a, e|
          if a.is_a? String
            a == e.name
          elsif a.is_a? Fixnum
            a == e.id
          else
            a == e
          end
        end,
        matches_all(@attributes[:mute], event.mute) do |a, e|
          if a.is_a? Boolean
            a == e.to_s
          else
            a == e
          end
        end,
        matches_all(@attributes[:deaf], event.deaf) do |a, e|
          if a.is_a? Boolean
            a == e.to_s
          else
            a == e
          end
        end,
        matches_all(@attributes[:self_mute], event.self_mute) do |a, e|
          if a.is_a? Boolean
            a == e.to_s
          else
            a == e
          end
        end,
        matches_all(@attributes[:self_deaf], event.self_deaf) do |a, e|
          if a.is_a? Boolean
            a == e.to_s
          else
            a == e
          end
        end,
        matches_all(@attributes[:channel], event.channel) do |a, e|
          if a.is_a? String
            a == e.name
          elsif a.is_a? Fixnum
            a == e.id
          else
            a == e
          end
        end
      ].reduce(true, &:&)
    end
  end
end
