require 'discordrb/events/generic'

module Discordrb::Events
  # @see Discordrb::EventContainer#ready
  class ReadyEvent < Event; end

  # Event handler for {ReadyEvent}
  class ReadyEventHandler < TrueEventHandler; end

  # @see Discordrb::EventContainer#disconnected
  class DisconnectEvent < Event; end

  # Event handler for {DisconnectEvent}
  class DisconnectEventHandler < TrueEventHandler; end
end
