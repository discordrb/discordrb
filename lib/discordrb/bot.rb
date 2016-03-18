require 'rest-client'

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
require 'discordrb/events/bans'

require 'discordrb/api'
require 'discordrb/errors'
require 'discordrb/data'
require 'discordrb/await'
require 'discordrb/token_cache'
require 'discordrb/container'
require 'discordrb/websocket'
require 'discordrb/cache'

require 'discordrb/voice/voice_bot'

module Discordrb
  # Represents a Discord bot, including servers, users, etc.
  class Bot
    # The user that represents the bot itself. This version will always be identical to
    # the user determined by {#user} called with the bot's ID.
    # @return [User] The bot user.
    attr_reader :bot_user

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

    # The bot's name which discordrb sends to Discord when making any request, so Discord can identify bots with the
    # same codebase. Not required but I recommend setting it anyway.
    attr_accessor :name

    include EventContainer
    include Cache

    # Makes a new bot with the given authentication data. It will be ready to be added event handlers to and can
    # eventually be run with {#run}.
    #
    # Depending on the authentication information present, discordrb will deduce whether you're running on a user or a
    # bot account. (Discord recommends using bot accounts whenever possible.) The following sets of authentication
    # information are valid:
    #  * token + application_id (bot account)
    #  * email + password (user account)
    #  * email + password + token (user account; the given token will be used for authentication instead of email
    #    and password)
    #
    # Simply creating a bot won't be enough to start sending messages etc. with, only a limited set of methods can
    # be used after logging in. If you want to do something when the bot has connected successfully, either do it in the
    # {#ready} event, or use the {#run} method with the :async parameter and do the processing after that.
    # @param email [String] The email for your (or the bot's) Discord account.
    # @param password [String] The valid password that should be used to log in to the account.
    # @param log_mode [Symbol] The mode this bot should use for logging. See {Logger#mode=} for a list of modes.
    # @param token [String] The token that should be used to log in. If your bot is a bot account, you have to specify
    #   this. If you're logging in as a user, make sure to also set the account type to :user so discordrb doesn't think
    #   you're trying to log in as a bot.
    # @param application_id [Integer] If you're logging in as a bot, the bot's application ID.
    # @param type [Symbol] This parameter lets you manually overwrite the account type. If this isn't specified, it will
    #   be determined by checking what other attributes are there. The only use case for this is if you want to log in
    #   as a user but only with a token. Valid values are :user and :bot.
    # @param name [String] Your bot's name. This will be sent to Discord with any API requests, who will use this to
    #   trace the source of excessive API requests; it's recommended to set this to something if you make bots that many
    #   people will host on their servers separately.
    # @param fancy_log [true, false] Whether the output log should be made extra fancy using ANSI escape codes. (Your
    #   terminal may not support this.)
    # @param suppress_ready [true, false] Whether the READY packet should be exempt from being printed to console.
    #   Useful for very large bots running in debug or verbose log_mode.
    def initialize(
        email: nil, password: nil, log_mode: :normal,
        token: nil, application_id: nil,
        type: nil, name: '', fancy_log: false, suppress_ready: false)
      # Make sure people replace the login details in the example files...
      if email.is_a?(String) && email.end_with?('example.com')
        puts 'You have to replace the login details in the example files with your own!'
        exit
      end

      LOGGER.mode = if log_mode.is_a? TrueClass # Specifically check for `true` because people might not have updated yet
                      :debug
                    else
                      log_mode
                    end

      @should_parse_self = false

      @email = email
      @password = password

      @application_id = application_id

      @type = determine_account_type(type, email, password, token, application_id)

      @name = name

      LOGGER.fancy = fancy_log
      @prevent_ready = suppress_ready

      debug('Creating token cache')
      @token_cache = Discordrb::TokenCache.new
      debug('Token cache created successfully')
      @token = login(type, email, password, token, @token_cache)

      init_cache

      @event_threads = []
      @current_thread = 0
    end

    # The Discord API token received when logging in. Useful to explicitly call
    # {API} methods.
    # @return [String] The API token.
    def token
      API.bot_name = @name
      @token
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

    # Runs the bot asynchronously. Equivalent to #run with the :async parameter.
    # @see #run
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

        # Initialize falloff so we wait for more time before reconnecting each time
        @falloff = 1.0

        loop do
          websocket_connect
          debug("Disconnected! Attempting to reconnect in #{@falloff} seconds.")
          sleep @falloff
          @token = login

          # Calculate new falloff
          @falloff *= 1.5
          @falloff = 115 + (rand * 10) if @falloff > 1 # Cap the falloff at 120 seconds and then add some random jitter
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

    # Makes the bot join an invite to a server.
    # @param invite [String, Invite] The invite to join. For possible formats see {#resolve_invite_code}.
    def join(invite)
      resolved = invite(invite).code
      API.join_server(token, resolved)
    end

    attr_reader :voice

    # Connects to a voice channel, initializes network connections and returns the {Voice::VoiceBot} over which audio
    # data can then be sent. After connecting, the bot can also be accessed using {#voice}.
    # @param chan [Channel] The voice channel to connect to.
    # @param encrypted [true, false] Whether voice communication should be encrypted using RbNaCl's SecretBox
    #   (uses an XSalsa20 stream cipher for encryption and Poly1305 for authentication)
    # @return [Voice::VoiceBot] the initialized bot over which audio data can then be sent.
    def voice_connect(chan, encrypted = true)
      if @voice
        debug('Voice bot exists already! Destroying it')
        @voice.destroy
        @voice = nil
      end

      chan = channel(chan.resolve_id)
      @voice_channel = chan
      @should_encrypt_voice = encrypted

      debug("Got voice channel: #{@voice_channel}")

      data = {
        op: 4,
        d: {
          guild_id: @voice_channel.server.id.to_s,
          channel_id: @voice_channel.id.to_s,
          self_mute: false,
          self_deaf: false
        }
      }
      debug("Voice channel init packet is: #{data.to_json}")

      @should_connect_to_voice = true
      @ws.send(data.to_json)
      debug('Voice channel init packet sent! Now waiting.')

      sleep(0.05) until @voice
      debug('Voice connect succeeded!')
      @voice
    end

    # Disconnects the client from all voice connections across Discord.
    # @param destroy_vws [true, false] Whether or not the VWS should also be destroyed. If you're calling this method
    #   directly, you should leave it as true.
    def voice_destroy(destroy_vws = true)
      data = {
        op: 4,
        d: {
          guild_id: nil,
          channel_id: nil,
          self_mute: false,
          self_deaf: false
        }
      }

      debug("Voice channel destroy packet is: #{data.to_json}")
      @ws.send(data.to_json)

      @voice.destroy if @voice && destroy_vws
      @voice = nil
    end

    # Revokes an invite to a server. Will fail unless you have the *Manage Server* permission.
    # It is recommended that you use {Invite#delete} instead.
    # @param code [String, Invite] The invite to revoke. For possible formats see {#resolve_invite_code}.
    def delete_invite(code)
      invite = resolve_invite_code(code)
      API.delete_invite(token, invite)
    end

    # Sends a text message to a channel given its ID and the message's content.
    # @param channel_id [Integer] The ID that identifies the channel to send something to.
    # @param content [String] The text that should be sent as a message. It is limited to 2000 characters (Discord imposed).
    # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
    # @return [Message] The message that was sent.
    def send_message(channel_id, content, tts = false)
      debug("Sending message to #{channel_id} with content '#{content}'")

      response = API.send_message(token, channel_id, content, [], tts)
      Message.new(JSON.parse(response), self)
    end

    # Sends a file to a channel. If it is an image, it will automatically be embedded.
    # @note This executes in a blocking way, so if you're sending long files, be wary of delays.
    # @param channel_id [Integer] The ID that identifies the channel to send something to.
    # @param file [File] The file that should be sent.
    def send_file(channel_id, file)
      response = API.send_file(token, channel_id, file)
      Message.new(JSON.parse(response), self)
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
    #   * `:us-south`
    #   * `:us-central`
    #   * `:singapore`
    #   * `:sydney`
    # @return [Server] The server that was created.
    def create_server(name, region = :london)
      response = API.create_server(token, name, region)
      id = JSON.parse(response)['id'].to_i
      sleep 0.1 until @servers[id]
      server = @servers[id]
      debug "Successfully created server #{server.id} with name #{server.name}"
      server
    end

    # Creates a new application to do OAuth authorization with. This allows you to use OAuth to authorize users using
    # Discord. For information how to use this, see this example: https://github.com/vishnevskiy/discord-oauth2-example
    # @param name [String] What your application should be called.
    # @param redirect_uris [Array<String>] URIs that Discord should redirect your users to after authorizing.
    # @return [Array(String, String)] your applications' client ID and client secret to be used in OAuth authorization.
    def create_oauth_application(name, redirect_uris)
      response = JSON.parse(API.create_oauth_application(@token, name, redirect_uris))
      [response['id'], response['secret']]
    end

    # Changes information about your OAuth application
    # @param name [String] What your application should be called.
    # @param redirect_uris [Array<String>] URIs that Discord should redirect your users to after authorizing.
    # @param description [String] A string that describes what your application does.
    # @param icon [String, nil] A data URI for your icon image (for example a base 64 encoded image), or nil if no icon
    #   should be set or changed.
    def update_oauth_application(name, redirect_uris, description = '', icon = nil)
      API.update_oauth_application(@token, name, redirect_uris, description, icon)
    end

    # Gets the user from a mention of the user.
    # @param mention [String] The mention, which should look like <@12314873129>.
    # @return [User] The user identified by the mention, or `nil` if none exists.
    def parse_mention(mention)
      # Mention format: <@id>
      return nil unless /<@(?<id>\d+)>?/ =~ mention
      user(id.to_i)
    end

    # Sets the currently playing game to the specified game.
    # @param name [String] The name of the game to be played.
    # @return [String] The game that is being played now.
    def game=(name)
      @game = name

      data = {
        op: 3,
        d: {
          idle_since: nil,
          game: name ? { name: name } : nil
        }
      }

      @ws.send(data.to_json)
      name
    end

    # Sets debug mode. If debug mode is on, many things will be outputted to STDOUT.
    def debug=(new_debug)
      LOGGER.debug = new_debug
    end

    # Sets the logging mode
    # @see Logger#mode=
    def mode=(new_mode)
      LOGGER.mode = new_mode
    end

    # Prevents the READY packet from being printed regardless of debug mode.
    def suppress_ready_debug
      @prevent_ready = true
    end

    # Add an await the bot should listen to. For information on awaits, see {Await}.
    # @param key [Symbol] The key that uniquely identifies the await for {AwaitEvent}s to listen to (see {#await}).
    # @param type [Class] The event class that should be listened for.
    # @param attributes [Hash] The attributes the event should check for. The block will only be executed if all attributes match.
    # @yield Is executed when the await is triggered.
    # @yieldparam event [Event] The event object that was triggered.
    # @return [Await] The await that was created.
    def add_await(key, type, attributes = {}, &block)
      raise "You can't await an AwaitEvent!" if type == Discordrb::Events::AwaitEvent
      await = Await.new(self, key, type, attributes, block)
      @awaits ||= {}
      @awaits[key] = await
    end

    # @see Logger#debug
    def debug(message)
      LOGGER.debug(message)
    end

    # @see Logger#log_exception
    def log_exception(e)
      LOGGER.log_exception(e)
    end

    private

    # Determines the type of an account by checking which parameters are given
    def determine_account_type(type, email, password, token, application_id)
      # Case 1: if a type is already given, return it
      return type if type

      # Case 2: user accounts can't have application IDs so if one is given, return bot type
      return :bot if application_id

      # Case 3: bot accounts can't have emails and passwords so if either is given, assume user
      return :user if email || password

      # Case 4: If we're here and no token is given, throw an exception because that's impossible
      raise ArgumentError, "Can't login because no authentication data was given! Specify at least a token" unless token

      # Case 5: Only a token has been specified, we can assume it's a bot but we should tell the user
      # to specify the application ID:
      LOGGER.warn('The application ID is missing! Logging in as a bot will work but some OAuth-related functionality will be unavailable!')
      :bot
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
      server = server(server_id)
      return unless server

      member_is_new = false

      if server.member_cached?(user_id)
        member = server.member(user_id)
      else
        # If the member is not cached yet, it means that it just came online from not being cached at all
        # due to large_threshold. Fortunately, Discord sends the entire member object in this case, and
        # not just a part of it - we can just cache this member directly
        member = Member.new(data, server, self)
        debug("Implicitly adding presence-obtained member #{user_id} to #{server_id} cache")

        member_is_new = true
      end

      username = data['user']['username']
      if username && !member_is_new # Don't set the username for newly-cached members
        debug "Implicitly updating presence-obtained information for member #{user_id}"
        member.update_username(username)
      end

      member.status = data['status'].to_sym
      member.game = data['game'] ? data['game']['name'] : nil

      server.cache_member(member)
    end

    # Internal handler for VOICE_STATUS_UPDATE
    def update_voice_state(data)
      user_id = data['user_id'].to_i
      server_id = data['guild_id'].to_i
      server = server(server_id)
      return unless server

      user = server.member(user_id)

      channel_id = data['channel_id']
      channel = nil
      channel = self.channel(channel_id.to_i) if channel_id

      user.update_voice_state(
        channel,
        data['mute'],
        data['deaf'],
        data['self_mute'],
        data['self_deaf'])

      @session_id = data['session_id']
    end

    # Internal handler for VOICE_SERVER_UPDATE
    def update_voice_server(data)
      debug("Voice server update received! should connect: #{@should_connect_to_voice}")
      return unless @should_connect_to_voice
      @should_connect_to_voice = false
      debug('Updating voice server!')

      token = data['token']
      endpoint = data['endpoint']

      unless endpoint
        debug('VOICE_SERVER_UPDATE sent with nil endpoint! Ignoring')
        return
      end

      channel = @voice_channel

      debug('Got data, now creating the bot.')
      @voice = Discordrb::Voice::VoiceBot.new(channel, self, token, @session_id, endpoint, @should_encrypt_voice)
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
      @channels.delete(channel.id)
      server.channels.reject! { |c| c.id == channel.id }
    end

    # Internal handler for GUILD_MEMBER_ADD
    def add_guild_member(data)
      server_id = data['guild_id'].to_i
      server = self.server(server_id)

      member = Member.new(data, server, self)
      server.add_member(member)
    end

    # Internal handler for GUILD_MEMBER_UPDATE
    def update_guild_member(data)
      server_id = data['guild_id'].to_i
      server = self.server(server_id)

      member = server.member(data['user']['id'].to_i)
      member.update_roles(data['roles'])
    end

    # Internal handler for GUILD_MEMBER_DELETE
    def delete_guild_member(data)
      server_id = data['guild_id'].to_i
      server = self.server(server_id)

      user_id = data['user']['id'].to_i
      server.delete_member(user_id)
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
      id = data['id'].to_i

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
      role_id = data['role_id'].to_i
      server_id = data['guild_id'].to_i
      server = @servers[server_id]
      server.delete_role(role_id)
    end

    # Internal handler for MESSAGE_CREATE
    def create_message(data); end

    # Internal handler for TYPING_START
    def start_typing(data); end

    # Internal handler for MESSAGE_UPDATE
    def update_message(data); end

    # Internal handler for MESSAGE_DELETE
    def delete_message(data); end

    # Internal handler for GUILD_BAN_ADD
    def add_user_ban(data); end

    # Internal handler for GUILD_BAN_REMOVE
    def remove_user_ban(data); end

    ##        #######   ######   #### ##    ##
    ##       ##     ## ##    ##   ##  ###   ##
    ##       ##     ## ##         ##  ####  ##
    ##       ##     ## ##   ####  ##  ## ## ##
    ##       ##     ## ##    ##   ##  ##  ####
    ##       ##     ## ##    ##   ##  ##   ###
    ########  #######   ######   #### ##    ##

    def login(type, email, password, token, token_cache)
      # Don't bother with any login code if a token is already specified
      return process_token(type, token) if token

      # If a bot account attempts logging in without a token, throw an error
      raise ArgumentError, 'Bot account detected (type == :bot) but no token was found! Please specify a token in the Bot initializer, or use a user account.' if type == :bot

      # If the type is not a user account at this point, it must be invalid
      raise ArgumentError, 'Invalid type specified! Use either :bot or :user' if type == :user

      user_login(email, password, token_cache)
    end

    def process_token(type, token)
      # Remove the "Bot " prefix if it exists
      token = token[4..-1] if token.starts_with? 'Bot '

      token = 'Bot ' + token unless type == :user
      token
    end

    def user_login(email, password, token_cache)
      debug('Logging in')

      # Attempt to retrieve the token from the cache
      retrieved_token = retrieve_token(email, password, token_cache)
      return retrieved_token if retrieved_token

      login_attempts ||= 0

      # Login
      login_response = JSON.parse(API.login(email, password))
      token = login_response['token']
      raise Discordrb::Errors::InvalidAuthenticationError unless token
      debug('Received token from Discord!')

      # Cache the token
      token_cache.store_token(email, password, token)

      token
    rescue RestClient::BadRequest
      raise Discordrb::Errors::InvalidAuthenticationError
    rescue SocketError, RestClient::RequestFailed => e # RequestFailed handles the 52x error codes Cloudflare sometimes sends that aren't covered by specific RestClient classes
      if login_attempts && login_attempts > 100
        LOGGER.error("User login failed permanently after #{login_attempts} attempts")
        raise
      else
        LOGGER.error("User login failed! Trying again in 5 seconds, #{100 - login_attempts} remaining")
        LOGGER.log_exception(e)
        retry
      end
    end

    def retrieve_token(email, password, token_cache)
      # First, attempt to get the token from the cache
      token = token_cache.token(email, password)
      debug('Token successfully obtained from cache!') if token
      token
    end

    def find_gateway
      # Get updated websocket_hub
      response = API.gateway(token)
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

      @ws = Discordrb::WebSocket.new(
        websocket_hub,
        method(:websocket_open),
        method(:websocket_message),
        method(:websocket_close),
        proc { |e| LOGGER.error "Gateway error: #{e}" }
      )

      @ws.thread[:discordrb_name] = 'gateway'
      @ws.thread.join
    end

    def websocket_message(event)
      # Parse packet
      packet = JSON.parse(event)

      if @prevent_ready && packet['t'] == 'READY'
        debug('READY packet was received and suppressed')
      elsif @prevent_ready && packet['t'] == 'GUILD_MEMBERS_CHUNK'
        # Ignore chunks as they will be handled later anyway
      else
        LOGGER.in(event.to_s)
      end

      raise 'Invalid Packet' unless packet['op'] == 0 # TODO

      data = packet['d']
      type = packet['t'].intern
      case type
      when :READY
        # Activate the heartbeats
        @heartbeat_interval = data['heartbeat_interval'].to_f / 1000.0
        @heartbeat_active = true
        debug("Desired heartbeat_interval: #{@heartbeat_interval}")

        bot_user_id = data['user']['id'].to_i
        @profile = Profile.new(data['user'], self, @email, @password)

        # Initialize servers
        @servers = {}
        data['guilds'].each do |element|
          ensure_server(element)

          # Save the bot user
          @bot_user = @users[bot_user_id]
        end

        # Add private channels
        data['private_channels'].each do |element|
          channel = ensure_channel(element)
          @private_channels[channel.recipient.id] = channel
        end

        # Make sure to raise the event
        raise_event(ReadyEvent.new)
        LOGGER.good 'Ready'

        # Tell the run method that everything was successful
        @ws_success = true
      when :GUILD_MEMBERS_CHUNK
        id = data['guild_id'].to_i
        server = server(id)
        server.process_chunk(data['members'])
      when :MESSAGE_CREATE
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
      when :MESSAGE_UPDATE
        update_message(data)

        event = MessageEditEvent.new(data, self)
        raise_event(event)
      when :MESSAGE_DELETE
        delete_message(data)

        event = MessageDeleteEvent.new(data, self)
        raise_event(event)
      when :TYPING_START
        start_typing(data)

        begin
          event = TypingEvent.new(data, self)
          raise_event(event)
        rescue Discordrb::Errors::NoPermission
          debug 'Typing started in channel the bot has no access to, ignoring'
        end
      when :PRESENCE_UPDATE
        now_playing = data['game']
        presence_user = @users[data['user']['id'].to_i]
        played_before = presence_user.nil? ? nil : presence_user.game
        update_presence(data)

        event = if now_playing != played_before
                  PlayingEvent.new(data, self)
                else
                  PresenceEvent.new(data, self)
                end

        raise_event(event)
      when :VOICE_STATE_UPDATE
        update_voice_state(data)

        event = VoiceStateUpdateEvent.new(data, self)
        raise_event(event)
      when :VOICE_SERVER_UPDATE
        update_voice_server(data)

        # no event as this is irrelevant to users
      when :CHANNEL_CREATE
        create_channel(data)

        event = ChannelCreateEvent.new(data, self)
        raise_event(event)
      when :CHANNEL_UPDATE
        update_channel(data)

        event = ChannelUpdateEvent.new(data, self)
        raise_event(event)
      when :CHANNEL_DELETE
        delete_channel(data)

        event = ChannelDeleteEvent.new(data, self)
        raise_event(event)
      when :GUILD_MEMBER_ADD
        add_guild_member(data)

        event = GuildMemberAddEvent.new(data, self)
        raise_event(event)
      when :GUILD_MEMBER_UPDATE
        update_guild_member(data)

        event = GuildMemberUpdateEvent.new(data, self)
        raise_event(event)
      when :GUILD_MEMBER_REMOVE
        delete_guild_member(data)

        event = GuildMemberDeleteEvent.new(data, self)
        raise_event(event)
      when :GUILD_BAN_ADD
        add_user_ban(data)

        event = UserBanEvent.new(data, self)
        raise_event(event)
      when :GUILD_BAN_REMOVE
        remove_user_ban(data)

        event = UserUnbanEvent.new(data, self)
        raise_event(event)
      when :GUILD_ROLE_UPDATE
        update_guild_role(data)

        event = GuildRoleUpdateEvent.new(data, self)
        raise_event(event)
      when :GUILD_ROLE_CREATE
        create_guild_role(data)

        event = GuildRoleCreateEvent.new(data, self)
        raise_event(event)
      when :GUILD_ROLE_DELETE
        delete_guild_role(data)

        event = GuildRoleDeleteEvent.new(data, self)
        raise_event(event)
      when :GUILD_CREATE
        create_guild(data)

        event = GuildCreateEvent.new(data, self)
        raise_event(event)
      when :GUILD_UPDATE
        update_guild(data)

        event = GuildUpdateEvent.new(data, self)
        raise_event(event)
      when :GUILD_DELETE
        delete_guild(data)

        event = GuildDeleteEvent.new(data, self)
        raise_event(event)
      else
        # another event that we don't support yet
        debug "Event #{packet['t']} has been received but is unsupported, ignoring"
      end
    rescue Exception => e
      LOGGER.error('Gateway message error!')
      log_exception(e)
    end

    def websocket_close(event)
      LOGGER.error('Disconnected from WebSocket!')

      # Handle actual close frames and errors separately
      if event.respond_to? :code
        LOGGER.error(" (Reason: #{event.data})")
        LOGGER.error(" (Code: #{event.code})")
      else
        LOGGER.log_exception event
      end

      raise_event(DisconnectEvent.new)
    rescue => e
      LOGGER.log_exception e
      raise
    end

    def websocket_open
      # Send the initial packet
      packet = {
        op: 2,    # Packet identifier
        d: {      # Packet data
          v: 3,   # WebSocket protocol version
          token: @token,
          properties: { # I'm unsure what these values are for exactly, but they don't appear to impact bot functionality in any way.
            :'$os' => RUBY_PLATFORM.to_s,
            :'$browser' => 'discordrb',
            :'$device' => 'discordrb',
            :'$referrer' => '',
            :'$referring_domain' => ''
          },
          large_threshold: 100
        }
      }

      @ws.send(packet.to_json)
    end

    def send_heartbeat
      millis = Time.now.strftime('%s%L').to_i
      LOGGER.out("Sending heartbeat at #{millis}")
      data = {
        op: 1,
        d: millis
      }

      @ws.send(data.to_json)
    end

    def raise_event(event)
      debug("Raised a #{event.class}")
      handle_awaits(event)

      @event_handlers ||= {}
      handlers = @event_handlers[event.class]
      (handlers || []).each do |handler|
        call_event(handler, event) if handler.matches?(event)
      end
    end

    def call_event(handler, event)
      t = Thread.new do
        @event_threads ||= []
        @current_thread ||= 0

        @event_threads << t
        Thread.current[:discordrb_name] = "et-#{@current_thread += 1}"
        begin
          handler.call(event)
          handler.after_call(event)
        rescue => e
          log_exception(e)
        ensure
          @event_threads.delete(t)
        end
      end
    end

    def handle_awaits(event)
      @awaits ||= {}
      @awaits.each do |_, await|
        key, should_delete = await.match(event)
        next unless key
        debug("should_delete: #{should_delete}")
        @awaits.delete(await.key) if should_delete

        await_event = Discordrb::Events::AwaitEvent.new(await, event, self)
        raise_event(await_event)
      end
    end
  end
end
