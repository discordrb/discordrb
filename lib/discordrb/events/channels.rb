# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Raised when a channel is created
  class ChannelCreateEvent < Event
    # @return [Channel] the channel in question.
    attr_reader :channel

    # @!attribute [r] type
    #   @return [Integer] the channel's type (0:text, 1:private, 2:voice, 3:group).
    #   @see Channel#type
    # @!attribute [r] topic
    #   @return [String] the channel's topic.
    #   @see Channel#topic
    # @!attribute [r] position
    #   @return [Integer] the position of the channel in the channels list.
    #   @see Channel#position
    # @!attribute [r] name
    #   @return [String] the channel's name
    #   @see Channel#name
    # @!attribute [r] id
    #   @return [Integer] the channel's unique ID.
    #   @see Channel#id
    # @!attribute [r] server
    #   @return [Server] the server the channel belongs to.
    #   @see Channel#server
    delegate :type, :topic, :position, :name, :id, :server, to: :channel

    def initialize(data, bot)
      @bot = bot
      @channel = bot.channel(data['id'].to_i)
    end
  end

  # Event handler for ChannelCreateEvent
  class ChannelCreateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ChannelCreateEvent

      [
        matches_all(@attributes[:type], event.type) do |a, e|
          a == if a.is_a? String
                 e.name
               else
                 e
               end
        end,
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

  # Raised when a channel is deleted
  class ChannelDeleteEvent < Event
    # @return [Integer] the channel's type (0:text, 1:private, 2:voice, 3:group).
    attr_reader :type

    # @return [String] the channel's topic
    attr_reader :topic

    # @return [Integer] the position of the channel on the list
    attr_reader :position

    # @return [String] the channel's name
    attr_reader :name

    # @return [Integer] the channel's ID
    attr_reader :id

    # @return [Server] the channel's server
    attr_reader :server

    def initialize(data, bot)
      @bot = bot

      @type = data['type']
      @topic = data['topic']
      @position = data['position']
      @name = data['name']
      @is_private = data['is_private']
      @id = data['id'].to_i
      @server = bot.server(data['guild_id'].to_i) if data['guild_id']
    end
  end

  # Event handler for ChannelDeleteEvent
  class ChannelDeleteEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ChannelDeleteEvent

      [
        matches_all(@attributes[:type], event.type) do |a, e|
          a == if a.is_a? String
                 e.name
               else
                 e
               end
        end,
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

  # Raised when a channel is updated (e.g. topic changes)
  class ChannelUpdateEvent < ChannelCreateEvent; end

  # Event handler for ChannelUpdateEvent
  class ChannelUpdateEventHandler < ChannelCreateEventHandler; end
end
