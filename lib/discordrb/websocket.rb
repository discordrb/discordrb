require 'websocket-client-simple'

module Discordrb
  # Utility wrapper class that abstracts an instance of WSCS. Useful should we decide that WSCS isn't good either -
  # in that case we can just switch to something else
  class WebSocket
    attr_reader :open_handler, :message_handler, :close_handler, :error_handler

    def initialize(endpoint, open_handler, message_handler, close_handler, error_handler)
      @open_handler = open_handler
      @message_handler = message_handler
      @close_handler = close_handler
      @error_handler = error_handler

      instance = self # to work around WSCS's weird way of handling blocks

      @client = WebSocket::Client::Simple.connect(endpoint) do |ws|
        ws.on(:open) { instance.open_handler.call }
        ws.on(:message) { |msg| instance.message_handler.call(msg) }
        ws.on(:close) { |err| instance.close_handler.call(err) }
        ws.on(:error) { |err| instance.error_handler.call(err) }
      end
    end

    def send(data)
      @client.send(data)
    end
  end
end