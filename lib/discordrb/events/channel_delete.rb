require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Raised when a channel is deleted
  class ChannelDeleteEvent
    attr_reader :type, :topic, :position, :name, :is_private, :id, :server

    def initialize(data, bot)
      @type = data['type']
      @topic = data['topic']
      @position = data['position']
      @name = data['name']
      @is_private = data['is_private']
      @id = data['id'].to_i
      @server = bot.server(data['guild_id'].to_i)
    end
  end

  # Event handler for ChannelDeleteEvent
  class ChannelDeleteEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ChannelDeleteEvent

      [
        matches_all(@attributes[:type], event.type) do |a, e|
          if a.is_a? String
            a == e.name
          else
            a == e
          end
        end,
        matches_all(@attributes[:name], event.name) do |a, e|
          if a.is_a? String
            a == e.to_s
          else
            a == e
          end
        end
      ].reduce(true, &:&)
    end
  end
end
