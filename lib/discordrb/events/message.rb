# frozen_string_literal: true

require 'discordrb/events/generic'

module Discordrb::Events
  # Event raised when a text message is sent to a channel
  class MessageEvent < Event
    # @return [Message] the message which triggered this event.
    attr_reader :message

    # @return [String] the message that has been saved by calls to {#<<} and will be sent to Discord upon completion.
    attr_reader :saved_message

    # @return [File] the file that have been saved by calls to {#attach_file} and will be sent to Discord upon completion.
    attr_reader :file

    # @!attribute [r] author
    #   @return [User] who sent this message.
    #   @see Message#author
    # @!attribute [r] channel
    #   @return [Channel] the channel in which this message was sent.
    #   @see Message#channel
    # @!attribute [r] content
    #   @return [String] the message's content.
    #   @see Message#content
    # @!attribute [r] timestamp
    #   @return [Time] the time at which the message was sent.
    #   @see Message#timestamp
    delegate :author, :channel, :content, :timestamp, to: :message

    # @!attribute [r] server
    #   @return [Server, nil] the server where this message was sent, or nil if it was sent in PM.
    #   @see Channel#server
    delegate :server, to: :channel

    def initialize(message, bot)
      @bot = bot
      @message = message
      @saved_message = ''
      @file = nil
    end

    # Sends a message to the channel this message was sent in, right now. It is usually preferable to use {#<<} instead
    # because it avoids rate limiting problems
    # @param content [String] The message to send to the channel
    # @return [Discordrb::Message] the message that was sent
    def send_message(content)
      @message.channel.send_message(content)
    end

    # Sends file with a caption to the channel this message was sent in, right now.
    # It is usually preferable to use {#<<} and {#attach_file} instead
    # because it avoids rate limiting problems
    # @param file [File] The file to send to the channel
    # @param caption [String] The caption attached to the file
    # @return [Discordrb::Message] the message that was sent
    def send_file(file, caption: nil)
      @message.channel.send_file(file, caption: caption)
    end

    # Attaches a file to the message event and converts the message into
    # a caption.
    # @param file [File] The file to be attached
    def attach_file(file)
      raise ArgumentError, "Argument is not a file!" unless file.is_a?(File)
      @file = file
      nil
    end

    # Detaches a file from the message event.
    def detach_file
      @file = nil
      nil
    end

    # @return [true, false] whether or not this message was sent by the bot itself
    def from_bot?
      @message.user.id == @bot.profile.id
    end

    # Utility method to get the voice bot for the current server
    # @return [VoiceBot, nil] the voice bot connected to this message's server, or nil if there is none connected
    def voice
      @bot.voice(@message.channel.server.id)
    end

    # Adds a string to be sent after the event has finished execution. Avoids problems with rate limiting because only
    # one message is ever sent. If it is used multiple times, the strings will bunch up into one message (separated by
    # newlines)
    # @param message [String] The message to send to the channel
    def <<(message)
      @saved_message += "#{message}\n"
      nil
    end

    alias_method :user, :author
    alias_method :text, :content
    alias_method :send, :send_message
    alias_method :respond, :send_message
  end

  # Event handler for MessageEvent
  class MessageEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? MessageEvent

      [
        matches_all(@attributes[:starting_with] || @attributes[:start_with], event.content) do |a, e|
          if a.is_a? String
            e.start_with? a
          elsif a.is_a? Regexp
            (e =~ a) == 0
          end
        end,
        matches_all(@attributes[:ending_with] || @attributes[:end_with], event.content) do |a, e|
          if a.is_a? String
            e.end_with? a
          elsif a.is_a? Regexp
            a.match(e) ? e.end_with?(a.match(e)[-1]) : false
          end
        end,
        matches_all(@attributes[:containing] || @attributes[:contains], event.content) do |a, e|
          if a.is_a? String
            e.include? a
          elsif a.is_a? Regexp
            (e =~ a)
          end
        end,
        matches_all(@attributes[:in], event.channel) do |a, e|
          if a.is_a? String
            # Make sure to remove the "#" from channel names in case it was specified
            a.delete('#') == e.name
          elsif a.is_a? Fixnum
            a == e.id
          else
            a == e
          end
        end,
        matches_all(@attributes[:from], event.author) do |a, e|
          if a.is_a? String
            a == e.name
          elsif a.is_a? Fixnum
            a == e.id
          elsif a == :bot
            e.current_bot?
          else
            a == e
          end
        end,
        matches_all(@attributes[:with_text] || @attributes[:content] || @attributes[:exact_text], event.content) do |a, e|
          if a.is_a? String
            e == a
          elsif a.is_a? Regexp
            match = a.match(e)
            match ? (e == match[0]) : false
          end
        end,
        matches_all(@attributes[:after], event.timestamp) { |a, e| a > e },
        matches_all(@attributes[:before], event.timestamp) { |a, e| a < e },
        matches_all(@attributes[:private], event.channel.private?) { |a, e| !e == !a }
      ].reduce(true, &:&)
    end

    # @see EventHandler#after_call
    def after_call(event)
      if event.file.nil?
        event.send_message(event.saved_message) unless event.saved_message.empty?
      else
        event.send_file(event.file, caption: event.saved_message)
      end
    end
  end

  # @see Discordrb::EventContainer#mention
  class MentionEvent < MessageEvent; end

  # Event handler for {MentionEvent}
  class MentionEventHandler < MessageEventHandler; end

  # @see Discordrb::EventContainer#pm
  class PrivateMessageEvent < MessageEvent; end

  # Event handler for {PrivateMessageEvent}
  class PrivateMessageEventHandler < MessageEventHandler; end

  # A subset of MessageEvent that only contains a message ID and a channel
  class MessageIDEvent < Event
    # @return [Integer] the ID associated with this event
    attr_reader :id

    # @return [Channel] the channel in which this event occurred
    attr_reader :channel

    # @!visibility private
    def initialize(data, bot)
      @id = data['id'].to_i
      @channel = bot.channel(data['channel_id'].to_i)
      @bot = bot
    end
  end

  # Event handler for {MessageIDEvent}
  class MessageIDEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? MessageIDEvent

      [
        matches_all(@attributes[:id], event.id) do |a, e|
          a.resolve_id == e.resolve_id
        end,
        matches_all(@attributes[:in], event.channel) do |a, e|
          if a.is_a? String
            # Make sure to remove the "#" from channel names in case it was specified
            a.delete('#') == e.name
          elsif a.is_a? Integer
            a == e.id
          else
            a == e
          end
        end
      ].reduce(true, &:&)
    end
  end

  # Raised when a message is edited
  # @see Discordrb::EventContainer#message_edit
  class MessageEditEvent < MessageEvent; end

  # Event handler for {MessageEditEvent}
  class MessageEditEventHandler < MessageEventHandler; end

  # Raised when a message is deleted
  # @see Discordrb::EventContainer#message_delete
  class MessageDeleteEvent < MessageIDEvent; end

  # Event handler for {MessageDeleteEvent}
  class MessageDeleteEventHandler < MessageIDEventHandler; end
end
