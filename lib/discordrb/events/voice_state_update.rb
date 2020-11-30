# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Event raised when a user's voice state updates
  class VoiceStateUpdateEvent < Event
    attr_reader :user, :token, :suppress, :session_id, :self_mute, :self_deaf, :mute, :deaf, :server, :channel

    # @return [Channel, nil] the old channel this user was on, or nil if the user is newly joining voice.
    attr_reader :old_channel

    def initialize(data, old_channel_id, bot)
      @bot = bot

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
      @old_channel = bot.channel(old_channel_id) if old_channel_id
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
          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:mute], event.mute) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end,
        matches_all(@attributes[:deaf], event.deaf) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end,
        matches_all(@attributes[:self_mute], event.self_mute) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end,
        matches_all(@attributes[:self_deaf], event.self_deaf) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end,
        matches_all(@attributes[:channel], event.channel) do |a, e|
          next unless e # Don't bother if the channel is nil

          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:old_channel], event.old_channel) do |a, e|
          next unless e # Don't bother if the channel is nil

          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end
      ].reduce(true, &:&)
    end
  end
end
