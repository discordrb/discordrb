require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Raised when a role is deleted from a server
  class GuildRoleDeleteEvent
    attr_reader :id
    attr_reader :server

    def initialize(data, bot)
      # The role should already be deleted from the server's list
      # by the time we create this event, so we'll create a temporary
      # role object for event consumers to use.
      @id = data['role_id'].to_i
      server_id = data['guild_id'].to_i
      @server = bot.server(server_id)
    end
  end

  # EventHandler for GuildRoleDeleteEvent
  class GuildRoleDeleteEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? GuildRoleDeleteEvent

      [
        matches_all(@attributes[:name], event.name) do |a, e|
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
