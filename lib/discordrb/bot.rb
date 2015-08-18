require 'rest-client'
require 'faye/websocket'
require 'eventmachine'

require 'discordrb/endpoints/endpoints'

require 'discordrb/exceptions'

module Discordrb
  class Bot
    def initialize(email, password)
      @email = email
      @password = password

      @token = login()
      websocket_connect()
    end

    private

    def login
      # Login
      login_response = RestClient.post Discordrb::Endpoints::LOGIN, :email => @email, :password => @password
      raise HTTPStatusException.new(login_response.code) if login_response.code >= 400

      # Parse response
      login_response_object = JSON.parse(login_response)
      raise InvalidAuthenticationException unless login_response_object[token]

      login_response_object[token]
    end

    def websocket_connect
      EM.run {
        @ws = Faye::WebSocket::Client.new(Discordrb::Endpoints::WEBSOCKET_HUB)

        @ws.on :open do |event|; websocket_message(event); end
        @ws.on :message do |event|; websocket_message(event); end

        @ws.on :close do |event|
          websocket_close(event)
          @ws = nil
        end
      }
    end

    def websocket_message(event)
    end

    def websocket_close(event)
    end

    def websocket_open(event)
    end
  end
end
