# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Raised when a role is created on a server
  class ServerRoleCreateEvent < Event
    attr_reader :role, :server

    def initialize(data, bot)
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
    attr_reader :id, :server

    def initialize(data, bot)
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

    # Event raised when a role updates on a server
    class ServerRoleUpdateEvent < Event
      attr_reader :role, :server

      def initialize(data, bot)
        @server = bot.server(data['guild_id'].to_i)
        return unless @server

        role_id = data['role']['id'].to_i
        @role = @server.roles.find { |r| r.id == role_id }
      end
    end

    # Event handler for ServerRoleUpdateEvent
    class ServerRoleUpdateEventHandler < EventHandler
      def matches?(event)
        # Check for the proper event type
        return false unless event.is_a? ServerRoleUpdateEvent

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
  end
end
