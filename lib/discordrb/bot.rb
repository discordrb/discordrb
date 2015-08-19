require 'rest-client'
require 'faye/websocket'
require 'eventmachine'

require 'discordrb/endpoints/endpoints'

require 'discordrb/events/message'
require 'discordrb/events/lifetime'

require 'discordrb/exceptions'
require 'discordrb/data'

module Discordrb
  class Bot
    include Discordrb::Events
    def initialize(email, password)
      @email = email
      @password = password

      @token = login

      @event_handlers = {}
      @channels = {}
      @debug = false
    end

    def run
      # Handle heartbeats
      @heartbeat_interval = 1
      @heartbeat_active = false
      @heartbeat_thread = Thread.new do
        while true do
          sleep @heartbeat_interval
          send_heartbeat if @heartbeat_active
        end
      end

      websocket_connect
    end

    def channel(id)
      debug("Obtaining data for channel with id #{id}")
      return @channels[id] if @channels[id]

      response = RestClient.get Discordrb::Endpoints::CHANNELS + "/#{id}", {:Authorization => @token}
      channel = Channel.new(JSON.parse(response), self)
      @channels[id] = channel
    end

    def send_message(channel_id, content)
      debug("Sending message to #{channel_id} with content '#{content}'")
      data = {
        'content' => content,
        'mentions' => []
      }

      RestClient.post Discordrb::Endpoints::CHANNELS + "/#{channel_id}/messages", data.to_json, {:Authorization => @token, :content_type => :json}
    end

    def debug=(debug)
      @debug = debug
    end

    def message(attributes = {}, &block)
      @event_handlers[MessageEvent] ||= []
      @event_handlers[MessageEvent] << MessageEventHandler.new(attributes, block)
    end

    def ready(attributes = {}, &block)
      @event_handlers[ReadyEvent] ||= []
      @event_handlers[ReadyEvent] << ReadyEventHandler.new(attributes, block)
    end

    def disconnected(attributes = {}, &block)
      @event_handlers[DisconnectEvent] ||= []
      @event_handlers[DisconnectEvent] << DisconnectEventHandler.new(attributes, block)
    end

    private

    def debug(message)
      puts "[DEBUG] #{message}" if @debug
    end

    def login
      debug("Logging in")
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
      debug("Received packet #{event.data}")

      # Parse packet
      packet = JSON.parse(event.data)

      raise "Invalid Packet" unless packet['op'] == 0   # TODO

      data = packet['d']
      case packet['t']
      when "READY"
        # Activate the heartbeats
        @heartbeat_interval = data['heartbeat_interval'].to_f / 1000.0
        @heartbeat_active = true
        debug("Desired heartbeat_interval: #{@heartbeat_interval}")

        # Initialize the bot user
        @bot_user = User.new(data['user'], self)

        # Initialize servers
        @servers = {}
        data['guilds'].each do |element|
          server = Server.new(element, self)
          @servers[server.id] = server
        end

        # Make sure to raise the event
        raise_event(ReadyEvent.new)
      when "MESSAGE_CREATE"
        message = Message.new(data, self)
        event = MessageEvent.new(message)
        raise_event(event)
      end
    end

    def websocket_close(event)
      raise_event(DisconnectEvent.new)
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
      debug("Raised a #{event.class}")
      handlers = @event_handlers[event.class]
      handlers.each do |handler|
        handler.match(event)
      end
    end

    def send_heartbeat
      millis = Time.now.strftime("%s%L").to_i
      debug("Sending heartbeat at #{millis}")
      data = {
        'op' => 1,
        'd' => millis
      }

      @ws.send(data.to_json)
    end
  end
end
