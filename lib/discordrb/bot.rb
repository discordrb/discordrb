require 'rest-client'
require 'faye/websocket'
require 'eventmachine'

require 'discordrb/endpoints/endpoints'

require 'discordrb/exceptions'
require 'discordrb/data'

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
      raise InvalidAuthenticationException unless login_response_object['token']

      login_response_object['token']
    end

    def websocket_connect
      EM.run {
        @ws = Faye::WebSocket::Client.new(Discordrb::Endpoints::WEBSOCKET_HUB)

        @ws.on :open do |event|; websocket_open(event); end
        @ws.on :message do |event|; websocket_message(event); end

        @ws.on :close do |event|
          websocket_close(event)
          @ws = nil
        end
      }
    end

    def websocket_message(event)
      # Parse packet
      packet = JSON.parse(event.data)

      raise "Invalid Packet" unless packet['op'] == 0   # TODO

      data = packet['d']
      case packet['t']
      when "READY"
        initialize_bot(data)
        # TODO
      when "MESSAGE_CREATE"
        message = Message.new(data)
      end
    end

    def websocket_close(event)
    end

    def websocket_open(event)
      # Send the initial packet
      packet = {
        "op" => 2,    # Packet identifier
        "d" => {      # Packet data
          "v" => 2,   # Another identifier
          "token" => @token,
          "properties" => {   # I'm unsure what these values are for exactly, but they don't appear to impact bot functionality in any way.
            "$os" => "Linux",
            "$browser" => "Chrome",
            "$device" => "discordrb",
            "$referrer" => "",
            "$referring_domain" => ""
          }
        }
      }

      @ws.send(packet.to_json)
    end
  end
end
