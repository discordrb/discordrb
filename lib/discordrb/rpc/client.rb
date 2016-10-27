require 'discordrb/websocket'

module Discordrb::RPC
  # Client for Discord's RPC protocol.
  class Client
    def initialize(client_id, origin)
      @client_id = client_id
      @origin = origin
    end

    def connect
      url = "wss://discordapp.io:6463/?v=1&client_id=#{@client_id}"

      headers = {
        origin: @origin
      }

      @ws = Discordrb::WebSocket.new(
        url,
        method(:websocket_open),
        method(:websocket_message),
        proc { |e| Discordrb::LOGGER.error "RPCWS error: #{e}" },
        proc { |e| Discordrb::LOGGER.warn "RPCWS close: #{e}" },
        headers: headers
      )
    end

    def websocket_open
      Discordrb::LOGGER.info 'RPCWS opened'
    end

    def websocket_message(msg)
      Discordrb::LOGGER.info "RPCWS message: #{msg}"
    end
  end
end
