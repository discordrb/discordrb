# frozen_string_literal: true

require 'discordrb/events/generic'

module Discordrb::Events
  # Raised when a user is banned
  class UserBanEvent < Event
    # @return [User] the user that was banned
    attr_reader :user

    # @return [Server] the server from which the user was banned
    attr_reader :server

    # @!visibility private
    def initialize(data, bot)
      @user = bot.user(data['user']['id'].to_i)
      @server = bot.server(data['guild_id'].to_i)
      @bot = bot
    end
  end

  # Event handler for {UserBanEvent}
  class UserBanEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? UserBanEvent

      [
        matches_all(@attributes[:user], event.user) do |a, e|
          if a.is_a? String
            a == e.name
          elsif a.is_a? Integer
            a == e.id
          elsif a == :bot
            e.current_bot?
          else
            a == e
          end
        end,
        matches_all(@attributes[:server], event.server) do |a, e|
          a == if a.is_a? String
                 e.name
               elsif a.is_a? Integer
                 e.id
               else
                 e
               end
        end
      ].reduce(true, &:&)
    end
  end

  # Raised when a user is unbanned from a server
  class UserUnbanEvent < UserBanEvent; end

  # Event handler for {UserUnbanEvent}
  class UserUnbanEventHandler < UserBanEventHandler; end
end
