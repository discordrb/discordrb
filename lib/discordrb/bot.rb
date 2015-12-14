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
require 'discordrb/events/guilds'
require 'discordrb/events/await'

require 'discordrb/api'
require 'discordrb/games'
require 'discordrb/exceptions'
require 'discordrb/data'
require 'discordrb/await'

module Discordrb
  # Represents a Discord bot, including servers, users, etc.
  class Bot
    include Discordrb::Events

    # The user that represents the bot itself. This version will always be identical to
    # the user determined by {#user} called with the bot's ID.
    # @return [User] The bot user.
    attr_reader :bot_user

    # The Discord API token received when logging in. Useful to explicitly call
    # {API} methods.
    # @return [String] The API token.
    attr_reader :token

    # The list of users the bot shares a server with.
    # @return [Array<User>] The users.
    attr_reader :users

    # The list of servers the bot is currently in.
    # @return [Array<Server>] The servers.
    attr_reader :servers

    # The list of currently running threads used to parse and call events.
    # The threads will have a local variable `:discordrb_name` in the format of `et-1234`, where
    # "et" stands for "event thread" and the number is a continually incrementing number representing
    # how many events were executed before.
    # @return [Array<Thread>] The threads.
    attr_reader :event_threads

    # The bot's user profile. This special user object can be used
    # to edit user data like the current username (see {Profile#username=}).
    # @return [Profile] The bot's profile that can be used to edit data.
    attr_reader :profile

    # Whether or not the bot should parse its own messages. Off by default.
    attr_accessor :should_parse_self

    # Makes a new bot with the given email and password. It will be ready to be added event handlers to and can eventually be run with {#run}.
    # @param email [String] The email for your (or the bot's) Discord account.
    # @param password [String] The valid password that should be used to log in to the account.
    # @param debug [Boolean] Whether or not the bug should run in debug mode, which gives increased console output.
    def initialize(email, password, debug = false)
      # Make sure people replace the login details in the example files...
      if email.end_with? 'example.com'
        puts 'You have to replace the login details in the example files with your own!'
        exit
      end

      LOGGER.debug = debug
      @should_parse_self = false

      @email = email
      @password = password

      @token = login

      @event_handlers = {}

      @channels = {}
      @users = {}

      @awaits = {}

      @event_threads = []
      @current_thread = 0
    end

    # Runs the bot, which logs into Discord and connects the WebSocket. This prevents all further execution unless it is executed with `async` = `:async`.
    # @param async [Symbol] If it is `:async`, then the bot will allow further execution.
    #   It doesn't necessarily have to be that, anything truthy will work,
    #   however it is recommended to use `:async` for code readability reasons.
    #   If the bot is run in async mode, make sure to eventually run {#sync} so
    #   the script doesn't stop prematurely.
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
        Thread.current[:discordrb_name] = 'heartbeat'
        loop do
          sleep @heartbeat_interval
          send_heartbeat if @heartbeat_active
        end
      end

      @ws_thread = Thread.new do
        Thread.current[:discordrb_name] = 'websocket'
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

    # Prevents all further execution until the websocket thread stops (e. g. through a closed connection).
    def sync
      @ws_thread.join
    end

    # Kills the websocket thread, stopping all connections to Discord.
    def stop
      @ws_thread.kill
    end

    # Gets a channel given its ID. This queries the internal channel cache, and if the channel doesn't
    # exist in there, it will get the data from Discord.
    # @param id [Integer] The channel ID for which to search for.
    # @return [Channel] The channel identified by the ID.
    def channel(id)
      debug("Obtaining data for channel with id #{id}")
      return @channels[id] if @channels[id]

      response = API.channel(@token, id)
      channel = Channel.new(JSON.parse(response), self)
      @channels[id] = channel
    end

    # Creates a private channel for the given user ID, or if one exists already, returns that one.
    # It is recommended that you use {User#pm} instead, as this is mainly for internal use. However,
    # usage of this method may be unavoidable if only the user ID is known.
    # @param id [Integer] The user ID to generate a private channel for.
    # @return [Channel] A private channel for that user.
    def private_channel(id)
      debug("Creating private channel with user id #{id}")
      return @private_channels[id] if @private_channels[id]

      response = API.create_private(@token, @bot_user.id, id)
      channel = Channel.new(JSON.parse(response), self)
      @private_channels[id] = channel
    end

    # Gets the code for an invite.
    # @param invite [String, Invite] The invite to get the code for. Possible formats are:
    #
    #    * An {Invite} object
    #    * The code for an invite
    #    * A fully qualified invite URL (e. g. `https://discordapp.com/invite/0A37aN7fasF7n83q`)
    #    * A short invite URL with protocol (e. g. `https://discord.gg/0A37aN7fasF7n83q`)
    #    * A short invite URL without protocol (e. g. `discord.gg/0A37aN7fasF7n83q`)
    # @return [String] Only the code for the invite.
    def resolve_invite_code(invite)
      invite = invite.code if invite.is_a? Discordrb::Invite
      invite = invite[invite.rindex('/') + 1..-1] if invite.start_with?('http') || invite.start_with?('discord.gg')
      invite
    end

    # Makes the bot join an invite to a server.
    # @param invite [String, Invite] The invite to join. For possible formats see {#resolve_invite_code}.
    def join(invite)
      invite = resolve_invite_code(invite)
      resolved = JSON.parse(API.resolve_invite(@token, invite))['code']
      API.join_server(@token, resolved)
    end

    # Revokes an invite to a server. Will fail unless you have the *Manage Server* permission.
    # It is recommended that you use {Invite#delete} instead.
    # @param code [String, Invite] The invite to revoke. For possible formats see {#resolve_invite_code}.
    def delete_invite(code)
      invite = resolve_invite_code(code)
      API.delete_invite(@token, invite)
    end

    # Gets a user by its ID.
    # @note This can only resolve users known by the bot (i.e. that share a server with the bot).
    # @param id [Integer] The user ID that should be resolved.
    # @return [User, nil] The user identified by the ID, or `nil` if it couldn't be found.
    def user(id)
      @users[id]
    end

    # Gets a server by its ID.
    # @note This can only resolve servers the bot is currently in.
    # @param id [Integer] The server ID that should be resolved.
    # @return [Server, nil] The server identified by the ID, or `nil` if it couldn't be found.
    def server(id)
      @servers[id]
    end

    # Finds a channel given its name and optionally the name of the server it is in. If the threshold
    # is not 0, it will use a Levenshtein distance function to find the channel in a fuzzy way, which
    # allows slight misspellings.
    # @param channel_name [String] The channel to search for.
    # @param server_name [String] The server to search for, or `nil` if only the channel should be searched for.
    # @param threshold [Integer] The threshold for the Levenshtein algorithm. The larger
    #   the threshold is, the more misspellings will be allowed.
    # @return [Array<Channel>] The array of channels that were found. May be empty if none were found.
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

    # Finds a user given its username. This allows fuzzy finding using Levenshtein
    # distances, see {#find}
    # @param username [String] The username to look for.
    # @param threshold [Integer] The threshold for the Levenshtein algorithm. The larger
    #   the threshold is, the more misspellings will be allowed.
    # @return [Array<User>] The array of users that were found. May be empty if none were found.
    def find_user(username, threshold = 0)
      require 'levenshtein'

      results = []
      @users.values.each do |user|
        distance = Levenshtein.distance(user.username, username)
        next if distance > threshold

        # Make a singleton accessor "distance"
        user.instance_variable_set(:@distance, distance)
        class << user
          attr_reader :distance
        end
        results << user
      end
      results
    end

    # Sends a text message to a channel given its ID and the message's content.
    # @param channel_id [Integer] The ID that identifies the channel to send something to.
    # @param content [String] The text that should be sent as a message. It is limited to 2000 characters (Discord imposed).
    # @return [Message] The message that was sent.
    def send_message(channel_id, content)
      debug("Sending message to #{channel_id} with content '#{content}'")
      response = API.send_message(@token, channel_id, content)
      Message.new(JSON.parse(response), self)
    end

    # Sends a file to a channel. If it is an image, it will automatically be embedded.
    # @note This executes in a blocking way, so if you're sending long files, be wary of delays.
    # @param channel_id [Integer] The ID that identifies the channel to send something to.
    # @param file [File] The file that should be sent.
    def send_file(channel_id, file)
      API.send_file(@token, channel_id, file)
    end

    # Add an await the bot should listen to. For information on awaits, see {Await}.
    # @param key [Symbol] The key that uniquely identifies the await for {AwaitEvent}s to listen to (see {#await}).
    # @param type [Class] The event class that should be listened for.
    # @param attributes [Hash] The attributes the event should check for. The block will only be executed if all attributes match.
    # @yield Is executed when the await is triggered.
    # @yieldparam event [Event] The event object that was triggered.
    # @return [Await] The await that was created.
    def add_await(key, type, attributes = {}, &block)
      fail "You can't await an AwaitEvent!" if type == Discordrb::Events::AwaitEvent
      await = Await.new(self, key, type, attributes, block)
      @awaits[key] = await
    end

    # Creates a server on Discord with a specified name and a region.
    # @note Discord's API doesn't directly return the server when creating it, so this method
    #   waits until the data has been received via the websocket. This may make the execution take a while.
    # @param name [String] The name the new server should have. Doesn't have to be alphanumeric.
    # @param region [Symbol] The region where the server should be created. Possible regions are:
    #
    #   * `:london`
    #   * `:amsterdam`
    #   * `:frankfurt`
    #   * `:us-east`
    #   * `:us-west`
    #   * `:singapore`
    #   * `:sydney`
    # @return [Server] The server that was created.
    def create_server(name, region = :london)
      response = API.create_server(@token, name, region)
      id = JSON.parse(response)['id'].to_i
      sleep 0.1 until @servers[id]
      server = @servers[id]
      debug "Successfully created server #{server.id} with name #{server.name}"
      server
    end

    # Gets the user from a mention of the user.
    # @param mention [String] The mention, which should look like <@12314873129>.
    # @return [User] The user identified by the mention, or `nil` if none exists.
    def parse_mention(mention)
      # Mention format: <@id>
      return nil unless /\<@(?<id>\d+)\>?/ =~ mention
      user(id)
    end

    # Sets the currently playing game to the specified game.
    # @param name_or_id [String, Fixnum] The name or the ID of the game to be played.
    # @return [Game] The game object that is being played now.
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

    # Sets debug mode. If debug mode is on, many things will be outputted to STDOUT.
    def debug=(new_debug)
      LOGGER.debug = new_debug
    end

    ##     ##    ###    ##    ## ########  ##       ######## ########   ######
    ##     ##   ## ##   ###   ## ##     ## ##       ##       ##     ## ##    ##
    ##     ##  ##   ##  ####  ## ##     ## ##       ##       ##     ## ##
    ######### ##     ## ## ## ## ##     ## ##       ######   ########   ######
    ##     ## ######### ##  #### ##     ## ##       ##       ##   ##         ##
    ##     ## ##     ## ##   ### ##     ## ##       ##       ##    ##  ##    ##
    ##     ## ##     ## ##    ## ########  ######## ######## ##     ##  ######

    # This **event** is raised when a message is sent to a text channel the bot is currently in.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :start_with Matches the string the message starts with.
    # @option attributes [String, Regexp] :end_with Matches the string the message ends with.
    # @option attributes [String, Regexp] :contains Matches a string the message contains.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was sent in.
    # @option attributes [String, Integer, User] :from Matches the user that sent the message.
    # @option attributes [String] :content Exactly matches the entire content of the message.
    # @option attributes [String] :content Exactly matches the entire content of the message.
    # @option attributes [Time] :after Matches a time after the time the message was sent at.
    # @option attributes [Time] :before Matches a time before the time the message was sent at.
    # @option attributes [Boolean] :private Matches whether or not the channel is private.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageEvent] The event that was raised.
    # @return [MessageEventHandler] The event handler that was registered.
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

    def server_create(attributes = {}, &block)
      register_event(GuildCreateEvent, attributes, block)
    end

    def server_update(attributes = {}, &block)
      register_event(GuildUpdateEvent, attributes, block)
    end

    def server_delete(attributes = {}, &block)
      register_event(GuildDeleteEvent, attributes, block)
    end

    # This **event** is raised when an {Await} is triggered. It provides an easy way to execute code
    # on an await without having to rely on the await's block.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Symbol] :key Exactly matches the await's key.
    # @option attributes [Class] :type Exactly matches the event's type.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [AwaitEvent] The event that was raised.
    # @return [AwaitEventHandler] The event handler that was registered.
    def await(attributes = {}, &block)
      register_event(AwaitEvent, attributes, block)
    end

    def pm(attributes = {}, &block)
      register_event(PrivateMessageEvent, attributes, block)
    end

    alias_method :private_message, :pm

    def remove_handler(handler)
      clazz = event_class(handler.class)
      @event_handlers[clazz].delete(handler)
    end

    def add_handler(handler)
      clazz = event_class(handler.class)
      @event_handlers[clazz] << handler
    end

    def debug(message, important = false)
      LOGGER.debug(message, important)
    end

    def log_exception(e)
      LOGGER.log_exception(e)
    end

    def handler_class(event_class)
      class_from_string(event_class.to_s + 'Handler')
    end

    alias_method :<<, :add_handler

    private

    #######     ###     ######  ##     ## ########
    ##    ##   ## ##   ##    ## ##     ## ##
    ##        ##   ##  ##       ##     ## ##
    ##       ##     ## ##       ######### ######
    ##       ######### ##       ##     ## ##
    ##    ## ##     ## ##    ## ##     ## ##
    #######  ##     ##  ######  ##     ## ########

    def add_server(data)
      server = Server.new(data, self)
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

      server
    end

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

    # Internal handler for GUILD_CREATE
    def create_guild(data)
      add_server(data)
    end

    # Internal handler for GUILD_UPDATE
    def update_guild(data)
      @servers[data['id'].to_i].update_data(data)
    end

    # Internal handler for GUILD_DELETE
    def delete_guild(data)
      id = data['id']

      @users.each do |_, user|
        user.delete_roles(id)
      end

      @servers.delete(id)
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
        log_exception(e)
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
        @profile = Profile.new(data['user'], self, @email, @password)

        # Initialize servers
        @servers = {}
        data['guilds'].each do |element|
          add_server(element)

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

        return if message.from_bot? && !should_parse_self

        event = MessageEvent.new(message, self)
        raise_event(event)

        if message.mentions.any? { |user| user.id == @bot_user.id }
          event = MentionEvent.new(message, self)
          raise_event(event)
        end

        if message.channel.private?
          event = PrivateMessageEvent.new(message, self)
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
      when 'GUILD_CREATE'
        create_guild(data)

        event = GuildCreateEvent.new(data, self)
        raise_event(event)
      when 'GUILD_UPDATE'
        update_guild(data)

        event = GuildUpdateEvent.new(data, self)
        raise_event(event)
      when 'GUILD_DELETE'
        delete_guild(data)

        event = GuildDeleteEvent.new(data, self)
        raise_event(event)
      end
    rescue Exception => e
      log_exception(e)
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
      handle_awaits(event)

      handlers = @event_handlers[event.class]
      (handlers || []).each do |handler|
        call_event(handler, event) if handler.matches?(event)
      end
    end

    def call_event(handler, event)
      t = Thread.new do
        @event_threads << t
        Thread.current[:discordrb_name] = "et-#{@current_thread += 1}"
        begin
          handler.call(event)
        rescue => e
          log_exception(e)
        ensure
          @event_threads.delete(t)
        end
      end
    end

    def handle_awaits(event)
      @awaits.each do |_, await|
        key, should_delete = await.match(event)
        next unless key
        debug("should_delete: #{should_delete}")
        @awaits.delete(await.key) if should_delete

        await_event = Discordrb::Events::AwaitEvent.new(await, event, self)
        raise_event(await_event)
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
