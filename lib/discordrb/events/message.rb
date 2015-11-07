require 'discordrb/events/generic'

module Discordrb::Events
  # Event raised when a text message is sent to a channel
  class MessageEvent
    attr_reader :message

    delegate :author, :channel, :content, :timestamp, to: :message
    delegate :server, to: :channel

    def initialize(message, bot)
      @bot = bot
      @message = message
    end

    def send_message(content)
      @message.channel.send_message(content)
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
        matches_all(@attributes[:starting_with], event.content) { |a, e| e.start_with? a },
        matches_all(@attributes[:ending_with], event.content) { |a, e| e.end_with? a },
        matches_all(@attributes[:containing], event.content) { |a, e| e.include? a },
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
          else
            a == e
          end
        end,
        matches_all(@attributes[:with_text], event.content) { |a, e| e == a },
        matches_all(@attributes[:after], event.timestamp) { |a, e| a > e },
        matches_all(@attributes[:before], event.timestamp) { |a, e| a < e }
      ].reduce(true, &:&)
    end
  end

  class MentionEvent < MessageEvent; end
  class MentionEventHandler < MessageEventHandler; end
end
