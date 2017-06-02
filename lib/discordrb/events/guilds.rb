# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Generic subclass for server events (create/update/delete)
  class ServerEvent < Event
    # @return [Server] the server in question.
    attr_reader :server

    def initialize(data, bot)
      @bot = bot

      init_server(data, bot)
    end

    # Initializes this event with server data. Should be overwritten in case the server doesn't exist at the time
    # of event creation (e. g. {ServerDeleteEvent})
    def init_server(data, bot)
      @server = bot.server(data['id'].to_i)
    end
  end

  # Generic event handler for member events
  class ServerEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ServerEvent

      [
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

  # Server is created
  # @see Discordrb::EventContainer#server_create
  class ServerCreateEvent < ServerEvent; end

  # Event handler for {ServerCreateEvent}
  class ServerCreateEventHandler < ServerEventHandler; end

  # Server is updated (e.g. name changed)
  # @see Discordrb::EventContainer#server_update
  class ServerUpdateEvent < ServerEvent; end

  # Event handler for {ServerUpdateEvent}
  class ServerUpdateEventHandler < ServerEventHandler; end

  # Server is deleted
  # @see Discordrb::EventContainer#server_delete
  class ServerDeleteEvent < ServerEvent
    # Override init_server to account for the deleted server
    def init_server(data, bot)
      @server = Discordrb::Server.new(data, bot, false)
    end
  end

  # Event handler for {ServerDeleteEvent}
  class ServerDeleteEventHandler < ServerEventHandler; end

  # Emoji is created/deleted/updated
  class ServerEmojiChangeEvent < ServerEvent
    # @return [Server] the server in question.
    attr_reader :server

    # @return [Array<Emoji>] array of emojis.
    attr_reader :emoji

    def initialize(server, data, bot)
      @bot = bot
      @server = server
      process_emoji(data)
    end

    def process_emoji(data)
      @emoji = data['emojis'].map do |e|
        @server.emoji[e['id']]
      end
    end
  end

  # Generic event helper for when an emoji is either created or deleted
  class ServerEmojiCDEvent < ServerEvent
    # @return [Server] the server in question.
    attr_reader :server

    # @return [Emoji] the emoji data.
    attr_reader :emoji

    def initialize(server, emoji, bot)
      @bot = bot
      @emoji = emoji
      @server = server
    end
  end

  # Emoji is created
  class ServerEmojiCreateEvent < ServerEmojiCDEvent; end

  # Emoji is deleted
  class ServerEmojiDeleteEvent < ServerEmojiCDEvent; end

  # Emoji is updated
  class ServerEmojiUpdateEvent < ServerEvent
    # @return [Server] the server in question.
    attr_reader :server

    # @return [Emoji, nil] the emoji data before the event.
    attr_reader :old_emoji

    # @return [Emoji, nil] the updated emoji data.
    attr_reader :emoji

    def initialize(server, old_emoji, emoji, bot)
      @bot = bot
      @old_emoji = old_emoji
      @emoji = emoji
      @server = server
    end
  end

  # Event handler for {ServerEmojiChangeEvent}
  class ServerEmojiChangeEventHandler < ServerEventHandler; end

  # Generic handler for emoji create and delete
  class ServerEmojiCDEventHandler < ServerEventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ServerEmojiCDEvent

      [
        matches_all(@attributes[:server], event.server) do |a, e|
          a == if a.is_a? String
                 e.name
               elsif a.is_a? Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:id], event.emoji.id) { |a, e| a.resolve_id == e.resolve_id },
        matches_all(@attributes[:name], event.emoji.name) { |a, e| a == e }
      ].reduce(true, &:&)
    end
  end

  # Event handler for {ServerEmojiCreateEvent}
  class ServerEmojiCreateEventHandler < ServerEmojiCDEventHandler; end

  # Event handler for {ServerEmojiDeleteEvent}
  class ServerEmojiDeleteEventHandler < ServerEmojiCDEventHandler; end

  # Event handler for {ServerEmojiUpdateEvent}
  class ServerEmojiUpdateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ServerEmojiUpdateEvent

      [
        matches_all(@attributes[:server], event.server) do |a, e|
          a == if a.is_a? String
                 e.name
               elsif a.is_a? Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:id], event.old_emoji.id) { |a, e| a.resolve_id == e.resolve_id },
        matches_all(@attributes[:old_name], event.old_emoji.name) { |a, e| a == e },
        matches_all(@attributes[:name], event.emoji.name) { |a, e| a == e }
      ].reduce(true, &:&)
    end
  end
end
