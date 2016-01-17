require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Event raised when a user's presence state updates (idle or online)
  class PresenceEvent
    attr_reader :server, :user, :status

    def initialize(data, bot)
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
               elsif a.is_a? Fixnum
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
  class PlayingEvent
    attr_reader :server, :user, :game

    def initialize(data, bot)
      @user = bot.user(data['user']['id'].to_i)

      @game = data['game'] ? data['game']['name'] : nil

      @server = bot.server(data['guild_id'].to_i)
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
               elsif a.is_a? Fixnum
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:game], event.game) do |a, e|
          a == if a.is_a? String
                 e.name
               else
                 e
               end
        end
      ].reduce(true, &:&)
    end
  end
end
