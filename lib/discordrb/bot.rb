require 'rest-client'
require 'faye/websocket'
require 'eventmachine'

require 'discordrb/endpoints/endpoints'

require 'discordrb/events/message'
require 'discordrb/events/typing'
require 'discordrb/events/lifetime'
require 'discordrb/events/presence'
require 'discordrb/events/voice-state-update'
require 'discordrb/events/channel-create'
require 'discordrb/events/channel-update'
require 'discordrb/events/channel-delete'

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

      while true do
        websocket_connect
        debug("Disconnected! Attempting to reconnect in 5 seconds.")
        sleep 5
        @token = login
      end
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

      data = {
        'recipient_id' => id
      }

      response = RestClient.post Discordrb::Endpoints::USERS + "/#{@bot_user.id}/channels", data.to_json, {:Authorization => @token, :content_type => :json}
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
        'content' => content.to_s,
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
    
    # Handle channel creation
    # Attributes:
    # * type: Channel type ('text' or 'voice')
    # * name: Channel name
    def channel_create(attributes = {}, &block)
      register_event(ChannelCreateEvent, attributes, block)
    end
    
    # Handle channel update
    # Attributes:
    # * type: Channel type ('text' or 'voice')
    # * name: Channel name
    def channel_update(attributes = {}, &block)
      register_event(ChannelUpdateEvent, attributes, block)
    end
    
    # Handle channel deletion
    # Attributes:
    # * type: Channel type ('text' or 'voice')
    # * name: Channel name
    def channel_delete(attributes = {}, &block)
      register_event(ChannelDeleteEvent, attributes, block)
    end
    
    # Handle a change to a voice state.
    # This includes joining a voice channel or changing mute or deaf state.
    # Attributes:
    # * from: User whose voice state changed
    # * mute: server mute status
    # * deaf: server deaf status
    # * self_mute: self mute status
    # * self_deaf: self deaf status
    # * channel: channel the user joined
    def voice_state_update(attributes = {}, &block)
      register_event(VoiceStateUpdateEvent, attributes, block)
    end

    def remove_handler(handler)
      clazz = event_class(handler.class)
      @event_handlers[clazz].delete(handler)
    end

    def add_handler(handler)
      clazz = event_class(handler.class)
      @event_handlers[clazz] << handler
    end

    alias_method :<<, :add_handler

    private
    
    # Internal handler for PRESENCE_UPDATE
    def presence_update(data)
      user_id = data['user']['id'].to_i
      server_id = data['guild_id'].to_i
      server = @servers[server_id]
      return if !server
      
      user = server.members.find {|u| u.id == user_id}
      if !user
        user = User.new(data['user'], self)
      end
      
      status = data['status'].to_sym
      if status != :offline
        if !(server.members.find {|u| u.id == user.id })
          server.members << user
        end
      end
      user.status = status
      user.game_id = data['game_id']
    end
    
    # Internal handler for VOICE_STATUS_UPDATE
    def voice_state_update(data)
      user_id = data['user_id'].to_i
      server_id = data['guild_id'].to_i
      server = @servers[server_id]
      return if !server
      
      user = server.members.find {|u| u.id == user_id }
      user.server_mute = data['mute']
      user.server_deaf = data['deaf']
      user.self_mute = data['self_mute']
      user.self_deaf = data['self_deaf']
      
      channel_id = data['channel_id']
      channel = nil
      if channel_id
        channel = server.channels.find {|c| c.id == channel_id.to_i }
      end
      user.move(channel)
    end
    
    # Internal handler for CHANNEL_CREATE
    def channel_create(data)
      channel = Channel.new(data, self)
      server = channel.server
      server.channels << channel if channel
    end
    
    # Internal handler for CHANNEL_UPDATE
    def channel_update(data)
      channel = Channel.new(data, self)
      server = channel.server
      old_channel = server.channels.find {|chan| chan.id == channel.id }
      return if !old_channel
      old_channel.update_from(channel)
    end
    
    # Internal handler for CHANNEL_DELETE
    def channel_delete(data)
      channel = Channel.new(data, self)
      server = channel.server
      server.channels.reject! {|chan| chan.id == channel.id }
    end

    def debug(message)
      puts "[DEBUG @ #{Time.now.to_s}] #{message}" if @debug
    end

    def login
      debug("Logging in")
      login_attempts = login_attempts || 0

      # Login
      login_response = RestClient.post Discordrb::Endpoints::LOGIN, :email => @email, :password => @password
      raise HTTPStatusException.new(login_response.code) if login_response.code >= 400

      # Parse response
      login_response_object = JSON.parse(login_response)
      raise InvalidAuthenticationException unless login_response_object['token']

      debug("Received token: #{login_response_object['token']}")
      login_response_object['token']
    rescue Exception => e
      response_code = login_response.nil? ? 0 : login_response.code ######## mackmm145
      if login_attempts < 100 && (e.inspect.include?("No such host is known.") || response_code == 523)
        debug("Login failed! Reattempting in 5 seconds. #{100 - login_attempts} attempts remaining.")
        debug("Error was: #{e.inspect}")
        sleep 5
        login_attempts += 1
        retry
      else
        debug("Login failed permanently after #{login_attempts + 1} attempts")

        # Apparently we get a 400 if the password or username is incorrect. In that case, tell the user
        debug("Are you sure you're using the correct username and password?") if e.class == RestClient::BadRequest
        raise $!
      end
    end

    def get_gateway
      # Get updated websocket_hub
      response = RestClient.get Discordrb::Endpoints::GATEWAY, :authorization => @token
      JSON.parse(response)["url"]
    end

    def websocket_connect
      debug("Attempting to get gateway URL...")
      websocket_hub = get_gateway
      debug("Success! Gateway URL is #{websocket_hub}.")
      debug("Now running bot")

      EM.run {
        @ws = Faye::WebSocket::Client.new(websocket_hub)

        @ws.on :open do |event|; websocket_open(event); end
        @ws.on :message do |event|; websocket_message(event); end
        @ws.on :error do |event|; debug(event.message); end
        @ws.on :close do |event|; websocket_close(event); @ws = nil; end
      }
    end

    def websocket_message(event)
      begin
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
        presence_update(data)
        event = PresenceEvent.new(data, self)
        raise_event(event)
      when "VOICE_STATE_UPDATE"
        voice_state_update(data)
        event = VoiceStateUpdateEvent.new(data, self)
        raise_event(event)
      when "CHANNEL_CREATE"
        channel_create(data)
        event = ChannelCreateEvent.new(data, self)
        raise_event(event)
      when "CHANNEL_UPDATE"
        channel_update(data)
        event = ChannelUpdateEvent.new(data, self)
        raise_event(event)
      when "CHANNEL_DELETE"
        channel_delete(data)
        event = ChannelDeleteEvent.new(data, self)
        raise_event(event)
      end
      rescue Exception => e
        debug("Exception: #{e.inspect}")
        e.backtrace.each {|line| debug(line) }
      end
    end

    def websocket_close(event)
      debug("Disconnected from WebSocket!")
      debug(" (Reason: #{event.reason})")
      debug(" (Code: #{event.code})")
      raise_event(DisconnectEvent.new)
      EM.stop
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
            "$browser" => "",
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
