require 'discordrb/events/utility'

def not!(object)
  Negated.new(object)
end

module Discordrb::Events
  class Negated
    attr_reader :object
    def initialize(object); @object = object; end
  end

  def matches_all(attributes, to_check, &block)
    # "Zeroth" case: attributes is nil
    return true unless attributes

    # First case: there's only a single attribute
    unless attributes.is_a? Array
      return yield(attributes, to_check)
    end

    # Second case: it's an array of attributes
    attributes.reduce(false) { |result, element| result || yield(element, to_check) }
  end

  class EventHandler
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
