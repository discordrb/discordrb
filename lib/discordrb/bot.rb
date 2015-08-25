require 'rest-client'
require 'faye/websocket'
require 'eventmachine'

require 'discordrb/endpoints/endpoints'

require 'discordrb/events/message'
require 'discordrb/events/typing'
require 'discordrb/events/lifetime'
require 'discordrb/events/presence'

require 'discordrb/exceptions'
require 'discordrb/data'

module Discordrb
  class Bot
    include Discordrb::Events
    def initialize(email, password, debug = false)
      @debug = debug

      @email = email
      @password = password

      @token = login

      @event_handlers = {}

      @channels = {}
      @users = {}
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

    def private_channel(id)
      debug("Creating private channel with user id #{id}")
      return @private_channels[id] if @private_channels[id]

      response = RestClient.get Discordrb::Endpoints::USERS + "/#{id}/channels", {:Authorization => @token}
      channel = Channel.new(JSON.parse(response), self)
      @private_channels[id] = channel
    end

    def user(id)
      @users[id]
    end

    def server(id)
      @servers[id]
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
      register_event(MessageEvent, attributes, block)
    end

    def ready(attributes = {}, &block)
      register_event(ReadyEvent, attributes, block)
    end

    def disconnected(attributes = {}, &block)
      register_event(DisconnectEvent, attributes, block)
    end

    def typing(attributes = {}, &block)
      register_event(TypingEvent, attributes, block)
    end

    def presence(attributes = {}, &block)
      register_event(PresenceEvent, attributes, block)
    end

    def mention(attributes = {}, &block)
      register_event(MentionEvent, attributes, block)
    end

    def remove_handler(handler)
      clazz = event_class(handler.class)
      @event_handlers[clazz].delete(handler)
    end

    def add_handler(handler)
      clazz = event_class(handler.class)
      @event_handlers[clazz] << handler
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

      debug("Received token: #{login_response_object['token']}")
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

          # Initialize users
          server.members.each do |element|
            @users[element.id] = element
          end
        end

        # Add private channels
        @private_channels = {}
        data['private_channels'].each do |element|
          channel = Channel.new(element, self)
          @channels[channel.id] = channel
          @private_channels[channel.recipient.id] = channel
        end

        # Make sure to raise the event
        raise_event(ReadyEvent.new)
      when "MESSAGE_CREATE"
        message = Message.new(data, self)
        event = MessageEvent.new(message, self)
        raise_event(event)

        if message.mentions.any? { |user| user.id == @bot_user.id }
          event = MentionEvent.new(message, self)
          raise_event(event)
        end
      when "TYPING_START"
        event = TypingEvent.new(data, self)
        raise_event(event)
      when "PRESENCE_UPDATE"
        event = PresenceEvent.new(data, self)
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
      (handlers || []).each do |handler|
        handler.match(event)
      end
    end

    def register_event(clazz, attributes, block)
      handler = handler_class(clazz).new(attributes, block)

      @event_handlers[clazz] ||= []
      @event_handlers[clazz] << handler

      # Return the handler so it can be removed later
      handler
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

    def class_from_string(str)
      str.split('::').inject(Object) do |mod, class_name|
        mod.const_get(class_name)
      end
    end

    def event_class(handler_class)
      class_name = handler_class.to_s
      return nil unless class_name.end_with? "Handler"

      class_from_string(class_name[0..-8])
    end

    def handler_class(event_class)
      class_from_string(event_class.to_s + "Handler")
    end
  end
end
