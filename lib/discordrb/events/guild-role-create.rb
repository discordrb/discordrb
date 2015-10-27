require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  class GuildRoleCreateEvent
    attr_reader :role
    attr_reader :server

    def initialize(data, bot)
      @server = bot.server(data['guild_id'].to_i)
      return if !@server
      
      role_id = data['role']['id'].to_i
      @role = @server.roles.find {|r| r.id == role_id}
    end
  end

  class GuildRoleCreateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? GuildRoleCreateEvent

      return [
        matches_all(@attributes[:name], event.name) do |a,e|
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
