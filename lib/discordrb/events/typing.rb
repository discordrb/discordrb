# frozen_string_literal: true

require 'discordrb/events/generic'

module Discordrb::Events
  # Event raised when a user starts typing
  class TypingEvent < Event
    # @return [Channel] the channel on which a user started typing.
    attr_reader :channel

    # @return [Member] the user that started typing.
    attr_reader :user
    alias_method :member, :user

    # @return [Time] when the typing happened.
    attr_reader :timestamp

    def initialize(data, bot)
      @bot = bot

      @user_id = data['user_id'].to_i

      @channel_id = data['channel_id'].to_i
      @channel = bot.channel(@channel_id)
      
      @user = channel.private? ? channel.recipient : bot.member(@channel.server.id, @user_id)

      @timestamp = Time.at(data['timestamp'].to_i)
    end
  end

  # Event handler for TypingEvent
  class TypingEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? TypingEvent

      [
        matches_all(@attributes[:in], event.channel) do |a, e|
          if a.is_a? String
            a.delete('#') == e.name
          elsif a.is_a? Fixnum
            a == e.id
          else
            a == e
          end
        end,
        matches_all(@attributes[:from], event.user) do |a, e|
          a == if a.is_a? String
                 e.name
               elsif a.is_a? Fixnum
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:after], event.timestamp) { |a, e| a > e },
        matches_all(@attributes[:before], event.timestamp) { |a, e| a < e }
      ].reduce(true, &:&)
    end
  end
end
