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
  # Gateway packet opcodes
  module Opcodes
    # **Received** when Discord dispatches an event to the gateway (like MESSAGE_CREATE, PRESENCE_UPDATE or whatever).
    # The vast majority of received packets will have this opcode.
    DISPATCH = 0

    # **Two-way**: The client has to send a packet with this opcode every ~40 seconds (actual interval specified in
    # READY or RESUMED) and the current sequence number, otherwise it will be disconnected from the gateway. In certain
    # cases Discord may also send one, specifically if two clients are connected at once.
    HEARTBEAT = 1

    # **Sent**: This is one of the two possible ways to initiate a session after connecting to the gateway. It
    # should contain the authentication token along with other stuff the server has to know right from the start, such
    # as large_threshold and, for older gateway versions, the desired version.
    IDENTIFY = 2

    # **Sent**: Packets with this opcode are used to change the user's status and played game. (Sending this is never
    # necessary for a gateway client to behave correctly)
    PRESENCE = 3

    # **Sent**: Packets with this opcode are used to change a user's voice state (mute/deaf/unmute/undeaf/etc.). It is
    # also used to connect to a voice server in the first place. (Sending this is never necessary for a gateway client
    # to behave correctly)
    VOICE_STATE = 4

    # **Sent**: This opcode is used to ping a voice server, whatever that means. The functionality of this opcode isn't
    # known well but non-user clients should never send it.
    VOICE_PING = 5

    # **Sent**: This is the other of two possible ways to initiate a gateway session (other than {IDENTIFY}). Rather
    # than starting an entirely new session, it resumes an existing session by replaying all events from a given
    # sequence number. It should be used to recover from a connection error or anything like that when the session is
    # still valid - sending this with an invalid session will cause an error to occur.
    RESUME = 6

    # **Received**: Discord sends this opcode to indicate that the client should reconnect to a different gateway
    # server because the old one is currently being decommissioned. Counterintuitively, this opcode also invalidates the
    # session - the client has to create an entirely new session with the new gateway instead of resuming the old one.
    RECONNECT = 7

    # **Sent**: This opcode identifies packets used to retrieve a list of members from a particular server. There is
    # also a REST endpoint available for this, but it is inconvenient to use because the client has to implement
    # pagination itself, whereas sending this opcode lets Discord handle the pagination and the client can just add
    # members when it receives them. (Sending this is never necessary for a gateway client to behave correctly)
    REQUEST_MEMBERS = 8

    # **Received**: The functionality of this opcode is less known than the others but it appears to specifically
    # tell the client to invalidate its local session and continue by {IDENTIFY}ing.
    INVALIDATE_SESSION = 9

    # **Received**: Sent immediately for any opened connection; tells the client to start heartbeating early on, so the
    # server can safely search for a session server to handle the connection without the connection being terminated.
    # As a side-effect, large bots are less likely to disconnect because of very large READY parse times.
    HELLO = 10

    # **Received**: Returned after a heartbeat was sent to the server. This allows clients to identify and deal with
    # zombie connections that don't dispatch any events anymore.
    HEARTBEAT_ACK = 11
  end

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
    # @param parse_self [true, false] Whether the bot should react on its own messages. It's best to turn this off
    #   unless you really need this so you don't inadvertently create infinite loops.
    # @param shard_id [Integer] The number of the shard this bot should handle. See
    #   https://github.com/hammerandchisel/discord-api-docs/issues/17 for how to do sharding.
    # @param num_shards [Integer] The total number of shards that should be running. See
    #   https://github.com/hammerandchisel/discord-api-docs/issues/17 for how to do sharding.
    def initialize(
        email: nil, password: nil, log_mode: :normal,
        token: nil, application_id: nil,
        type: nil, name: '', fancy_log: false, suppress_ready: false, parse_self: false,
        shard_id: nil, num_shards: nil)
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

      @should_parse_self = parse_self

      @email = email
      @password = password

      @application_id = application_id

      @type = determine_account_type(type, email, password, token, application_id)

      @name = name

      @shard_key = num_shards ? [shard_id, num_shards] : nil

      LOGGER.fancy = fancy_log
      @prevent_ready = suppress_ready

      debug('Creating token cache')
      token_cache = Discordrb::TokenCache.new
      debug('Token cache created successfully')
      @token = login(type, email, password, token, token_cache)

      init_cache

      @voices = {}
      @should_connect_to_voice = {}

      @ignored_ids = Set.new

      @event_threads = []
      @current_thread = 0

      @idletime = nil

      # Whether the connection to the gateway has succeeded yet
      @ws_success = false
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

    # The bot's user profile. This special user object can be used
    # to edit user data like the current username (see {Profile#username=}).
    # @return [Profile] The bot's profile that can be used to edit data.
    def profile
      gateway_check
      @profile
    end

    alias_method :bot_user, :profile

    # The bot's OAuth application.
    # @return [Application, nil] The bot's applicatino info. Returns `nil` if bot is not a bot account.
    def bot_application
      gateway_check
      profile.bot_account? ? Cache.application(@application_id) : nil
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
          if @heartbeat_active
            send_heartbeat
            sleep @heartbeat_interval
          else
            sleep 1
          end
        end
      end

      @ws_thread = Thread.new do
        Thread.current[:discordrb_name] = 'websocket'

        # Initialize falloff so we wait for more time before reconnecting each time
        @falloff = 1.0

        loop do
          @should_reconnect = true
          websocket_connect

          break unless @should_reconnect

          if @reconnect_url
            # We got an op 7! Don't wait before reconnecting
            LOGGER.info('Got an op 7, reconnecting right away')
          else
            wait_for_reconnect
          end

          # Restart the loop, i. e. reconnect
        end

        LOGGER.warn('The WS loop exited! Not sure if this is a good thing')
      end

      debug('WS thread created! Now waiting for confirmation that everything worked')
      sleep(0.5) until @ws_success
      debug('Confirmation received! Exiting run.')
    end

    # Prevents all further execution until the websocket thread stops (e. g. through a closed connection).
    def sync
      @ws_thread.join
    end

    # Stops the bot gracefully, disconnecting the websocket without immediately killing the thread. This means that
    # Discord is immediately aware of the closed connetion and makes the bot appear offline instantly.
    #
    # If this method doesn't work or you're looking for something more drastic, use {#kill} instead.
    def stop
      @should_reconnect = false
      @ws.close
    end

    # Kills the websocket thread, stopping all connections to Discord.
    def kill
      @ws_thread.kill
    end

    # @return [true, false] whether or not the bot is currently connected to Discord.
    def connected?
      @ws_success
    end

    # Makes the bot join an invite to a server.
    # @param invite [String, Invite] The invite to join. For possible formats see {#resolve_invite_code}.
    def join(invite)
      resolved = invite(invite).code
      API.join_server(token, resolved)
    end

    # Creates an OAuth invite URL that can be used to invite this bot to a particular server.
    # Requires the application ID to have been set during initialization.
    # @param server [Server, nil] The server the bot should be invited to, or nil if a general invite should be created.
    # @return [String] the OAuth invite URL.
    def invite_url(server = nil)
      raise 'No application ID has been set during initialization! Add one as the `application_id` named parameter while creating your bot.' unless @application_id

      guild_id_str = server ? "&guild_id=#{server.id}" : ''
      "https://discordapp.com/oauth2/authorize?&client_id=#{@application_id}#{guild_id_str}&scope=bot"
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

      data = {
        op: Opcodes::VOICE_STATE,
        d: {
          guild_id: server_id.to_s,
          channel_id: chan.id.to_s,
          self_mute: false,
          self_deaf: false
        }
      }
      debug("Voice channel init packet is: #{data.to_json}")

      @should_connect_to_voice[server_id] = chan
      @ws.send(data.to_json)
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
      data = {
        op: Opcodes::VOICE_STATE,
        d: {
          guild_id: server_id.to_s,
          channel_id: nil,
          self_mute: false,
          self_deaf: false
        }
      }

      debug("Voice channel destroy packet is: #{data.to_json}")
      @ws.send(data.to_json)

      @voices[server_id].destroy if @voices[server_id] && destroy_vws
      @voices.delete(server_id)
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
    # @param server_id [Integer] The ID that identifies the server to send something to.
    # @return [Message] The message that was sent.
    def send_message(channel_id, content, tts = false, server_id = nil)
      channel_id = channel_id.resolve_id
      debug("Sending message to #{channel_id} with content '#{content}'")

      response = API.send_message(token, channel_id, content, [], tts, server_id)
      Message.new(JSON.parse(response), self)
    end

    # Sends a text message to a channel given its ID and the message's content,
    # then deletes it after the specified timeout in seconds.
    # @param channel_id [Integer] The ID that identifies the channel to send something to.
    # @param content [String] The text that should be sent as a message. It is limited to 2000 characters (Discord imposed).
    # @param timeout [Float] The amount of time in seconds after which the message sent will be deleted.
    # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
    # @param server_id [Integer] The ID that identifies the server to send something to.
    def send_temporary_message(channel_id, content, timeout, tts = false, server_id = nil)
      Thread.new do
        message = send_message(channel_id, content, tts, server_id)

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
      response = API.send_file(token, channel_id, file, caption: caption, tts: tts)
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

    # Gets the user from a mention of the user.
    # @param mention [String] The mention, which should look like <@12314873129>.
    # @return [User] The user identified by the mention, or `nil` if none exists.
    def parse_mention(mention)
      # Mention format: <@id>
      return nil unless /<@!?(?<id>\d+)>?/ =~ mention
      user(id.to_i)
    end

    # Updates presence status.
    # @param idletime [Integer, nil] The floating point of a Time object that shows the last time the bot was on.
    # @param game [String, nil] The name of the game to be played/stream name on the stream.
    # @param url [String, nil] The Twitch URL to display as a stream. nil for no stream.
    def update_status(idletime, game, url)
      gateway_check

      @game = game
      @idletime = idletime
      @streamurl = url
      type = url ? 1 : nil
      data = {
        op: Opcodes::PRESENCE,
        d: {
          idle_since: idletime,
          game: game || url ? { name: game, url: url, type: type } : nil
        }
      }
      @ws.send(data.to_json)
    end

    # Sets the currently playing game to the specified game.
    # @param name [String] The name of the game to be played.
    # @return [String] The game that is being played now.
    def game=(name)
      gateway_check
      update_status(@idletime, name, nil)
      name
    end

    # Sets the currently online stream to the specified name and Twitch URL.
    # @param name [String] The name of the stream to display.
    # @param url [String] The url of the current Twitch stream.
    # @return [String] The stream name that is being displayed now.
    def stream(name, url)
      gateway_check
      update_status(@idletime, name, url)
      name
    end

    # Sets status to online.
    def online
      gateway_check
      update_status(nil, @game, @streamurl)
    end
    alias_method :on, :online

    # Sets status to idle.
    def idle
      gateway_check
      update_status((Time.now.to_f * 1000), @game, nil)
    end
    alias_method :away, :idle

    # Injects a reconnect event (op 7) into the event processor, causing Discord to reconnect to the given gateway URL.
    # If the URL is set to nil, it will reconnect and get an entirely new gateway URL. This method has not much use
    # outside of testing and implementing highly custom reconnect logic.
    # @param url [String, nil] the URL to connect to or nil if one should be obtained from Discord.
    def inject_reconnect(url)
      websocket_message({
        op: Opcodes::RECONNECT,
        d: {
          url: url
        }
      }.to_json)
    end

    # Injects a resume packet (op 6) into the gateway. If this is done with a running connection, it will cause an
    # error. It has no use outside of testing stuff that I know of, but if you want to use it anyway for some reason,
    # here it is.
    # @param seq [Integer, nil] The sequence ID to inject, or nil if the currently tracked one should be used.
    def inject_resume(seq)
      resume(seq || @sequence, raw_token, @session_id)
    end

    # Injects a terminal gateway error into the handler. Useful for testing the reconnect logic.
    # @param e [Exception] The exception object to inject.
    def inject_error(e)
      websocket_error(e)
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
      # Friends list presences have no guild ID so ignore these to not cause an error
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

      member.status = data['status'].to_sym
      member.game = data['game'] ? data['game']['name'] : nil

      server.cache_member(member)
    end

    # Internal handler for VOICE_STATUS_UPDATE
    def update_voice_state(data)
      server_id = data['guild_id'].to_i
      server = server(server_id)
      return unless server

      server.update_voice_state(data)

      @session_id = data['session_id']
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
        server.channels << channel
        @channels[channel.id] = channel
      else
        @private_channels[channel.id] = channel
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
        server.channels.reject! { |c| c.id == channel.id }
      else
        @private_channels.delete(channel.id)
      end
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
      token = token[4..-1] if token.start_with? 'Bot '

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
      # If the reconnect URL is set, it means we got an op 7 earlier and should reconnect to the new URL
      if @reconnect_url
        debug("Reconnecting to URL #{@reconnect_url}")
        url = @reconnect_url
        @reconnect_url = nil # Unset the URL so we don't connect to the same URL again if the connection fails
        url
      else
        # Get the correct gateway URL from Discord
        response = API.gateway(token)
        JSON.parse(response)['url']
      end
    end

    def process_gateway
      raw_url = find_gateway

      # Append a slash in case it's not there (I'm not sure how well WSCS handles it otherwise)
      raw_url += '/' unless raw_url.end_with? '/'

      # Add the parameters we want
      raw_url + "?encoding=json&v=#{GATEWAY_VERSION}"
    end

    ##      ##  ######     ######## ##     ## ######## ##    ## ########  ######
    ##  ##  ## ##    ##    ##       ##     ## ##       ###   ##    ##    ##    ##
    ##  ##  ## ##          ##       ##     ## ##       ####  ##    ##    ##
    ##  ##  ##  ######     ######   ##     ## ######   ## ## ##    ##     ######
    ##  ##  ##       ##    ##        ##   ##  ##       ##  ####    ##          ##
    ##  ##  ## ##    ##    ##         ## ##   ##       ##   ###    ##    ##    ##
    ####  ###   ######     ########    ###    ######## ##    ##    ##     ######

    # Desired gateway version
    GATEWAY_VERSION = 5

    def websocket_connect
      debug('Attempting to get gateway URL...')
      gateway_url = process_gateway
      debug("Success! Gateway URL is #{gateway_url}.")
      debug('Now running bot')

      @ws = Discordrb::WebSocket.new(
        gateway_url,
        method(:websocket_open),
        method(:websocket_message),
        method(:websocket_close),
        method(:websocket_error)
      )

      @ws.thread[:discordrb_name] = 'gateway'
      @ws.thread.join
    rescue => e
      LOGGER.error 'Error while connecting to the gateway!'
      LOGGER.log_exception e
      raise
    end

    def websocket_reconnect(url)
      # In here, we do nothing except set the reconnect URL and close the current connection.
      @reconnect_url = url
      @ws.close

      # Reset the packet sequence number so we don't try to resume the connection afterwards
      @sequence = 0

      # Let's hope the reconnect handler reconnects us correctly...
    end

    def websocket_message(event)
      if event.byteslice(0) == 'x'
        # The message is encrypted
        event = Zlib::Inflate.inflate(event)
      end

      # Parse packet
      packet = JSON.parse(event)

      if @prevent_ready && packet['t'] == 'READY'
        debug('READY packet was received and suppressed')
      elsif @prevent_ready && packet['t'] == 'GUILD_MEMBERS_CHUNK'
        # Ignore chunks as they will be handled later anyway
      else
        LOGGER.in(event.to_s)
      end

      opcode = packet['op'].to_i

      if opcode == Opcodes::HEARTBEAT
        # If Discord sends us a heartbeat, simply reply with a heartbeat with the packet's sequence number
        @sequence = packet['s'].to_i

        LOGGER.info("Received an op1 (seq: #{@sequence})! This means another client connected while this one is already running. Replying with the same seq")
        send_heartbeat

        return
      end

      if opcode == Opcodes::RECONNECT
        websocket_reconnect(packet['d'] ? packet['d']['url'] : nil)
        return
      end

      if opcode == Opcodes::INVALIDATE_SESSION
        LOGGER.info "We got an opcode 9 from Discord! Invalidating the session. You probably don't have to worry about this."
        invalidate_session
        LOGGER.debug 'Session invalidated!'

        LOGGER.debug 'Reconnecting with IDENTIFY'
        websocket_open # Since we just invalidated the session, pretending we just opened the WS again will re-identify
        LOGGER.debug "Re-identified! Let's hope everything works fine."
        return
      end

      if opcode == Opcodes::HELLO
        LOGGER.debug 'Hello!'

        # Initialize sequence with 0 so we can start heartbeating without being in a session
        @sequence = 0

        # Activate the heartbeats
        @heartbeat_interval = packet['d']['heartbeat_interval'].to_f / 1000.0
        @heartbeat_active = true
        debug("Desired heartbeat_interval: #{@heartbeat_interval} seconds")

        debug("Trace: #{packet['d']['_trace']}")

        return
      end

      if opcode == Opcodes::HEARTBEAT_ACK
        # Set this to false so when sending the next heartbeat it won't try to reconnect because it's still expecting
        # an ACK
        @awaiting_ack = false
        return
      end

      raise "Got an unexpected opcode (#{opcode}) in a gateway event!
              Please report this issue along with the following information:
              v#{GATEWAY_VERSION} #{packet}" unless opcode == Opcodes::DISPATCH

      # Check whether there are still unavailable servers and there have been more than 10 seconds since READY
      if @unavailable_servers && @unavailable_servers > 0 && (Time.now - @unavailable_timeout_time) > 10
        # The server streaming timed out!
        LOGGER.warn("Server streaming timed out with #{@unavailable_servers} servers remaining")
        LOGGER.warn("This means some servers are unavailable due to an outage. Notifying ready now, we'll have to live without these servers")

        # Unset the unavailable server count so this doesn't get triggered again
        @unavailable_servers = nil

        notify_ready
      end

      # Keep track of the packet sequence (continually incrementing number for every packet) so we can resume a
      # connection if we disconnect
      @sequence = packet['s'].to_i

      data = packet['d']
      type = packet['t'].intern
      case type
      when :READY
        LOGGER.info("Discord using gateway protocol version: #{data['v']}, requested: #{GATEWAY_VERSION}")

        # Set the session ID in case we get disconnected and have to resume
        @session_id = data['session_id']

        @profile = Profile.new(data['user'], self, @email, @password)

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

        # Add private channels
        data['private_channels'].each do |element|
          channel = ensure_channel(element)
          @private_channels[channel.recipient.id] = channel
        end

        # Don't notify yet if there are unavailable servers because they need to get available before the bot truly has
        # all the data
        if @unavailable_servers == 0
          # No unavailable servers - we're ready!
          notify_ready
        end

        @ready_time = Time.now
        @unavailable_timeout_time = Time.now
      when :RESUMED
        # The RESUMED event is received after a successful op 6 (resume). It does nothing except tell the bot the
        # connection is initiated (like READY would). Starting with v5, it doesn't set a new heartbeat interval anymore
        # since that is handled by op 10 (HELLO).
        debug('Connection resumed')
      when :GUILD_MEMBERS_CHUNK
        id = data['guild_id'].to_i
        server = server(id)
        server.process_chunk(data['members'])
      when :MESSAGE_CREATE
        if ignored?(data['author']['id'].to_i)
          debug("Ignored author with ID #{data['author']['id']}")
          return
        end

        create_message(data)

        message = Message.new(data, self)

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

          notify_ready if @unavailable_servers == 0

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

        event = ServerDeleteEvent.new(data, self)
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
      # Don't handle nil events (for example if the disconnect came from our side)
      return unless event

      # Handle actual close frames and errors separately
      if event.respond_to? :code
        LOGGER.error(%(Disconnected from WebSocket - code #{event.code} with reason: "#{event.data}"))

        if event.code.to_i == 4006
          # If we got disconnected with a 4006, it means we sent a resume when Discord wanted an identify. To battle this,
          # we invalidate the local session so we'll just send an identify next time
          debug('Apparently we just sent the wrong type of initiation packet (resume rather than identify) to Discord. (Sorry!)
                Invalidating session so this is fixed next time')
          invalidate_session
        end
      else
        LOGGER.error('Disconnected from WebSocket due to an exception!')
        LOGGER.log_exception event
      end

      raise_event(DisconnectEvent.new(self))

      # Stop sending heartbeats
      @heartbeat_active = false

      # Safely close the WS connection and handle any errors that occur there
      begin
        @ws.close
      rescue => e
        LOGGER.warn 'Got the following exception while closing the WS after being disconnected:'
        LOGGER.log_exception e
      end
    rescue => e
      LOGGER.log_exception e
      raise
    end

    def websocket_error(e)
      LOGGER.error "Terminal gateway error: #{e}"
      LOGGER.error 'Killing thread and reconnecting...'

      # Kill the WSCS internal thread to ensure disconnection regardless of what error occurred
      @ws.thread.kill
    end

    def websocket_open
      # If we've already received packets (packet sequence > 0) resume an existing connection instead of identifying anew
      if @sequence && @sequence > 0
        resume(@sequence, raw_token, @session_id)
        return
      end

      identify(raw_token, 100, GATEWAY_VERSION)
    end

    # Identify the client to the gateway
    def identify(token, large_threshold, version)
      # Send the initial packet
      packet = {
        op: Opcodes::IDENTIFY, # Opcode
        d: {                   # Packet data
          v: version,          # WebSocket protocol version
          token: token,
          properties: { # I'm unsure what these values are for exactly, but they don't appear to impact bot functionality in any way.
            :'$os' => RUBY_PLATFORM.to_s,
            :'$browser' => 'discordrb',
            :'$device' => 'discordrb',
            :'$referrer' => '',
            :'$referring_domain' => ''
          },
          large_threshold: large_threshold,
          compress: true
        }
      }

      # Discord is very strict about the existence of the shard parameter, so only add it if it actually exists
      packet[:d][:shard] = @shard_key if @shard_key

      @ws.send(packet.to_json)
    end

    # Resume a previous gateway connection when reconnecting to a different server
    def resume(seq, token, session_id)
      data = {
        op: Opcodes::RESUME,
        d: {
          seq: seq,
          token: token,
          session_id: session_id
        }
      }

      @ws.send(data.to_json)
    end

    # Invalidate the current session (whatever this means)
    def invalidate_session
      @sequence = 0
      @session_id = nil
    end

    # Notifies everything there is to be notified that the connection is now ready
    def notify_ready
      # Make sure to raise the event
      raise_event(ReadyEvent.new(self))
      LOGGER.good 'Ready'

      # Tell the run method that everything was successful
      @ws_success = true
    end

    # Separate method to wait an ever-increasing amount of time before reconnecting after being disconnected in an
    # unexpected way
    def wait_for_reconnect
      # We disconnected in an unexpected way! Wait before reconnecting so we don't spam Discord's servers.
      debug("Attempting to reconnect in #{@falloff} seconds.")
      sleep @falloff

      # Calculate new falloff
      @falloff *= 1.5
      @falloff = 115 + (rand * 10) if @falloff > 120 # Cap the falloff at 120 seconds and then add some random jitter
    end

    def send_heartbeat(sequence = nil)
      sequence ||= @sequence

      raise_event(HeartbeatEvent.new(self))

      if @awaiting_ack
        # There has been no HEARTBEAT_ACK between the last heartbeat and now, so reconnect because the connection might
        # be a zombie
        LOGGER.warn("No HEARTBEAT_ACK received between the last heartbeat and now! (seq: #{sequence})")
      end

      LOGGER.out("Sending heartbeat with sequence #{sequence}")
      data = {
        op: Opcodes::HEARTBEAT,
        d: sequence
      }

      @ws.send(data.to_json)
      @awaiting_ack = true
    rescue => e
      LOGGER.error('Got an error while sending a heartbeat! Carrying on anyway because heartbeats are vital for the connection to stay alive')
      LOGGER.log_exception(e)
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
