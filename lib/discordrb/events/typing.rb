require 'discordrb/events/generic'

module Discordrb::Events
  class TypingEvent
    attr_reader :channel, :user, :timestamp

    def initialize(data, bot)
      @user_id = data['user_id']
      @user = bot.user(@user_id)
      @channel_id = data['channel_id']
      @channel = bot.channel(@channel_id)
      @timestamp = Time.at(data['timestamp'].to_i)
    end
  end

  class TypingEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? TypingEvent

      return [
        matches_all(@attributes[:in], event.channel) do |a,e|
          if a.is_a? String
            a == e.name
          elsif a.is_a? Fixnum
            a == e.id
          else
            a == e
          end
        end,
        matches_all(@attributes[:from], event.user) do |a,e|
          if a.is_a? String
            a == e.name
          elsif a.is_a? Fixnum
            a == e.id
          else
            a == e
          end
        end,
        matches_all(@attributes[:after], event.timestamp) { |a,e| a > e },
        matches_all(@attributes[:before], event.timestamp) { |a,e| a < e }
      ].reduce(true, &:&)
    end
  end
end
