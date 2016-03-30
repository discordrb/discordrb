# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
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
