require 'json'

require 'discordrb/websocket'

module Discordrb::RPC
  # Client for Discord's RPC protocol.
  class Client
    attr_reader :ws

    def initialize(client_id, origin)
      @client_id = client_id
      @origin = origin
    end

    def run
      connect
    end

    def select_text_channel(id)
      send_frame(:SELECT_TEXT_CHANNEL, channel_id: id)
    end

    private

    def send_frame(command, payload, event = nil)
      frame = {
        cmd: command,
        args: payload,
        evt: event
      }

      data = frame.to_json
      Discordrb::LOGGER.debug("RPCWS send: #{data}")
      @ws.send(data)
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
      Discordrb::LOGGER.debug 'RPCWS opened'
    end

    def websocket_message(msg)
      Discordrb::LOGGER.debug "RPCWS message: #{msg}"
    end
  end
end
