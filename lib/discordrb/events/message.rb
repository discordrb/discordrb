require 'discordrb/events/generic'

module Discordrb::Events
  class MessageEvent
    attr_reader :message

    def initialize(message)
      @message = message
    end

    def author; @message.author; end
    alias_method :user, :author
    def channel; @message.channel; end
    def content; @message.content; end
    alias_method :text, :content
    def timestamp; @message.timestamp; end
    
    def send_message(content); @message.send_message(content); end
    def send(content); @message.send(content); end
    def message(content); @message.message(content); end
  end

  class MessageEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? MessageEvent

      return [
        matches_all(@attributes[:starting_with], event.content) { |a,e| e.start_with? a },
        matches_all(@attributes[:ending_with], event.content) { |a,e| e.end_with? a },
        matches_all(@attributes[:containing], event.content) { |a,e| e.include? a },
        matches_all(@attributes[:in], event.channel) do |a,e|
          if a.is_a? String
            a == e.name
          elsif a.is_a? Fixnum
            a == e.id
          else
            a == e
          end
        end,
        matches_all(@attributes[:from], event.author) do |a,e|
          if a.is_a? String
            a == e.name
          elsif a.is_a? Fixnum
            a == e.id
          else
            a == e
          end
        end,
        matches_all(@attributes[:with_text], event.content) { |a,e| e == a },
        matches_all(@attributes[:after], event.timestamp) { |a,e| a > e },
        matches_all(@attributes[:before], event.timestamp) { |a,e| a < e }
      ].reduce(true, &:&)
    end
  end
end
