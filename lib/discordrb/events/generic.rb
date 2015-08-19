require 'discordrb/events/utility'

def not(object)
  Negated.new(object)
end

module Discordrb::Events
  class Negated
    attr_reader :object
    def initialize(object); @object = object; end
  end

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
