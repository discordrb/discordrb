# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Raised when a role is created on a server
  class ServerRoleCreateEvent < Event
    # @return [Role] the role that got created
    attr_reader :role

    # @return [Server] the server on which a role got created
    attr_reader :server

    def initialize(data, bot)
      @bot = bot

      @server = bot.server(data['guild_id'].to_i)
      return unless @server

      role_id = data['role']['id'].to_i
      @role = @server.roles.find { |r| r.id == role_id }
    end
  end

  # Event handler for ServerRoleCreateEvent
  class ServerRoleCreateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ServerRoleCreateEvent

      [
        matches_all(@attributes[:name], event.name) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end
      ].reduce(true, &:&)
    end
  end

  # Raised when a role is deleted from a server
  class ServerRoleDeleteEvent < Event
    # @return [Integer] the ID of the role that got deleted.
    attr_reader :id

    # @return [Server] the server on which a role got deleted.
    attr_reader :server

    def initialize(data, bot)
      @bot = bot

      # The role should already be deleted from the server's list
      # by the time we create this event, so we'll create a temporary
      # role object for event consumers to use.
      @id = data['role_id'].to_i
      server_id = data['guild_id'].to_i
      @server = bot.server(server_id)
    end
  end

  # EventHandler for ServerRoleDeleteEvent
  class ServerRoleDeleteEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ServerRoleDeleteEvent

      [
        matches_all(@attributes[:name], event.name) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end
      ].reduce(true, &:&)
    end
  end

  # Event raised when a role updates on a server
  class ServerRoleUpdateEvent < ServerRoleCreateEvent; end

  # Event handler for ServerRoleUpdateEvent
  class ServerRoleUpdateEventHandler < ServerRoleCreateEventHandler; end
end
