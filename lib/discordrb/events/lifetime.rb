# frozen_string_literal: true

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

  # @see Discordrb::EventContainer#heartbeat
  class HeartbeatEvent < LifetimeEvent; end

  # Event handler for {HeartbeatEvent}
  class HeartbeatEventHandler < TrueEventHandler; end
end
