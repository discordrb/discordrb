# frozen_string_literal: true

require 'discordrb/events/generic'

# Event classes and handlers
module Discordrb::Events
  # Event raised when any dispatch is received
  class RawEvent < Event
    # @return [Symbol] the type of this dispatch.
    attr_reader :type
    alias_method :t, :type

    # @return [Hash] the data of this dispatch.
    attr_reader :data
    alias_method :d, :data
  end
end
