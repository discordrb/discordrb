# frozen_string_literal: true

module Discordrb::Events
  # Raised when an invite is created.
  class InviteCreateEvent < Event
    # @return [Invite] The invite that was created.
    attr_reader :invite

    # @return [Server, nil] The server the invite was created for.
    attr_reader :server

    # @return [Channel] The channel the invite was created for.
    attr_reader :channel

    # @!attribute [r] code
    #   @return [String] The code for the created invite.
    #   @see Invite#code
    # @!attribute [r] created_at
    #   @return [Time] The time the invite was created at.
    #   @see Invite#created_at
    # @!attribute [r] max_age
    #   @return [Integer] The maximum age of the created invite.
    #   @see Invite#max_age
    # @!attribute [r] max_uses
    #   @return [Integer] The maximum number of uses before the invite expires.
    #   @see Invite#max_uses
    # @!attribute [r] temporary
    #   @return [true, false] Whether or not this invite grants temporary membership.
    #   @see Invite#temporary
    # @!attribute [r] inviter
    #   @return [User] The user that created the invite.
    #   @see Invite#inviter
    delegate :code, :created_at, :max_age, :max_uses, :temporary, :inviter, to: :invite

    alias temporary? temporary

    def initialize(data, invite, bot)
      @bot = bot
      @invite = invite
      @channel = bot.channel(data['channel_id'])
      @server = bot.server(data['guild_id']) if data['guild_id']
    end
  end

  # Raised when an invite is deleted.
  class InviteDeleteEvent < Event
    # @return [Channel] The channel the deleted invite was for.
    attr_reader :channel

    # @return [Server, nil] The server the deleted invite was for.
    attr_reader :server

    # @return [String] The code of the deleted invite.
    attr_reader :code

    def initialize(data, bot)
      @bot = bot
      @channel = bot.channel(data['channel_id'])
      @server = bot.server(data['guild_id']) if data['guild_id']
      @code = data['code']
    end
  end

  # Event handler for InviteCreateEvent.
  class InviteCreateEventHandler < EventHandler
    def matches?(event)
      return false unless event.is_a? InviteCreateEvent

      [
        matches_all(@attributes[:server], event.server) do |a, e|
          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:channel], event.channel) do |a, e|
          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:temporary], event.temporary?, &:==),
        matches_all(@attributes[:inviter], event.inviter, &:==)
      ].reduce(true, &:&)
    end
  end

  # Event handler for InviteDeleteEvent
  class InviteDeleteEventHandler < EventHandler
    def matches?(event)
      return false unless event.is_a? InviteDeleteEvent

      [
        matches_all(@attributes[:server], event.server) do |a, e|
          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:channel], event.channel) do |a, e|
          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end
      ].reduce(true, &:&)
    end
  end
end
