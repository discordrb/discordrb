require 'rest-client'
require 'faye/websocket'
require 'eventmachine'

require 'discordrb/events/message'
require 'discordrb/events/typing'
require 'discordrb/events/lifetime'
require 'discordrb/events/presence'
require 'discordrb/events/voice_state_update'
require 'discordrb/events/channel_create'
require 'discordrb/events/channel_update'
require 'discordrb/events/channel_delete'
require 'discordrb/events/members'
require 'discordrb/events/guild_role_create'
require 'discordrb/events/guild_role_delete'
require 'discordrb/events/guild_role_update'

require 'discordrb/api'
require 'discordrb/games'
require 'discordrb/exceptions'
require 'discordrb/data'

module Discordrb
  # Represents a Discord bot, including servers, users, etc.
  class Bot
    include Discordrb::Events

    attr_reader :bot_user, :token, :users, :servers

    def initialize(email, password, debug = false)
      # Make sure people replace the login details in the example files...
      if email.end_with? 'example.com'
        puts 'You have to replace the login details in the example files with your own!'
        exit
      end

      @debug = debug

      @email = email
      @password = password

      @token = login

      @event_handlers = {}

      @channels = {}
      @users = {}

      @awaits = {}
    end

    def run(async = false)
      run_async
      return if async

      debug('Oh wait! Not exiting yet as run was run synchronously.')
      sync
    end

    def run_async
      # Handle heartbeats
      @heartbeat_interval = 1
      @heartbeat_active = false
      @heartbeat_thread = Thread.new do
        loop do
          sleep @heartbeat_interval
          send_heartbeat if @heartbeat_active
        end
      end

      @ws_thread = Thread.new do
        loop do
          websocket_connect
          debug('Disconnected! Attempting to reconnect in 5 seconds.')
          sleep 5
          @token = login
        end
      end

      debug('WS thread created! Now waiting for confirmation that everything worked')
      @ws_success = false
      sleep(0.5) until @ws_success
      debug('Confirmation received! Exiting run.')
    end

    def sync
      @ws_thread.join
    end

    def stop
      @ws_thread.kill
    end

    def channel(id)
      debug("Obtaining data for channel with id #{id}")
      return @channels[id] if @channels[id]

      response = API.channel(@token, id)
      channel = Channel.new(JSON.parse(response), self)
      @channels[id] = channel
    end

    def private_channel(id)
      debug("Creating private channel with user id #{id}")
      return @private_channels[id] if @private_channels[id]

      response = API.create_private(@token, @bot_user.id, id)
      channel = Channel.new(JSON.parse(response), self)
      @private_channels[id] = channel
    end

    def join(invite)
      invite = invite[invite.rindex('/') + 1..-1] if invite.start_with?('http') || invite.start_with?('discord.gg')
      resolved = JSON.parse(API.resolve_invite(@token, invite))['code']
      API.join_server(@token, resolved)
    end

    def user(id)
      @users[id]
    end

    def server(id)
      @servers[id]
    end

    def find(channel_name, server_name = nil, threshold = 0)
      require 'levenshtein'

      results = []
      @servers.values.each do |server|
        server.channels.each do |channel|
          distance = Levenshtein.distance(channel.name, channel_name)
          distance += Levenshtein.distance(server_name || server.name, server.name)
          next if distance > threshold

          # Make a singleton accessor "distance"
          channel.instance_variable_set(:@distance, distance)
          class << channel
            attr_reader :distance
          end
          results << channel
        end
      end
      results
    end

    def send_message(channel_id, content)
      debug("Sending message to #{channel_id} with content '#{content}'")
      response = API.send_message(@token, channel_id, content)
      Message.new(JSON.parse(response), self)
    end

    def send_file(channel_id, file)
      API.send_file(@token, channel_id, file)
    end

    def add_await(key, type, attributes, &block)
      await = Await.new(self, key, type, attributes, block)
      @awaits << await
    end

    def parse_mention(mention)
      # Mention format: <@id>
      return nil unless /\<@(?<id>\d+)\>?/ =~ mention
      user(id)
    end

    def game=(name_or_id)
      game = Discordrb::Games.find_game(name_or_id)
      @game = game

      data = {
        'op' => 3,
        'd' => {
          'idle_since' => nil,
          'game_id' => game ? game.id : 60 # 60 blanks out the game playing
        }
      }

      @ws.send(data.to_json)
      game
    end

    attr_writer :debug

    ##     ##    ###    ##    ## ########  ##       ######## ########   ######
    ##     ##   ## ##   ###   ## ##     ## ##       ##       ##     ## ##    ##
    ##     ##  ##   ##  ####  ## ##     ## ##       ##       ##     ## ##
    ######### ##     ## ## ## ## ##     ## ##       ######   ########   ######
    ##     ## ######### ##  #### ##     ## ##       ##       ##   ##         ##
    ##     ## ##     ## ##   ### ##     ## ##       ##       ##    ##  ##    ##
    ##     ## ##     ## ##    ## ########  ######## ######## ##     ##  ######

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

    def member_join(attributes = {}, &block)
      register_event(GuildMemberAddEvent, attributes, block)
    end

    def member_update(attributes = {}, &block)
      register_event(GuildMemberUpdateEvent, attributes, block)
    end

    def member_leave(attributes = {}, &block)
      register_event(GuildMemberDeleteEvent, attributes, block)
    end

    def remove_handler(handler)
      clazz = event_class(handler.class)
      @event_handlers[clazz].delete(handler)
    end

    def add_handler(handler)
      clazz = event_class(handler.class)
      @event_handlers[clazz] << handler
    end

    def debug(message, important = false)
      puts "[DEBUG @ #{Time.now}] #{message}" if @debug || important
    end

    def handler_class(event_class)
      class_from_string(event_class.to_s + 'Handler')
    end

    alias_method :<<, :add_handler

    private

    ### ##    ## ######## ######## ########  ##    ##    ###    ##        ######
    ##  ###   ##    ##    ##       ##     ## ###   ##   ## ##   ##       ##    ##
    ##  ####  ##    ##    ##       ##     ## ####  ##  ##   ##  ##       ##
    ##  ## ## ##    ##    ######   ########  ## ## ## ##     ## ##        ######
    ##  ##  ####    ##    ##       ##   ##   ##  #### ######### ##             ##
    ##  ##   ###    ##    ##       ##    ##  ##   ### ##     ## ##       ##    ##
    ### ##    ##    ##    ######## ##     ## ##    ## ##     ## ########  ######

    # Internal handler for PRESENCE_UPDATE
    def update_presence(data)
      user_id = data['user']['id'].to_i
      server_id = data['guild_id'].to_i
      server = @servers[server_id]
      return unless server

      user = @users[user_id]
      unless user
        user = User.new(data['user'], self)
        @users[user_id] = user
      end

      status = data['status'].to_sym
      if status != :offline
        unless server.members.find { |u| u.id == user.id }
          server.members << user
        end
      end
      user.status = status
      user.game = Discordrb::Games.find_game(data['game_id'])
      user
    end

    # Internal handler for VOICE_STATUS_UPDATE
    def update_voice_state(data)
      user_id = data['user_id'].to_i
      server_id = data['guild_id'].to_i
      server = @servers[server_id]
      return unless server

      user = @users[user_id]
      user.server_mute = data['mute']
      user.server_deaf = data['deaf']
      user.self_mute = data['self_mute']
      user.self_deaf = data['self_deaf']

      channel_id = data['channel_id']
      channel = nil
      channel = @channels[channel_id.to_i] if channel_id
      user.move(channel)
    end

    # Internal handler for CHANNEL_CREATE
    def create_channel(data)
      channel = Channel.new(data, self)
      server = channel.server
      server.channels << channel
      @channels[channel.id] = channel
    end

    # Internal handler for CHANNEL_UPDATE
    def update_channel(data)
      channel = Channel.new(data, self)
      old_channel = @channels[channel.id]
      return unless old_channel
      old_channel.update_from(channel)
    end

    # Internal handler for CHANNEL_DELETE
    def delete_channel(data)
      channel = Channel.new(data, self)
      server = channel.server
      @channels[channel.id] = nil
      server.channels.reject! { |c| c.id == channel.id }
    end

    # Internal handler for GUILD_MEMBER_ADD
    def add_guild_member(data)
      user = User.new(data['user'], self)
      server_id = data['guild_id'].to_i
      server = @servers[server_id]

      roles = []
      data['roles'].each do |element|
        role_id = element.to_i
        roles << server.roles.find { |r| r.id == role_id }
      end
      user.update_roles(server, roles)

      if @users[user.id]
        # If the user is already cached, just add the new roles
        @users[user.id].merge_roles(server, user.roles[server.id])
      else
        @users[user.id] = user
      end

      server.add_user(user)
    end

    # Internal handler for GUILD_MEMBER_UPDATE
    def update_guild_member(data)
      user_id = data['user']['id'].to_i
      user = @users[user_id]

      server_id = data['guild_id'].to_i
      server = @servers[server_id]

      roles = []
      data['roles'].each do |element|
        role_id = element.to_i
        roles << server.roles.find { |r| r.id == role_id }
      end
      user.update_roles(server, roles)
    end

    # Internal handler for GUILD_MEMBER_DELETE
    def delete_guild_member(data)
      user_id = data['user']['id'].to_i
      user = @users[user_id]

      server_id = data['guild_id'].to_i
      server = @servers[server_id]

      user.delete_roles(server_id)
      server.delete_user(user_id)
    end

    # Internal handler for GUILD_ROLE_UPDATE
    def update_guild_role(data)
      role_data = data['role']
      server_id = data['guild_id'].to_i
      server = @servers[server_id]
      new_role = Role.new(role_data, self, server)
      role_id = role_data['id'].to_i
      old_role = server.roles.find { |r| r.id == role_id }
      old_role.update_from(new_role)
    end

    # Internal handler for GUILD_ROLE_CREATE
    def create_guild_role(data)
      role_data = data['role']
      server_id = data['guild_id'].to_i
      server = @servers[server_id]
      new_role = Role.new(role_data, self, server)
      server.add_role(new_role)
    end

    # Internal handler for GUILD_ROLE_DELETE
    def delete_guild_role(data)
      role_data = data['role']
      role_id = role_data['id'].to_i
      server_id = data['guild_id'].to_i
      server = @servers[server_id]
      server.delete_role(role_id)
    end

    # Internal handler for MESSAGE_CREATE
    def create_message(data); end

    # Internal handler for TYPING_START
    def start_typing(data); end

    ##        #######   ######   #### ##    ##
    ##       ##     ## ##    ##   ##  ###   ##
    ##       ##     ## ##         ##  ####  ##
    ##       ##     ## ##   ####  ##  ## ## ##
    ##       ##     ## ##    ##   ##  ##  ####
    ##       ##     ## ##    ##   ##  ##   ###
    ########  #######   ######   #### ##    ##

    def login
      debug('Logging in')
      login_attempts ||= 0

      # Login
      login_response = API.login(@email, @password)
      fail HTTPStatusException, login_response.code if login_response.code >= 400

      # Parse response
      login_response_object = JSON.parse(login_response)
      fail InvalidAuthenticationException unless login_response_object['token']

      debug("Received token: #{login_response_object['token']}")
      login_response_object['token']
    rescue Exception => e
      response_code = login_response.nil? ? 0 : login_response.code ######## mackmm145
      if login_attempts < 100 && (e.inspect.include?('No such host is known.') || response_code == 523)
        debug("Login failed! Reattempting in 5 seconds. #{100 - login_attempts} attempts remaining.")
        debug("Error was: #{e.inspect}")
        sleep 5
        login_attempts += 1
        retry
      else
        debug("Login failed permanently after #{login_attempts + 1} attempts")

        # Apparently we get a 400 if the password or username is incorrect. In that case, tell the user
        debug("Are you sure you're using the correct username and password?") if e.class == RestClient::BadRequest
        raise $ERROR_INFO
      end
    end

    def find_gateway
      # Get updated websocket_hub
      response = API.gateway(@token)
      JSON.parse(response)['url']
    end

    ##      ##  ######     ######## ##     ## ######## ##    ## ########  ######
    ##  ##  ## ##    ##    ##       ##     ## ##       ###   ##    ##    ##    ##
    ##  ##  ## ##          ##       ##     ## ##       ####  ##    ##    ##
    ##  ##  ##  ######     ######   ##     ## ######   ## ## ##    ##     ######
    ##  ##  ##       ##    ##        ##   ##  ##       ##  ####    ##          ##
    ##  ##  ## ##    ##    ##         ## ##   ##       ##   ###    ##    ##    ##
    ####  ###   ######     ########    ###    ######## ##    ##    ##     ######

    def websocket_connect
      debug('Attempting to get gateway URL...')
      websocket_hub = find_gateway
      debug("Success! Gateway URL is #{websocket_hub}.")
      debug('Now running bot')

      EM.run do
        @ws = Faye::WebSocket::Client.new(websocket_hub)

        @ws.on(:open) { |event| websocket_open(event) }
        @ws.on(:message) { |event| websocket_message(event) }
        @ws.on(:error) { |event| debug(event.message) }
        @ws.on :close do |event|
          websocket_close(event)
          @ws = nil
        end
      end
    end

    def websocket_message(event)
      debug("Received packet #{event.data}")

      # Parse packet
      packet = JSON.parse(event.data)

      fail 'Invalid Packet' unless packet['op'] == 0 # TODO

      data = packet['d']
      case packet['t']
      when 'READY'
        # Activate the heartbeats
        @heartbeat_interval = data['heartbeat_interval'].to_f / 1000.0
        @heartbeat_active = true
        debug("Desired heartbeat_interval: #{@heartbeat_interval}")

        bot_user_id = data['user']['id'].to_i

        # Initialize servers
        @servers = {}
        data['guilds'].each do |element|
          server = Server.new(element, self)
          @servers[server.id] = server

          # Initialize users
          server.members.each do |member|
            if @users[member.id]
              # If the user is already cached, just add the new roles
              @users[member.id].merge_roles(server, member.roles[server.id])
            else
              @users[member.id] = member
            end
          end

          # Save the bot user
          @bot_user = @users[bot_user_id]
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

        # Tell the run method that everything was successful
        @ws_success = true
      when 'MESSAGE_CREATE'
        create_message(data)

        message = Message.new(data, self)
        event = MessageEvent.new(message, self)
        raise_event(event)

        if message.mentions.any? { |user| user.id == @bot_user.id }
          event = MentionEvent.new(message, self)
          raise_event(event)
        end
      when 'TYPING_START'
        start_typing(data)

        event = TypingEvent.new(data, self)
        raise_event(event)
      when 'PRESENCE_UPDATE'
        update_presence(data)

        event = PresenceEvent.new(data, self)
        raise_event(event)
      when 'VOICE_STATE_UPDATE'
        update_voice_state(data)

        event = VoiceStateUpdateEvent.new(data, self)
        raise_event(event)
      when 'CHANNEL_CREATE'
        create_channel(data)

        event = ChannelCreateEvent.new(data, self)
        raise_event(event)
      when 'CHANNEL_UPDATE'
        update_channel(data)

        event = ChannelUpdateEvent.new(data, self)
        raise_event(event)
      when 'CHANNEL_DELETE'
        delete_channel(data)

        event = ChannelDeleteEvent.new(data, self)
        raise_event(event)
      when 'GUILD_MEMBER_ADD'
        add_guild_member(data)

        event = GuildMemberAddEvent.new(data, self)
        raise_event(event)
      when 'GUILD_MEMBER_UPDATE'
        update_guild_member(data)

        event = GuildMemberUpdateEvent.new(data, self)
        raise_event(event)
      when 'GUILD_MEMBER_REMOVE'
        delete_guild_member(data)

        event = GuildMemberDeleteEvent.new(data, self)
        raise_event(event)
      when 'GUILD_ROLE_UPDATE'
        update_guild_role(data)

        event = GuildRoleUpdateEvent.new(data, self)
        raise_event(event)
      when 'GUILD_ROLE_CREATE'
        create_guild_role(data)

        event = GuildRoleCreateEvent.new(data, self)
        raise_event(event)
      when 'GUILD_ROLE_DELETE'
        delete_guild_role(data)

        event = GuildRoleDeleteEvent.new(data, self)
        raise_event(event)
      end
    rescue Exception => e
      debug("Exception: #{e.inspect}", true)
      e.backtrace.each { |line| debug(line) }
    end

    def websocket_close(event)
      debug('Disconnected from WebSocket!')
      debug(" (Reason: #{event.reason})")
      debug(" (Code: #{event.code})")
      raise_event(DisconnectEvent.new)
      EM.stop
    end

    def websocket_open(_)
      # Send the initial packet
      packet = {
        'op' => 2,    # Packet identifier
        'd' => {      # Packet data
          'v' => 2,   # Another identifier
          'token' => @token,
          'properties' => { # I'm unsure what these values are for exactly, but they don't appear to impact bot functionality in any way.
            '$os' => "#{RUBY_PLATFORM}",
            '$browser' => 'discordrb',
            '$device' => 'discordrb',
            '$referrer' => '',
            '$referring_domain' => ''
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
      millis = Time.now.strftime('%s%L').to_i
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
      return nil unless class_name.end_with? 'Handler'

      class_from_string(class_name[0..-8])
    end
  end
end
