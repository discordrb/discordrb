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

    def initialize(data, bot)
      @bot = bot

      @user = bot.user(data['user']['id'].to_i)
      @status = data['status'].to_sym
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
          a == if a.is_a? String
                 e.name
               elsif a.is_a? Integer
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

    # @return [String] the new game the user is playing.
    attr_reader :game

    # @return [String] the URL to the stream
    attr_reader :url

    # @return [Integer] the type of play. 0 = game, 1 = Twitch
    attr_reader :type

    def initialize(data, bot)
      @bot = bot

      @user = bot.user(data['user']['id'].to_i)
      @game = data['game'] ? data['game']['name'] : nil
      @server = bot.server(data['guild_id'].to_i)
      @url = data['game'] ? data['game']['url'] : nil
      @type = data['game'] ? data['game']['type'].to_i : nil
    end
  end

  # Event handler for PlayingEvent
  class PlayingEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? PlayingEvent

      [
        matches_all(@attributes[:from], event.user) do |a, e|
          a == if a.is_a? String
                 e.name
               elsif a.is_a? Integer
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
        end
      ].reduce(true, &:&)
    end
  end
end
