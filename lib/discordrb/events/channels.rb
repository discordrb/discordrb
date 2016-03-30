# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Raised when a channel is created
  class ChannelCreateEvent < Event
    # @return [Channel] the channel in question.
    attr_reader :channel

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
    attr_reader :type, :topic, :position, :name, :id, :server

    def initialize(data, bot)
      @type = data['type']
      @topic = data['topic']
      @position = data['position']
      @name = data['name']
      @is_private = data['is_private']
      @id = data['id'].to_i
      @server = bot.server(data['guild_id'].to_i)
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
  class ChannelUpdateEvent < Event
    attr_reader :type, :topic, :position, :name, :channel, :server

    def initialize(data, bot)
      @type = data['type']
      @topic = data['topic']
      @position = data['position']
      @name = data['name']
      @is_private = data['is_private']
      @server = bot.server(data['guild_id'].to_i)
      return unless @server

      @channel = bot.channel(data['id'].to_i)
    end
  end

  # Event handler for ChannelUpdateEvent
  class ChannelUpdateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ChannelUpdateEvent

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
end
