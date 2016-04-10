# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Generic subclass for server events (create/update/delete)
  class ServerEvent < Event
    # @return [Server] the server in question.
    attr_reader :server

    def initialize(data, bot)
      @bot = bot

      init_server(data, bot)
    end

    # Initializes this event with server data. Should be overwritten in case the server doesn't exist at the time
    # of event creation (e. g. {ServerDeleteEvent})
    def init_server(data, bot)
      @server = bot.server(data['id'].to_i)
    end
  end

  # Generic event handler for member events
  class ServerEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ServerEvent

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
  class ServerCreateEvent < ServerEvent; end

  # Event handler for {ServerCreateEvent}
  class ServerCreateEventHandler < ServerEventHandler; end

  # Server is updated (e.g. name changed)
  # @see Discordrb::EventContainer#server_update
  class ServerUpdateEvent < ServerEvent; end

  # Event handler for {ServerUpdateEvent}
  class ServerUpdateEventHandler < ServerEventHandler; end

  # Server is deleted
  # @see Discordrb::EventContainer#server_delete
  class ServerDeleteEvent < ServerEvent
    # Overide init_server to account for the deleted server
    def init_server(data, bot)
      @server = Discordrb::Server.new(data, bot, false)
    end
  end

  # Event handler for {ServerDeleteEvent}
  class ServerDeleteEventHandler < ServerEventHandler; end
end
