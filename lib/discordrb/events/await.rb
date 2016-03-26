# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/await'

module Discordrb::Events
  # @see Bot#await
  class AwaitEvent < Event
    # The await that was triggered.
    # @return [Await] The await
    attr_reader :await

    # The event that triggered the await.
    # @return [Event] The event
    attr_reader :event

    # @!attribute [r] key
    #   @return [Symbol] the await's key.
    #   @see Await#key
    # @!attribute [r] type
    #   @return [Class] the await's event class.
    #   @see Await#type
    # @!attribute [r] attributes
    #   @return [Hash] a hash of attributes defined on the await.
    #   @see Await#attributes
    delegate :key, :type, :attributes, to: :await

    # For internal use only
    def initialize(await, event, bot)
      @await = await
      @event = event
      @bot = bot
    end
  end

  # Event handler for {AwaitEvent}
  class AwaitEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? AwaitEvent

      [
        matches_all(@attributes[:key], event.key) { |a, e| a == e },
        matches_all(@attributes[:type], event.type) { |a, e| a == e }
      ].reduce(true, &:&)
    end
  end
end
