require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Raised when a user updates on a server (e.g. new name)
  class GuildMemberUpdateEvent
    attr_reader :user
    attr_reader :roles
    attr_reader :server

    def initialize(data, bot)
      @server = bot.server(data['guild_id'].to_i)
      return unless @server

      user_id = data['user']['id'].to_i
      @user = @server.members.find { |u| u.id == user_id }
      @roles = []
      data['roles'].each do |element|
        role_id = element.to_i
        @roles << @server.roles.find { |r| r.id == role_id }
      end
    end
  end

  # Event handler for GuildMemberUpdateEvent
  class GuildMemberUpdateHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? GuildMemberUpdateEvent

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
