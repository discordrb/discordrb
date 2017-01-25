# frozen_string_literal: true

require 'rest-client'
require 'zlib'
require 'set'

require 'discordrb/events/message'
require 'discordrb/events/typing'
require 'discordrb/events/lifetime'
require 'discordrb/events/presence'
require 'discordrb/events/voice_state_update'
require 'discordrb/events/channels'
require 'discordrb/events/members'
require 'discordrb/events/roles'
require 'discordrb/events/guilds'
require 'discordrb/events/await'
require 'discordrb/events/bans'
require 'discordrb/events/raw'
require 'discordrb/events/reactions'

require 'discordrb/api'
require 'discordrb/api/channel'
require 'discordrb/api/server'
require 'discordrb/api/invite'
require 'discordrb/errors'
require 'discordrb/data'
require 'discordrb/await'
require 'discordrb/container'
require 'discordrb/websocket'
require 'discordrb/cache'
require 'discordrb/gateway'

require 'discordrb/voice/voice_bot'

module Discordrb
  # Represents a Discord bot, including servers, users, etc.
  class Bot
    # The list of currently running threads used to parse and call events.
    # The threads will have a local variable `:discordrb_name` in the format of `et-1234`, where
    # "et" stands for "event thread" and the number is a continually incrementing number representing
    # how many events were executed before.
    # @return [Array<Thread>] The threads.
    attr_reader :event_threads

    # Whether or not the bot should parse its own messages. Off by default.
    attr_accessor :should_parse_self

    # The bot's name which discordrb sends to Discord when making any request, so Discord can identify bots with the
    # same codebase. Not required but I recommend setting it anyway.
    attr_accessor :name

    # @return [Array(Integer, Integer)] the current shard key
    attr_reader :shard_key

    # @return [Hash<Symbol => Await>] the list of registered {Await}s.
    attr_reader :awaits

    # The gateway connection is an internal detail that is useless to most people. It is however essential while
    # debugging or developing discordrb itself, or while writing very custom bots.
    # @return [Gateway] the underlying {Gateway} object.
    attr_reader :gateway

    include EventContainer
    include Cache

    # Makes a new bot with the given authentication data. It will be ready to be added event handlers to and can
    # eventually be run with {#run}.
    #
    # As support for logging in using username and password has been removed in version 3.0.0, only a token login is
    # possible. Be sure to specify the `type` parameter as `:user` if you're logging in as a user.
    #
    # Simply creating a bot won't be enough to start sending messages etc. with, only a limited set of methods can
    # be used after logging in. If you want to do something when the bot has connected successfully, either do it in the
    # {#ready} event, or use the {#run} method with the :async parameter and do the processing after that.
    # @param log_mode [Symbol] The mode this bot should use for logging. See {Logger#mode=} for a list of modes.
    # @param token [String] The token that should be used to log in. If your bot is a bot account, you have to specify
    #   this. If you're logging in as a user, make sure to also set the account type to :user so discordrb doesn't think
    #   you're trying to log in as a bot.
    # @param client_id [Integer] If you're logging in as a bot, the bot's client ID.
    # @param type [Symbol] This parameter lets you manually overwrite the account type. This needs to be set when
    #   logging in as a user, otherwise discordrb will treat you as a bot account. Valid values are `:user` and `:bot`.
    # @param name [String] Your bot's name. This will be sent to Discord with any API requests, who will use this to
    #   trace the source of excessive API requests; it's recommended to set this to something if you make bots that many
    #   people will host on their servers separately.
    # @param fancy_log [true, false] Whether the output log should be made extra fancy using ANSI escape codes. (Your
    #   terminal may not support this.)
    # @param suppress_ready [true, false] Whether the READY packet should be exempt from being printed to console.
    #   Useful for very large bots running in debug or verbose log_mode.
    # @param parse_self [true, false] Whether the bot should react on its own messages. It's best to turn this off
    #   unless you really need this so you don't inadvertently create infinite loops.
    # @param shard_id [Integer] The number of the shard this bot should handle. See
    #   https://github.com/hammerandchisel/discord-api-docs/issues/17 for how to do sharding.
    # @param num_shards [Integer] The total number of shards that should be running. See
    #   https://github.com/hammerandchisel/discord-api-docs/issues/17 for how to do sharding.
    # @param redact_token [true, false] Whether the bot should redact the token in logs. Default is true.
    # @param ignore_bots [true, false] Whether the bot should ignore bot accounts or not. Default is false.
    def initialize(
        log_mode: :normal,
        token: nil, client_id: nil,
        type: nil, name: '', fancy_log: false, suppress_ready: false, parse_self: false,
        shard_id: nil, num_shards: nil, redact_token: true, ignore_bots: false
    )

      LOGGER.mode = if log_mode.is_a? TrueClass # Specifically check for `true` because people might not have updated yet
                      :debug
                    else
                      log_mode
                    end

      LOGGER.token = token if redact_token

      @should_parse_self = parse_self

      @client_id = client_id

      @type = type || :bot
      @name = name

      @shard_key = num_shards ? [shard_id, num_shards] : nil

      LOGGER.fancy = fancy_log
      @prevent_ready = suppress_ready

      @token = process_token(@type, token)
      @gateway = Gateway.new(self, @token, @shard_key)

      init_cache

      @voices = {}
      @should_connect_to_voice = {}

      @ignored_ids = Set.new
      @ignore_bots = ignore_bots

      @event_threads = []
      @current_thread = 0

      @status = :online
    end

    # The list of users the bot shares a server with.
    # @return [Hash<Integer => User>] The users by ID.
    def users
      gateway_check
      @users
    end

    # The list of servers the bot is currently in.
    # @return [Hash<Integer => Server>] The servers by ID.
    def servers
      gateway_check
      @servers
    end

    # @overload emoji(id)
    #   Return an emoji by its ID
    #   @param id [Integer] The emoji's ID.
    #   @return emoji [GlobalEmoji, nil] the emoji object. `nil` if the emoji was not found.
    # @overload emoji
    #   The list of emoji the bot can use.
    #   @return [Array<GlobalEmoji>] the emoji available.
    def emoji(id = nil)
      gateway_check
      if id
        emoji
        @emoji.find { |sth| sth.id == id }
      else
        emoji = {}
        @servers.each do |_, server|
          server.emoji.values.each do |element|
            emoji[element.name] = GlobalEmoji.new(element, self)
          end
        end
        @emoji = emoji.values
      end
    end

    alias_method :emojis, :emoji
    alias_method :all_emoji, :emoji

    # Finds an emoji by its name.
    # @param name [String] The emoji name that should be resolved.
    # @return [GlobalEmoji, nil] the emoji identified by the name, or `nil` if it couldn't be found.
    def find_emoji(name)
      LOGGER.out("Resolving emoji #{name}")
      emoji.find { |element| element.name == name }
    end

    # The bot's user profile. This special user object can be used
    # to edit user data like the current username (see {Profile#username=}).
    # @return [Profile] The bot's profile that can be used to edit data.
    def profile
      gateway_check
      @profile
    end

    alias_method :bot_user, :profile

    # The bot's OAuth application.
    # @return [Application, nil] The bot's application info. Returns `nil` if bot is not a bot account.
    def bot_application
      gateway_check
      return nil unless @type == :bot
      response = API.oauth_application(token)
      Application.new(JSON.parse(response), self)
    end

    alias_method :bot_app, :bot_application

    # The Discord API token received when logging in. Useful to explicitly call
    # {API} methods.
    # @return [String] The API token.
    def token
      API.bot_name = @name
      @token
    end

    # @return the raw token, without any prefix
    # @see #token
    def raw_token
      @token.split(' ').last
    end

    # Runs the bot, which logs into Discord and connects the WebSocket. This prevents all further execution unless it is executed with `async` = `:async`.
    # @param async [Symbol] If it is `:async`, then the bot will allow further execution.
    #   It doesn't necessarily have to be that, anything truthy will work,
    #   however it is recommended to use `:async` for code readability reasons.
    #   If the bot is run in async mode, make sure to eventually run {#sync} so
    #   the script doesn't stop prematurely.
    def run(async = false)
      @gateway.run_async
      return if async

      debug('Oh wait! Not exiting yet as run was run synchronously.')
      @gateway.sync
    end

    # Blocks execution until the websocket stops, which should only happen manually triggered
    # or due to an error. This is necessary to have a continuously running bot.
    def sync
      @gateway.sync
    end

    # Stops the bot gracefully, disconnecting the websocket without immediately killing the thread. This means that
    # Discord is immediately aware of the closed connection and makes the bot appear offline instantly.
    # @param no_sync [true, false] Whether or not to disable use of synchronize in the close method. This should be true if called from a trap context.
    def stop(no_sync = false)
      @gateway.stop(no_sync)
    end

    # @return [true, false] whether or not the bot is currently connected to Discord.
    def connected?
      @gateway.open?
    end

    # Makes the bot join an invite to a server.
    # @param invite [String, Invite] The invite to join. For possible formats see {#resolve_invite_code}.
    def join(invite)
      resolved = invite(invite).code
      API::Invite.accept(token, resolved)
    end

    # Creates an OAuth invite URL that can be used to invite this bot to a particular server.
    # Requires the application ID to have been set during initialization.
    # @param server [Server, nil] The server the bot should be invited to, or nil if a general invite should be created.
    # @param permission_bits [Integer, String] Permission bits that should be appended to invite url.
    # @return [String] the OAuth invite URL.
    def invite_url(server: nil, permission_bits: nil)
      raise 'No application ID has been set during initialization! Add one as the `client_id` named parameter while creating your bot.' unless @client_id

      server_id_str = server ? "&guild_id=#{server.id}" : ''
      permission_bits_str = permission_bits ? "&permissions=#{permission_bits}" : ''
      "https://discordapp.com/oauth2/authorize?&client_id=#{@client_id}#{server_id_str}#{permission_bits_str}&scope=bot"
    end

    # @return [Hash<Integer => VoiceBot>] the voice connections this bot currently has, by the server ID to which they are connected.
    attr_reader :voices

    # Gets the voice bot for a particular server or channel. You can connect to a new channel using the {#voice_connect}
    # method.
    # @param thing [Channel, Server, Integer] the server or channel you want to get the voice bot for, or its ID.
    # @return [VoiceBot, nil] the VoiceBot for the thing you specified, or nil if there is no connection yet
    def voice(thing)
      id = thing.resolve_id
      return @voices[id] if @voices[id]

      channel = channel(id)
      return nil unless channel

      server_id = channel.server.id
      return @voices[server_id] if @voices[server_id]

      nil
    end

    # Connects to a voice channel, initializes network connections and returns the {Voice::VoiceBot} over which audio
    # data can then be sent. After connecting, the bot can also be accessed using {#voice}. If the bot is already
    # connected to voice, the existing connection will be terminated - you don't have to call
    # {Discordrb::Voice::VoiceBot#destroy} before calling this method.
    # @param chan [Channel] The voice channel to connect to.
    # @param encrypted [true, false] Whether voice communication should be encrypted using RbNaCl's SecretBox
    #   (uses an XSalsa20 stream cipher for encryption and Poly1305 for authentication)
    # @return [Voice::VoiceBot] the initialized bot over which audio data can then be sent.
    def voice_connect(chan, encrypted = true)
      chan = channel(chan.resolve_id)
      server_id = chan.server.id
      @should_encrypt_voice = encrypted

      if @voices[chan.id]
        debug('Voice bot exists already! Destroying it')
        @voices[chan.id].destroy
        @voices.delete(chan.id)
      end

      debug("Got voice channel: #{chan}")

      @should_connect_to_voice[server_id] = chan
      @gateway.send_voice_state_update(server_id.to_s, chan.id.to_s, false, false)

      debug('Voice channel init packet sent! Now waiting.')

      sleep(0.05) until @voices[server_id]
      debug('Voice connect succeeded!')
      @voices[server_id]
    end

    # Disconnects the client from a specific voice connection given the server ID. Usually it's more convenient to use
    # {Discordrb::Voice::VoiceBot#destroy} rather than this.
    # @param server_id [Integer] The ID of the server the voice connection is on.
    # @param destroy_vws [true, false] Whether or not the VWS should also be destroyed. If you're calling this method
    #   directly, you should leave it as true.
    def voice_destroy(server_id, destroy_vws = true)
      @gateway.send_voice_state_update(server_id.to_s, nil, false, false)
      @voices[server_id].destroy if @voices[server_id] && destroy_vws
      @voices.delete(server_id)
    end

    # Revokes an invite to a server. Will fail unless you have the *Manage Server* permission.
    # It is recommended that you use {Invite#delete} instead.
    # @param code [String, Invite] The invite to revoke. For possible formats see {#resolve_invite_code}.
    def delete_invite(code)
      invite = resolve_invite_code(code)
      API::Invite.delete(token, invite)
    end

    # Sends a text message to a channel given its ID and the message's content.
    # @param channel_id [Integer] The ID that identifies the channel to send something to.
    # @param content [String] The text that should be sent as a message. It is limited to 2000 characters (Discord imposed).
    # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
    # @param embed [Hash, Discordrb::Webhooks::Embed, nil] The rich embed to append to this message.
    # @return [Message] The message that was sent.
    def send_message(channel_id, content, tts = false, embed = nil)
      channel_id = channel_id.resolve_id
      debug("Sending message to #{channel_id} with content '#{content}'")

      response = API::Channel.create_message(token, channel_id, content, [], tts, embed ? embed.to_hash : nil)
      Message.new(JSON.parse(response), self)
    end

    # Sends a text message to a channel given its ID and the message's content,
    # then deletes it after the specified timeout in seconds.
    # @param channel_id [Integer] The ID that identifies the channel to send something to.
    # @param content [String] The text that should be sent as a message. It is limited to 2000 characters (Discord imposed).
    # @param timeout [Float] The amount of time in seconds after which the message sent will be deleted.
    # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
    # @param embed [Hash, Discordrb::Webhooks::Embed, nil] The rich embed to append to this message.
    def send_temporary_message(channel_id, content, timeout, tts = false, embed = nil)
      Thread.new do
        message = send_message(channel_id, content, tts, embed)

        sleep(timeout)

        message.delete
      end

      nil
    end

    # Sends a file to a channel. If it is an image, it will automatically be embedded.
    # @note This executes in a blocking way, so if you're sending long files, be wary of delays.
    # @param channel_id [Integer] The ID that identifies the channel to send something to.
    # @param file [File] The file that should be sent.
    # @param caption [string] The caption for the file.
    # @param tts [true, false] Whether or not this file's caption should be sent using Discord text-to-speech.
    def send_file(channel_id, file, caption: nil, tts: false)
      response = API::Channel.upload_file(token, channel_id, file, caption: caption, tts: tts)
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
      response = API::Server.create(token, name, region)
      id = JSON.parse(response)['id'].to_i
      sleep 0.1 until @servers[id]
      server = @servers[id]
      debug "Successfully created server #{server.id} with name #{server.name}"
      server
    end

    # Creates a new application to do OAuth authorization with. This allows you to use OAuth to authorize users using
    # Discord. For information how to use this, see the docs: https://discordapp.com/developers/docs/topics/oauth2
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

    # Gets the user, role or emoji from a mention of the user, role or emoji.
    # @param mention [String] The mention, which should look like `<@12314873129>`, `<@&123456789>` or `<:Name:126328:>`.
    # @param server [Server, nil] The server of the associated mention. (recommended for role parsing, to speed things up)
    # @return [User, Role, Emoji] The user, role or emoji identified by the mention, or `nil` if none exists.
    def parse_mention(mention, server = nil)
      # Mention format: <@id>
      if /<@!?(?<id>\d+)>?/ =~ mention
        user(id.to_i)
      elsif /<@&(?<id>\d+)>?/ =~ mention
        return server.role(id.to_i) if server
        @servers.values.each do |element|
          role = element.role(id.to_i)
          return role unless role.nil?
        end

        # Return nil if no role is found
        nil
      elsif /<:(\w+):(?<id>\d+)>?/ =~ mention
        emoji.find { |element| element.id.to_i == id.to_i }
      end
    end

    # Updates presence status.
    # @param status [String] The status the bot should show up as.
    # @param game [String, nil] The name of the game to be played/stream name on the stream.
    # @param url [String, nil] The Twitch URL to display as a stream. nil for no stream.
    # @param since [Integer] When this status was set.
    # @param afk [true, false] Whether the bot is AFK.
    # @see Gateway#send_status_update
    def update_status(status, game, url, since = 0, afk = false)
      gateway_check

      @game = game
      @status = status
      @streamurl = url
      type = url ? 1 : 0

      game_obj = game || url ? { name: game, url: url, type: type } : nil
      @gateway.send_status_update(status, since, game_obj, afk)
    end

    # Sets the currently playing game to the specified game.
    # @param name [String] The name of the game to be played.
    # @return [String] The game that is being played now.
    def game=(name)
      gateway_check
      update_status(@status, name, nil)
      name
    end

    # Sets the currently online stream to the specified name and Twitch URL.
    # @param name [String] The name of the stream to display.
    # @param url [String] The url of the current Twitch stream.
    # @return [String] The stream name that is being displayed now.
    def stream(name, url)
      gateway_check
      update_status(@status, name, url)
      name
    end

    # Sets status to online.
    def online
      gateway_check
      update_status(:online, @game, @streamurl)
    end

    alias_method :on, :online

    # Sets status to idle.
    def idle
      gateway_check
      update_status(:idle, @game, nil)
    end

    alias_method :away, :idle

    # Sets the bot's status to DnD (red icon).
    def dnd
      gateway_check
      update_status(:dnd, @game, nil)
    end

    # Sets the bot's status to invisible (appears offline).
    def invisible
      gateway_check
      update_status(:invisible, @game, nil)
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

    # Add a user to the list of ignored users. Those users will be ignored in message events at event processing level.
    # @note Ignoring a user only prevents any message events (including mentions, commands etc.) from them! Typing and
    #   presence and any other events will still be received.
    # @param user [User, Integer, #resolve_id] The user, or its ID, to be ignored.
    def ignore_user(user)
      @ignored_ids << user.resolve_id
    end

    # Remove a user from the ignore list.
    # @param user [User, Integer, #resolve_id] The user, or its ID, to be unignored.
    def unignore_user(user)
      @ignored_ids.delete(user.resolve_id)
    end

    # Checks whether a user is being ignored.
    # @param user [User, Integer, #resolve_id] The user, or its ID, to check.
    # @return [true, false] whether or not the user is ignored.
    def ignored?(user)
      @ignored_ids.include?(user.resolve_id)
    end

    # @see Logger#debug
    def debug(message)
      LOGGER.debug(message)
    end

    # @see Logger#log_exception
    def log_exception(e)
      LOGGER.log_exception(e)
    end

    # Dispatches an event to this bot. Called by the gateway connection handler used internally.
    def dispatch(type, data)
      handle_dispatch(type, data)
    end

    # Raises a heartbeat event. Called by the gateway connection handler used internally.
    def raise_heartbeat_event
      raise_event(HeartbeatEvent.new(self))
    end

    def prune_empty_groups
      @channels.each_value do |channel|
        channel.leave_group if channel.group? && channel.recipients.empty?
      end
    end

    private

    # Throws a useful exception if there's currently no gateway connection
    def gateway_check
      return if connected?

      raise "A gateway connection is necessary to call this method! You'll have to do it inside any event (e.g. `ready`) or after `bot.run :async`."
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
      # Friends list presences have no server ID so ignore these to not cause an error
      return unless data['guild_id']

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

      member.update_presence(data)

      member.avatar_id = data['user']['avatar'] if data['user']['avatar']

      server.cache_member(member)
    end

    # Internal handler for VOICE_STATE_UPDATE
    def update_voice_state(data)
      @session_id = data['session_id']

      server_id = data['guild_id'].to_i
      server = server(server_id)
      return unless server

      user_id = data['user_id'].to_i
      old_voice_state = server.voice_states[user_id]
      old_channel_id = old_voice_state.voice_channel.id if old_voice_state

      server.update_voice_state(data)

      old_channel_id
    end

    # Internal handler for VOICE_SERVER_UPDATE
    def update_voice_server(data)
      server_id = data['guild_id'].to_i
      channel = @should_connect_to_voice[server_id]

      debug("Voice server update received! chan: #{channel.inspect}")
      return unless channel
      @should_connect_to_voice.delete(server_id)
      debug('Updating voice server!')

      token = data['token']
      endpoint = data['endpoint']

      unless endpoint
        debug('VOICE_SERVER_UPDATE sent with nil endpoint! Ignoring')
        return
      end

      debug('Got data, now creating the bot.')
      @voices[server_id] = Discordrb::Voice::VoiceBot.new(channel, self, token, @session_id, endpoint, @should_encrypt_voice)
    end

    # Internal handler for CHANNEL_CREATE
    def create_channel(data)
      channel = Channel.new(data, self)
      server = channel.server

      # Handle normal and private channels separately
      if server
        server.add_channel(channel)
        @channels[channel.id] = channel
      elsif channel.pm?
        @pm_channels[channel.recipient.id] = channel
      elsif channel.group?
        @channels[channel.id] = channel
      end
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

      # Handle normal and private channels separately
      if server
        @channels.delete(channel.id)
        server.delete_channel(channel.id)
      elsif channel.pm?
        @pm_channels.delete(channel.recipient.id)
      elsif channel.group?
        @channels.delete(channel.id)
      end
    end

    # Internal handler for CHANNEL_RECIPIENT_ADD
    def add_recipient(data)
      channel_id = data['channel_id'].to_i
      channel = self.channel(channel_id)

      recipient_user = ensure_user(data['user'])
      recipient = Recipient.new(recipient_user, channel, self)
      channel.add_recipient(recipient)
    end

    # Internal handler for CHANNEL_RECIPIENT_REMOVE
    def remove_recipient(data)
      channel_id = data['channel_id'].to_i
      channel = self.channel(channel_id)

      recipient_user = ensure_user(data['user'])
      recipient = Recipient.new(recipient_user, channel, self)
      channel.remove_recipient(recipient)
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
      member.update_nick(data['nick'])
    end

    # Internal handler for GUILD_MEMBER_DELETE
    def delete_guild_member(data)
      server_id = data['guild_id'].to_i
      server = self.server(server_id)

      user_id = data['user']['id'].to_i
      server.delete_member(user_id)
    rescue Discordrb::Errors::NoPermission
      Discordrb::LOGGER.warn("delete_guild_member attempted to access a server for which the bot doesn't have permission! Not sure what happened here, ignoring")
    end

    # Internal handler for GUILD_CREATE
    def create_guild(data)
      ensure_server(data)
    end

    # Internal handler for GUILD_UPDATE
    def update_guild(data)
      @servers[data['id'].to_i].update_data(data)
    end

    # Internal handler for GUILD_DELETE
    def delete_guild(data)
      id = data['id'].to_i
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

    # Internal handler for GUILD_EMOJIS_UPDATE
    def update_guild_emoji(data)
      server_id = data['guild_id'].to_i
      server = @servers[server_id]
      server.update_emoji_data(data)
    end

    # Internal handler for MESSAGE_CREATE
    def create_message(data); end

    # Internal handler for TYPING_START
    def start_typing(data); end

    # Internal handler for MESSAGE_UPDATE
    def update_message(data); end

    # Internal handler for MESSAGE_DELETE
    def delete_message(data); end

    # Internal handler for MESSAGE_REACTION_ADD
    def add_message_reaction(data); end

    # Internal handler for MESSAGE_REACTION_REMOVE
    def remove_message_reaction(data); end

    # Internal handler for MESSAGE_REACTION_REMOVE_ALL
    def remove_all_message_reactions(data); end

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

    def process_token(type, token)
      # Remove the "Bot " prefix if it exists
      token = token[4..-1] if token.start_with? 'Bot '

      token = 'Bot ' + token unless type == :user
      token
    end

    def handle_dispatch(type, data)
      # Check whether there are still unavailable servers and there have been more than 10 seconds since READY
      if @unavailable_servers && @unavailable_servers > 0 && (Time.now - @unavailable_timeout_time) > 10
        # The server streaming timed out!
        LOGGER.warn("Server streaming timed out with #{@unavailable_servers} servers remaining")
        LOGGER.warn("This means some servers are unavailable due to an outage. Notifying ready now, we'll have to live without these servers")

        # Unset the unavailable server count so this doesn't get triggered again
        @unavailable_servers = 0

        notify_ready
      end

      case type
      when :READY
        # As READY may be called multiple times over a single process lifetime, we here need to reset the cache entirely
        # to prevent possible inconsistencies, like objects referencing old versions of other objects which have been
        # replaced.
        init_cache

        @profile = Profile.new(data['user'], self)

        # Initialize servers
        @servers = {}

        # Count unavailable servers
        @unavailable_servers = 0

        data['guilds'].each do |element|
          # Check for true specifically because unavailable=false indicates that a previously unavailable server has
          # come online
          if element['unavailable'].is_a? TrueClass
            @unavailable_servers += 1

            # Ignore any unavailable servers
            next
          end

          ensure_server(element)
        end

        # Add PM and group channels
        data['private_channels'].each do |element|
          channel = ensure_channel(element)
          if channel.pm?
            @pm_channels[channel.recipient.id] = channel
          else
            @channels[channel.id] = channel
          end
        end

        # Don't notify yet if there are unavailable servers because they need to get available before the bot truly has
        # all the data
        if @unavailable_servers.zero?
          # No unavailable servers - we're ready!
          notify_ready
        end

        @ready_time = Time.now
        @unavailable_timeout_time = Time.now
      when :GUILD_MEMBERS_CHUNK
        id = data['guild_id'].to_i
        server = server(id)
        server.process_chunk(data['members'])
      when :MESSAGE_CREATE
        if ignored?(data['author']['id'].to_i)
          debug("Ignored author with ID #{data['author']['id']}")
          return
        end

        if @ignore_bots && data['author']['bot']
          debug("Ignored Bot account with ID #{data['author']['id']}")
          return
        end

        # If create_message is overwritten with a method that returns the parsed message, use that instead, so we don't
        # parse the message twice (which is just thrown away performance)
        message = create_message(data)
        message = Message.new(data, self) unless message.is_a? Message

        return if message.from_bot? && !should_parse_self

        event = MessageEvent.new(message, self)
        raise_event(event)

        if message.mentions.any? { |user| user.id == @profile.id }
          event = MentionEvent.new(message, self)
          raise_event(event)
        end

        if message.channel.private?
          event = PrivateMessageEvent.new(message, self)
          raise_event(event)
        end
      when :MESSAGE_UPDATE
        update_message(data)

        message = Message.new(data, self)
        return if message.from_bot? && !should_parse_self

        unless message.author
          LOGGER.debug("Edited a message with nil author! Content: #{message.content.inspect}, channel: #{message.channel.inspect}")
          return
        end

        event = MessageEditEvent.new(message, self)
        raise_event(event)
      when :MESSAGE_DELETE
        delete_message(data)

        event = MessageDeleteEvent.new(data, self)
        raise_event(event)
      when :MESSAGE_DELETE_BULK
        debug("MESSAGE_DELETE_BULK will raise #{data['ids'].length} events")

        data['ids'].each do |single_id|
          # Form a data hash for a single ID so the methods get what they want
          single_data = {
            'id' => single_id,
            'channel_id' => data['channel_id']
          }

          # Raise as normal
          delete_message(single_data)

          event = MessageDeleteEvent.new(single_data, self)
          raise_event(event)
        end
      when :TYPING_START
        start_typing(data)

        begin
          event = TypingEvent.new(data, self)
          raise_event(event)
        rescue Discordrb::Errors::NoPermission
          debug 'Typing started in channel the bot has no access to, ignoring'
        end
      when :MESSAGE_REACTION_ADD
        add_message_reaction(data)

        event = ReactionAddEvent.new(data, self)
        raise_event(event)
      when :MESSAGE_REACTION_REMOVE
        remove_message_reaction(data)

        event = ReactionRemoveEvent.new(data, self)
        raise_event(event)
      when :MESSAGE_REACTION_REMOVE_ALL
        remove_all_message_reactions(data)

        event = ReactionRemoveAllEvent.new(data, self)
        raise_event(event)
      when :PRESENCE_UPDATE
        # Ignore friends list presences
        return unless data['guild_id']

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
        old_channel_id = update_voice_state(data)

        event = VoiceStateUpdateEvent.new(data, old_channel_id, self)
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
      when :CHANNEL_RECIPIENT_ADD
        add_recipient(data)

        event = ChannelRecipientAddEvent.new(data, self)
        raise_event(event)
      when :CHANNEL_RECIPIENT_REMOVE
        remove_recipient(data)

        event = ChannelRecipientRemoveEvent.new(data, self)
        raise_event(event)
      when :GUILD_MEMBER_ADD
        add_guild_member(data)

        event = ServerMemberAddEvent.new(data, self)
        raise_event(event)
      when :GUILD_MEMBER_UPDATE
        update_guild_member(data)

        event = ServerMemberUpdateEvent.new(data, self)
        raise_event(event)
      when :GUILD_MEMBER_REMOVE
        delete_guild_member(data)

        event = ServerMemberDeleteEvent.new(data, self)
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

        event = ServerRoleUpdateEvent.new(data, self)
        raise_event(event)
      when :GUILD_ROLE_CREATE
        create_guild_role(data)

        event = ServerRoleCreateEvent.new(data, self)
        raise_event(event)
      when :GUILD_ROLE_DELETE
        delete_guild_role(data)

        event = ServerRoleDeleteEvent.new(data, self)
        raise_event(event)
      when :GUILD_CREATE
        create_guild(data)

        # Check for false specifically (no data means the server has never been unavailable)
        if data['unavailable'].is_a? FalseClass
          @unavailable_servers -= 1 if @unavailable_servers
          @unavailable_timeout_time = Time.now

          notify_ready if @unavailable_servers.zero?

          # Return here so the event doesn't get triggered
          return
        end

        event = ServerCreateEvent.new(data, self)
        raise_event(event)
      when :GUILD_UPDATE
        update_guild(data)

        event = ServerUpdateEvent.new(data, self)
        raise_event(event)
      when :GUILD_DELETE
        delete_guild(data)

        if data['unavailable'].is_a? TrueClass
          LOGGER.warn("Server #{data['id']} is unavailable due to an outage!")
          return # Don't raise an event
        end

        event = ServerDeleteEvent.new(data, self)
        raise_event(event)
      when :GUILD_EMOJIS_UPDATE
        server_id = data['guild_id'].to_i
        server = @servers[server_id]
        old_emoji_data = server.emoji.clone
        update_guild_emoji(data)
        new_emoji_data = server.emoji

        created_ids = new_emoji_data.keys - old_emoji_data.keys
        deleted_ids = old_emoji_data.keys - new_emoji_data.keys
        updated_ids = old_emoji_data.select do |k, v|
          new_emoji_data[k] && (v.name != new_emoji_data[k].name || v.roles != new_emoji_data[k].roles)
        end.keys

        event = ServerEmojiChangeEvent.new(server, data, self)
        raise_event(event)

        created_ids.each do |e|
          event = ServerEmojiCreateEvent.new(server, new_emoji_data[e], self)
          raise_event(event)
        end

        deleted_ids.each do |e|
          event = ServerEmojiDeleteEvent.new(server, old_emoji_data[e], self)
          raise_event(event)
        end

        updated_ids.each do |e|
          event = ServerEmojiUpdateEvent.new(server, old_emoji_data[e], new_emoji_data[e], self)
          raise_event(event)
        end
      else
        # another event that we don't support yet
        debug "Event #{type} has been received but is unsupported. Raising UnknownEvent"

        event = UnknownEvent.new(type, data, self)
        raise_event(event)
      end

      # The existence of this array is checked before for performance reasons, since this has to be done for *every*
      # dispatch.
      if @event_handlers && @event_handlers[RawEvent]
        event = RawEvent.new(type, data, self)
        raise_event(event)
      end
    rescue Exception => e
      LOGGER.error('Gateway message error!')
      log_exception(e)
    end

    # Notifies everything there is to be notified that the connection is now ready
    def notify_ready
      # Make sure to raise the event
      raise_event(ReadyEvent.new(self))
      LOGGER.good 'Ready'

      @gateway.notify_ready
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
