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
    end
  end

  # Generic event handler for member events
  class GuildEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? GuildEvent

      [
        matches_all(@attributes[:server], event.server) do |a, e|
          a == if a.is_a? String
                 e.name
               elsif a.is_a? Fixnum
                 e.id
               else
                 e
               end
        end
      ].reduce(true, &:&)
    end
  end

  # Server is created
  # @see Discordrb::EventContainer#server_create
  class GuildCreateEvent < GuildEvent; end

  # Event handler for {GuildCreateEvent}
  class GuildCreateEventHandler < GuildEventHandler; end

  # Server is updated (e.g. name changed)
  # @see Discordrb::EventContainer#server_update
  class GuildUpdateEvent < GuildEvent; end

  # Event handler for {GuildUpdateEvent}
  class GuildUpdateEventHandler < GuildEventHandler; end

  # Server is deleted
  # @see Discordrb::EventContainer#server_delete
  class GuildDeleteEvent < GuildEvent
    # Overide init_server to account for the deleted server
    def init_server(data, bot)
      @server = Discordrb::Server.new(data, bot)
    end
  end

  # Event handler for {GuildDeleteEvent}
  class GuildDeleteEventHandler < GuildEventHandler; end
end
