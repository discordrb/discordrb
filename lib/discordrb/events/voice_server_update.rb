# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Event raised when a server's voice server is updating.
  # Sent when initially connecting to voice and when a voice instance fails
  # over to a new server.
  # This event is exposed for use with library agnostic interfaces like telecom and
  # lavalink.
  class VoiceServerUpdateEvent < Event
    # @return [String] The voice connection token
    attr_reader :token

    # @return [Server] The server this update is for.
    attr_reader :server

    # @return [String] The voice server host.
    attr_reader :endpoint

    def initialize(data, bot)
      @bot = bot

      @token = data['token']
      @endpoint = data['endpoint']
      @server = bot.server(data['guild_id'])
    end
  end

  # Event handler for VoiceServerUpdateEvent
  class VoiceServerUpdateEventHandler < EventHandler
    def matches?(event)
      return false unless event.is_a? VoiceServerUpdateEvent

      [
        matches_all(@attributes[:from], event.server) do |a, e|
          a == if a.is_a? String
                 e.name
               else
                 e
               end
        end
      ]
    end
  end
end
