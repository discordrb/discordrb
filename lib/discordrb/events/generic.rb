require 'discordrb/events/utility'

module Discordrb::Events
  class EventHandler
    include Discordrb::Events::Utility
    def initialize(attributes, block)
      @attributes = attributes
      @block = block
    end

    def matches?(event)
      raise "Attempted to call matches?() from a generic EventHandler"
    end

    def match(event)
      @block.call(event) if matches? event
    end
  end

  # Event handler that matches all events
  class TrueEventHandler < EventHandler
    def matches?(event)
      true
    end
  end
end
