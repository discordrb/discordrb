require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Generic subclass for server member events (add/update/delete)
  class GuildMemberEvent
    attr_reader :user
    attr_reader :roles
    attr_reader :server

    def initialize(data, bot)
      @server = bot.server(data['guild_id'].to_i)
      return unless @server

      init_user(data, bot)
      init_roles(data, bot)
    end

    private

    def init_user(data, _)
      user_id = data['user']['id'].to_i
      @user = @server.members.find { |u| u.id == user_id }
    end

    def init_roles(data, _)
      @roles = []
      return unless data['roles']
      data['roles'].each do |element|
        role_id = element.to_i
        @roles << @server.roles.find { |r| r.id == role_id }
      end
    end
  end

  # Generic event handler for member events
  class GuildMemberEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? GuildMemberAddEvent

      [
        matches_all(@attributes[:username], event.user.name) do |a, e|
          if a.is_a? String
            a == e.to_s
          else
            a == e
          end
        end
      ].reduce(true, &:&)
    end
  end

  # Specialized subclasses
  # Member joins
  class GuildMemberAddEvent < GuildMemberEvent; end
  class GuildMemberAddEventHandler < GuildMemberEventHandler; end

  # Member is updated (e.g. name changed)
  class GuildMemberUpdateEvent < GuildMemberEvent; end
  class GuildMemberUpdateEventHandler < GuildMemberEventHandler; end

  # Member leaves
  class GuildMemberDeleteEvent < GuildMemberEvent
    # Overide init_user to account for the deleted user on the server
    def init_user(data, bot)
      @user = Discordrb::User.new(data['user'], bot)
    end
  end
  class GuildMemberDeleteEventHandler < GuildMemberEventHandler; end
end
