# frozen_string_literal: true

require 'websocket-client-simple'

# The WSCS module which we're hooking
# @see Websocket::Client::Simple::Client
module WebSocket::Client::Simple
  # Patch to the WSCS class to allow reading the internal thread
  class Client
    # @return [Thread] the internal thread this client is using for the event loop.
    attr_reader :thread
  end
end

module Discordrb
  # Utility wrapper class that abstracts an instance of WSCS. Useful should we decide that WSCS isn't good either -
  # in that case we can just switch to something else
  class WebSocket
    attr_reader :open_handler, :message_handler, :close_handler, :error_handler

    # Create a new WebSocket and connect to the given endpoint.
    # @param endpoint [String] Where to connect to.
    # @param open_handler [#call] The handler that should be called when the websocket has opened successfully.
    # @param message_handler [#call] The handler that should be called when the websocket receives a message. The
    #   handler can take one parameter which will have a `data` attribute for normal messages and `code` and `data` for
    #   close frames.
    # @param close_handler [#call] The handler that should be called when the websocket is closed due to an internal
    #   error. The error will be passed as the first parameter to the handler.
    # @param error_handler [#call] The handler that should be called when an error occurs in another handler. The error
    #   will be passed as the first parameter to the handler.
    def initialize(endpoint, open_handler, message_handler, close_handler, error_handler)
      Discordrb::LOGGER.debug "Using WSCS version: #{::WebSocket::Client::Simple::VERSION}"

      @open_handler = open_handler
      @message_handler = message_handler
      @close_handler = close_handler
      @error_handler = error_handler

      instance = self # to work around WSCS's weird way of handling blocks

      @client = ::WebSocket::Client::Simple.connect(endpoint) do |ws|
        ws.on(:open) { instance.open_handler.call }
        ws.on(:message) do |msg|
          # If the message has a code attribute, it is in reality a close message
          if msg.code
            instance.close_handler.call(msg)
          else
            instance.message_handler.call(msg.data)
          end
        end
        ws.on(:close) { |err| instance.close_handler.call(err) }
        ws.on(:error) { |err| instance.error_handler.call(err) }
      end
    end

    # Send data over this WebSocket
    # @param data [String] What to send
    def send(data)
      @client.send(data)
    end

    # Close the WebSocket connection
    def close
      @client.close
    end

    # @return [Thread] the internal WSCS thread
    def thread
      @client.thread
    end
  end
end
