module Discordrb::Events
  # An event only associated with an ID and no further information.
  class IDEvent
    # @return [Integer] the ID associated with this event
    attr_reader :id

    # @!visibility private
    def initialize(id, bot)
      @id = id
      @bot = bot
    end
  end

  # Event handler for {IDEvent}
  class IDEventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? IDEvent

      matches_all(@attributes[:id], event.id) do |a, e|
        a.resolve_id == e.resolve_id
      end
    end
  end
end