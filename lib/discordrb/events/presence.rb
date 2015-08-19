require 'discordrb/events/generic'

module Discordrb::Events
  class PresenceEvent
    attr_reader :server, :user, :status

    def initialize(data, bot)
      @user = User.new(data['user'], bot)
      @status = data['status'].to_sym
      @server = bot.server(data['guild_id'])
    end
  end

  class PresenceEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? PresenceEvent

      return [
        matches_all(@attributes[:from], event.user) do |a,e|
          if a.is_a? String
            a == e.name
          elsif a.is_a? Fixnum
            a == e.id
          else
            a == e
          end
        end,
        matches_all(@attributes[:status], event.status) do |a,e|
          if a.is_a? String
            a == e.to_s
          else
            a == e
          end
        end
      ].reduce(true, &:&)
    end
  end
end
