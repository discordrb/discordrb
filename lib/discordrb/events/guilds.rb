require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Generic subclass for server events (create/update/delete)
  class GuildEvent
    attr_reader :server

    def initialize(data, bot)
      init_server(data, bot)
    end

    def init_server(data, bot)
      @server = bot.server(data['id'].to_i)
      return unless @server
    end
  end

  # Generic event handler for member events
  class GuildEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? GuildEvent

      [
        matches_all(@attributes[:server], event.server) do |a, e|
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

  # Specialized subclasses
  # Server is created
  class GuildCreateEvent < GuildEvent; end
  class GuildCreateEventHandler < GuildEventHandler; end

  # Server is updated (e.g. name changed)
  class GuildUpdateEvent < GuildEvent; end
  class GuildUpdateEventHandler < GuildEventHandler; end

  # Server is deleted
  class GuildDeleteEvent < GuildEvent
    # Overide init_server to account for the deleted server
    def init_server(data, bot)
      @server = Discordrb::Server.new(data, bot)
    end
  end
  class GuildDeleteEventHandler < GuildEventHandler; end
end
