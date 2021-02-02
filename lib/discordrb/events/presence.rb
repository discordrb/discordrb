# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Event raised when a user's presence state updates (idle or online)
  class PresenceEvent < Event
    # @return [Server] the server on which the presence update happened.
    attr_reader :server

    # @return [User] the user whose status got updated.
    attr_reader :user

    # @return [Symbol] the new status.
    attr_reader :status

    # @return [Hash<Symbol, Symbol>] the current online status (`:online`, `:idle` or `:dnd`) of the user
    #   on various device types (`:desktop`, `:mobile`, or `:web`). The value will be `nil` if the user is offline or invisible.
    attr_reader :client_status

    def initialize(data, bot)
      @bot = bot

      @user = bot.user(data['user']['id'].to_i)
      @status = data['status'].to_sym
      @client_status = user.client_status
      @server = bot.server(data['guild_id'].to_i)
    end
  end

  # Event handler for PresenceEvent
  class PresenceEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? PresenceEvent

      [
        matches_all(@attributes[:from], event.user) do |a, e|
          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:status], event.status) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end
      ].reduce(true, &:&)
    end
  end

  # Event raised when a user starts or stops playing a game
  class PlayingEvent < Event
    # @return [Server] the server on which the presence update happened.
    attr_reader :server

    # @return [User] the user whose status got updated.
    attr_reader :user

    # @return [Discordrb::Activity] The new activity
    attr_reader :activity

    # @!attribute [r] url
    #   @return [String] the URL to the stream

    # @!attribute [r] details
    #   @return [String] what the player is currently doing (ex. game being streamed)

    # @!attribute [r] type
    #   @return [Integer] the type of play. See {Discordrb::Activity}
    delegate :url, :details, :type, to: :activity

    # @return [Hash<Symbol, Symbol>] the current online status (`:online`, `:idle` or `:dnd`) of the user
    #   on various device types (`:desktop`, `:mobile`, or `:web`). The value will be `nil` if the user is offline or invisible.
    attr_reader :client_status

    def initialize(data, activity, bot)
      @bot = bot
      @activity = activity

      @server = bot.server(data['guild_id'].to_i)
      @user = bot.user(data['user']['id'].to_i)
      @client_status = @user.client_status
    end

    # @return [String] the name of the new game the user is playing.
    def game
      @activity.name
    end
  end

  # Event handler for PlayingEvent
  class PlayingEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? PlayingEvent

      [
        matches_all(@attributes[:from], event.user) do |a, e|
          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:game], event.game) do |a, e|
          a == e
        end,
        matches_all(@attributes[:type], event.type) do |a, e|
          a == e
        end,
        matches_all(@attributes[:client_status], event.client_status) do |a, e|
          e.slice(a.keys) == a
        end
      ].reduce(true, &:&)
    end
  end
end
