# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Generic subclass for server member events (add/update/delete)
  class ServerMemberEvent < Event
    # @return [Member] the member in question.
    attr_reader :user
    alias_method :member, :user

    # @return [Array<Role>] the member's roles.
    attr_reader :roles

    # @return [Server] the server on which the event happened.
    attr_reader :server

    def initialize(data, bot)
      @bot = bot

      @server = bot.server(data['guild_id'].to_i)
      return unless @server

      init_user(data, bot)
      init_roles(data, bot)
    end

    private

    def init_user(data, _)
      user_id = data['user']['id'].to_i
      @user = @server.member(user_id)
    end

    def init_roles(data, _)
      @roles = [@server.role(@server.id)]
      return unless data['roles']

      data['roles'].each do |element|
        role_id = element.to_i
        @roles << @server.roles.find { |r| r.id == role_id }
      end
    end
  end

  # Generic event handler for member events
  class ServerMemberEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ServerMemberEvent

      [
        matches_all(@attributes[:username], event.user.name) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end
      ].reduce(true, &:&)
    end
  end

  # Member joins
  # @see Discordrb::EventContainer#member_join
  class ServerMemberAddEvent < ServerMemberEvent; end

  # Event handler for {ServerMemberAddEvent}
  class ServerMemberAddEventHandler < ServerMemberEventHandler; end

  # Member is updated (roles added or deleted)
  # @see Discordrb::EventContainer#member_update
  class ServerMemberUpdateEvent < ServerMemberEvent; end

  # Event handler for {ServerMemberUpdateEvent}
  class ServerMemberUpdateEventHandler < ServerMemberEventHandler; end

  # Member leaves
  # @see Discordrb::EventContainer#member_leave
  class ServerMemberDeleteEvent < ServerMemberEvent
    # Override init_user to account for the deleted user on the server
    def init_user(data, bot)
      @user = Discordrb::User.new(data['user'], bot)
    end

    # @return [User] the user in question.
    attr_reader :user
  end

  # Event handler for {ServerMemberDeleteEvent}
  class ServerMemberDeleteEventHandler < ServerMemberEventHandler; end
end
