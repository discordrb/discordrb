require 'discordrb/events/generic'

module Discordrb::Events
  # Common superclass for all lifetime events
  class LifetimeEvent < Event
    # @!visibility private
    def initialize(bot)
      @bot = bot
    end
  end

  # @see Discordrb::EventContainer#ready
  class ReadyEvent < LifetimeEvent; end

  # Event handler for {ReadyEvent}
  class ReadyEventHandler < TrueEventHandler; end

  # @see Discordrb::EventContainer#disconnected
  class DisconnectEvent < LifetimeEvent; end

  # Event handler for {DisconnectEvent}
  class DisconnectEventHandler < TrueEventHandler; end
end
