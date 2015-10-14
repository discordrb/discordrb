require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  class ChannelUpdateEvent
    attr_reader :type
    attr_reader :topic
    attr_reader :position
    attr_reader :name
    attr_reader :is_private
    attr_reader :channel
    attr_reader :server

    def initialize(data, bot)
      @type = data['type']
      @topic = data['topic']
      @position = data['position']
      @name = data['name']
      @is_private = data['is_private']
      @server = bot.server(data['guild_id'].to_i)
      return if !@server
      @channel = @server.channels.find {|channel| channel.id == data['id'].to_i }
    end
  end

  class ChannelUpdateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? VoiceStateUpdateEvent

      return [
        matches_all(@attributes[:type], event.type) do |a,e|
          if a.is_a? String
            a == e.name
          else
            a == e
          end
        end,
        matches_all(@attributes[:name], event.name) do |a,e|
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
