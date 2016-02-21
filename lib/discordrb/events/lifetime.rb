require 'discordrb/events/generic'

module Discordrb::Events
  # @see Discordrb::EventContainer#ready
  class ReadyEvent; end

  # Event handler for {ReadyEvent}
  class ReadyEventHandler < TrueEventHandler; end

  # @see Discordrb::EventContainer#disconnected
  class DisconnectEvent; end

  # Event handler for {DisconnectEvent}
  class DisconnectEventHandler < TrueEventHandler; end
end
