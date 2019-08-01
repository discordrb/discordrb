# frozen_string_literal: true

require 'discordrb/events/generic'

# Event classes and handlers
module Discordrb::Events
  # Event raised when any dispatch is received
  class RawEvent < Event
    # @return [Symbol] the type of this dispatch.
    attr_reader :type
    alias_method :t, :type

    # @return [Hash] the data of this dispatch.
    attr_reader :data
    alias_method :d, :data

    def initialize(type, data, bot)
      @type = type
      @data = data
      @bot = bot
    end
  end

  # Event handler for {RawEvent}
  class RawEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? RawEvent

      [
        matches_all(@attributes[:type] || @attributes[:t], event.type) do |a, e|
          if a.is_a? Regexp
            a.match?(e)
          else
            e.to_s.casecmp(a.to_s).zero?
          end
        end
      ].reduce(true, &:&)
    end
  end

  # Event raised when an unknown dispatch is received
  class UnknownEvent < RawEvent; end

  # Event handler for {UnknownEvent}
  class UnknownEventHandler < RawEventHandler; end
end
