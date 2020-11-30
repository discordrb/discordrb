# frozen_string_literal: true

require 'discordrb/events/generic'

module Discordrb::Events
  # Event raised when a user starts typing
  class TypingEvent < Event
    include Respondable

    # @return [Channel] the channel on which a user started typing.
    attr_reader :channel

    # @return [User, Member, Recipient] the user that started typing.
    attr_reader :user
    alias_method :member, :user

    # @return [Time] when the typing happened.
    attr_reader :timestamp

    def initialize(data, bot)
      @bot = bot

      @user_id = data['user_id'].to_i

      @channel_id = data['channel_id'].to_i
      @channel = bot.channel(@channel_id)

      @user = if channel.pm?
                channel.recipient
              elsif channel.group?
                bot.user(@user_id)
              else
                bot.member(@channel.server.id, @user_id)
              end

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
          case a
          when String
            a.delete('#') == e.name
          when Integer
            a == e.id
          else
            a == e
          end
        end,
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
        matches_all(@attributes[:after], event.timestamp) { |a, e| a > e },
        matches_all(@attributes[:before], event.timestamp) { |a, e| a < e }
      ].reduce(true, &:&)
    end
  end
end
