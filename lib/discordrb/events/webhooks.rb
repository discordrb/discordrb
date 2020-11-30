# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Event raised when a webhook is updated
  class WebhookUpdateEvent < Event
    # @return [Server] the server where the webhook updated
    attr_reader :server

    # @return [Channel] the channel the webhook is associated to
    attr_reader :channel

    def initialize(data, bot)
      @bot = bot

      @server = bot.server(data['guild_id'].to_i)
      @channel = bot.channel(data['channel_id'].to_i)
    end
  end

  # Event handler for {WebhookUpdateEvent}
  class WebhookUpdateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? WebhookUpdateEvent

      [
        matches_all(@attributes[:server], event.server) do |a, e|
          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:channel], event.channel) do |a, e|
          case a
          when String
            # Make sure to remove the "#" from channel names in case it was specified
            a.delete('#') == e.name
          when Integer
            a == e.id
          else
            a == e
          end
        end,
        matches_all(@attributes[:webhook], event) do |a, e|
          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end
      ].reduce(true, &:&)
    end
  end
end
