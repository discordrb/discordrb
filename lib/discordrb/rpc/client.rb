require 'discordrb/websocket'

module Discordrb::RPC
  # Client for Discord's RPC protocol.
  class Client
    def initialize(client_id, origin)
      @client_id = client_id
      @origin = origin
    end

    def connect
      url = 'wss://discordapp.io:6463/?v=1'

      @ws = Discordrb::WebSocket.new(
        url,
        method(:websocket_open),
        method(:websocket_message),
        proc { |e| Discordrb::LOGGER.error "RPCWS error: #{e}" },
        proc { |e| Discordrb::LOGGER.warn "RPCWS close: #{e}" }
      )
    end
  end
end
