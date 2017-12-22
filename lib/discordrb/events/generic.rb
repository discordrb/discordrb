# frozen_string_literal: true

# Events used by discordrb
module Discordrb::Events
  # A negated object, used to not match something in event parameters.
  # @see Discordrb::Events.matches_all
  class Negated
    attr_reader :object

    def initialize(object)
      @object = object
    end
  end

  # Attempts to match possible formats of event attributes to a set comparison value, using a comparison block.
  # It allows five kinds of attribute formats:
  #  0. nil -> always returns true
  #  1. A single attribute, not negated
  #  2. A single attribute, negated
  #  3. An array of attributes, not negated
  #  4. An array of attributes, not negated
  # Note that it doesn't allow an array of negated attributes. For info on negation stuff, see {::#not!}
  # @param attributes [Object, Array<Object>, Negated<Object>, Negated<Array<Object>>, nil] One or more attributes to
  #   compare to the to_check value.
  # @param to_check [Object] What to compare the attributes to.
  # @yield [a, e] The block will be called when a comparison happens.
  # @yieldparam [Object] a The attribute to compare to the value to check. Will always be a single not-negated object,
  #   all the negation and array handling is done by the method
  # @yieldparam [Object] e The value to compare the attribute to. Will always be the value passed to the function as
  #   to_check.
  # @yieldreturn [true, false] Whether or not the attribute a matches the given comparison value e.
  # @return [true, false] whether the attributes match the comparison value in at least one way.
  def self.matches_all(attributes, to_check, &block)
    # "Zeroth" case: attributes is nil
    return true if attributes.nil?

    # First case: there's a single negated attribute
    if attributes.is_a? Negated
      # The contained object might also be an array, so recursively call matches_all (and negate the result)
      return !matches_all(attributes.object, to_check, &block)
    end

    # Second case: there's a single, not-negated attribute
    return yield(attributes, to_check) unless attributes.is_a? Array

    # Third case: it's an array of attributes
    attributes.reduce(false) do |result, element|
      result || yield(element, to_check)
    end
  end

  # Generic event class that can be extended
  class Event
    # @return [Bot] the bot used to initialize this event.
    attr_reader :bot

    class << self
      protected

      # Delegates a list of methods to a particular object. This is essentially a reimplementation of ActiveSupport's
      # `#delegate`, but without the overhead provided by the rest. Used in subclasses of `Event` to delegate properties
      # on events to properties on data objects.
      # @param methods [Array<Symbol>] The methods to delegate.
      # @param hash [Hash<Symbol => Symbol>] A hash with one `:to` key and the value the method to be delegated to.
      def delegate(*methods, hash)
        methods.each do |e|
          define_method(e) do
            object = __send__(hash[:to])
            object.__send__(e)
          end
        end
      end
    end
  end

  # Generic event handler that can be extended
  class EventHandler
    def initialize(attributes, block)
      @attributes = attributes
      @block = block
    end

    # Whether or not this event handler matches the given event with its attributes.
    # @raise [RuntimeError] if this method is called - overwrite it in your event handler!
    def matches?(_)
      raise 'Attempted to call matches?() from a generic EventHandler'
    end

    # Checks whether this handler matches the given event, and then calls it.
    # @param event [Object] The event object to match and call the handler with
    def match(event)
      call(event) if matches? event
    end

    # Calls this handler
    # @param event [Object] The event object to call this handler with
    def call(event)
      @block.call(event)
    end

    # to be overwritten by extending event handlers
    def after_call(event); end

    # @see Discordrb::Events::matches_all
    def matches_all(attributes, to_check, &block)
      Discordrb::Events.matches_all(attributes, to_check, &block)
    end
  end

  # Event handler that matches all events. Only useful for making an event that has no attributes, such as {ReadyEvent}.
  class TrueEventHandler < EventHandler
    # Always returns true.
    # @return [true]
    def matches?(_)
      true
    end
  end
end

# Utility function that creates a negated object for {Discordrb::Events.matches_all}
# @param [Object] object The object to negate
# @see Discordrb::Events::Negated
# @see Discordrb::Events.matches_all
# @return [Negated<Object>] the object, negated, as an attribute to pass to matches_all
def not!(object)
  Discordrb::Events::Negated.new(object)
end
