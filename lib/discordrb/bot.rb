require 'rest-client'
require 'faye/websocket'
require 'eventmachine'

require 'discordrb/endpoints/endpoints'

require 'discordrb/events/message'

require 'discordrb/exceptions'
require 'discordrb/data'

module Discordrb
  class Bot
    def initialize(email, password)
      @email = email
      @password = password

      @token = login()
      websocket_connect()

      @event_handlers = {}
    end

    def message(attributes = {}, &block)
      @event_handlers[MessageEvent] ||= []
      @event_handlers[MessageEvent] << MessageEventHandler.new(attributes, block)
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
        # Handle heartbeats
        @heartbeat_interval = data['heartbeat_interval'].to_f / 1000.0
        setup_heartbeat

        # Initialize the bot user
        @bot_user = User.new(data['user'], self)

        # Initialize servers
        @servers = {}
        data['guilds'].each do |element|
          server = Server.new(element, self)
          @servers[server.id] = server
        end
      when "MESSAGE_CREATE"
        message = Message.new(data, self)
        event = MessageEvent.new(message)
        raise_event(event)
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

    def raise_event(event)
      handlers = @event_handlers[event.class]
      handlers.each do |handler|
        handler.match(event)
      end
    end

    def setup_heartbeat
      Thread.new do
        loop do
          send_heartbeat
          sleep @heartbeat_interval
        end
      end
    end

    def send_heartbeat
      # TODO
    end
  end
end
