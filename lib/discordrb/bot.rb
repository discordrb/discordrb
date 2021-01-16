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
require 'discordrb/events/webhooks'
require 'discordrb/events/invites'

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

    # @return [true, false] whether or not the bot should parse its own messages. Off by default.
    attr_accessor :should_parse_self

    # The bot's name which discordrb sends to Discord when making any request, so Discord can identify bots with the
    # same codebase. Not required but I recommend setting it anyway.
    # @return [String] The bot's name.
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
    # @param client_id [Integer] If you're logging in as a bot, the bot's client ID. This is optional, and may be fetched
    #   from the API by calling {Bot#bot_application} (see {Application}).
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
    #   https://github.com/discordapp/discord-api-docs/issues/17 for how to do sharding.
    # @param num_shards [Integer] The total number of shards that should be running. See
    #   https://github.com/discordapp/discord-api-docs/issues/17 for how to do sharding.
    # @param redact_token [true, false] Whether the bot should redact the token in logs. Default is true.
    # @param ignore_bots [true, false] Whether the bot should ignore bot accounts or not. Default is false.
    # @param compress_mode [:none, :large, :stream] Sets which compression mode should be used when connecting
    #   to Discord's gateway. `:none` will request that no payloads are received compressed (not recommended for
    #   production bots). `:large` will request that large payloads are received compressed. `:stream` will request
    #   that all data be received in a continuous compressed stream.
    # @param intents [:all, Array<Symbol>, nil] Intents that this bot requires. See {Discordrb::INTENTS}. If `nil`, no intents
    #   field will be passed.
    def initialize(
      log_mode: :normal,
      token: nil, client_id: nil,
      type: nil, name: '', fancy_log: false, suppress_ready: false, parse_self: false,
      shard_id: nil, num_shards: nil, redact_token: true, ignore_bots: false,
      compress_mode: :large, intents: nil
    )
      LOGGER.mode = log_mode
      LOGGER.token = token if redact_token

      @should_parse_self = parse_self

      @client_id = client_id

      @type = type || :bot
      @name = name

      @shard_key = num_shards ? [shard_id, num_shards] : nil

      LOGGER.fancy = fancy_log
      @prevent_ready = suppress_ready

      @compress_mode = compress_mode

      raise 'Token string is empty or nil' if token.nil? || token.empty?

      @intents = intents == :all ? INTENTS.values.reduce(&:|) : calculate_intents(intents) if intents

      @token = process_token(@type, token)
      @gateway = Gateway.new(self, @token, @shard_key, @compress_mode, @intents)

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
      unavailable_servers_check
      @users
    end

    # The list of servers the bot is currently in.
    # @return [Hash<Integer => Server>] The servers by ID.
    def servers
      gateway_check
      unavailable_servers_check
      @servers
    end

    # @overload emoji(id)
    #   Return an emoji by its ID
    #   @param id [String, Integer] The emoji's ID.
    #   @return [Emoji, nil] the emoji object. `nil` if the emoji was not found.
    # @overload emoji
    #   The list of emoji the bot can use.
    #   @return [Array<Emoji>] the emoji available.
    def emoji(id = nil)
      emoji_hash = servers.values.map(&:emoji).reduce(&:merge)
      if id
        id = id.resolve_id
        emoji_hash[id]
      else
        emoji_hash.values
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
      return unless @type == :bot

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

    # @return [String] the raw token, without any prefix
    # @see #token
    def raw_token
      @token.split(' ').last
    end

    # Runs the bot, which logs into Discord and connects the WebSocket. This
    # prevents all further execution unless it is executed with
    # `background` = `true`.
    # @param background [true, false] If it is `true`, then the bot will run in
    #   another thread to allow further execution. If it is `false`, this method
    #   will block until {#stop} is called. If the bot is run with `true`, make
    #   sure to eventually call {#join} so the script doesn't stop prematurely.
    # @note Running the bot in the background means that you can call some
    #   methods that require a gateway connection *before* that connection is
    #   established. In most cases an exception will be raised if you try to do
    #   this. If you need a way to safely run code after the bot is fully
    #   connected, use a {#ready} event handler instead.
    def run(background = false)
      @gateway.run_async
      return if background

      debug('Oh wait! Not exiting yet as run was run synchronously.')
      @gateway.sync
    end

    # Joins the bot's connection thread with the current thread.
    # This blocks execution until the websocket stops, which should only happen
    # manually triggered. or due to an error. This is necessary to have a
    # continuously running bot.
    def join
      @gateway.sync
    end
    alias_method :sync, :join

    # Stops the bot gracefully, disconnecting the websocket without immediately killing the thread. This means that
    # Discord is immediately aware of the closed connection and makes the bot appear offline instantly.
    # @note This method no longer takes an argument as of 3.4.0
    def stop(_no_sync = nil)
      @gateway.stop
    end

    # @return [true, false] whether or not the bot is currently connected to Discord.
    def connected?
      @gateway.open?
    end

    # Makes the bot join an invite to a server.
    # @param invite [String, Invite] The invite to join. For possible formats see {#resolve_invite_code}.
    def accept_invite(invite)
      resolved = invite(invite).code
      API::Invite.accept(token, resolved)
    end

    # Creates an OAuth invite URL that can be used to invite this bot to a particular server.
    # @param server [Server, nil] The server the bot should be invited to, or nil if a general invite should be created.
    # @param permission_bits [String, Integer] Permission bits that should be appended to invite url.
    # @return [String] the OAuth invite URL.
    def invite_url(server: nil, permission_bits: nil)
      @client_id ||= bot_application.id

      server_id_str = server ? "&guild_id=#{server.id}" : ''
      permission_bits_str = permission_bits ? "&permissions=#{permission_bits}" : ''
      "https://discord.com/oauth2/authorize?&client_id=#{@client_id}#{server_id_str}#{permission_bits_str}&scope=bot"
    end

    # @return [Hash<Integer => VoiceBot>] the voice connections this bot currently has, by the server ID to which they are connected.
    attr_reader :voices

    # Gets the voice bot for a particular server or channel. You can connect to a new channel using the {#voice_connect}
    # method.
    # @param thing [Channel, Server, Integer] the server or channel you want to get the voice bot for, or its ID.
    # @return [Voice::VoiceBot, nil] the VoiceBot for the thing you specified, or nil if there is no connection yet
    def voice(thing)
      id = thing.resolve_id
      return @voices[id] if @voices[id]

      channel = channel(id)
      return nil unless channel

      server_id = channel.server.id
      return @voices[server_id] if @voices[server_id]
    end

    # Connects to a voice channel, initializes network connections and returns the {Voice::VoiceBot} over which audio
    # data can then be sent. After connecting, the bot can also be accessed using {#voice}. If the bot is already
    # connected to voice, the existing connection will be terminated - you don't have to call
    # {Discordrb::Voice::VoiceBot#destroy} before calling this method.
    # @param chan [Channel, String, Integer] The voice channel, or its ID, to connect to.
    # @param encrypted [true, false] Whether voice communication should be encrypted using
    #   (uses an XSalsa20 stream cipher for encryption and Poly1305 for authentication)
    # @return [Voice::VoiceBot] the initialized bot over which audio data can then be sent.
    def voice_connect(chan, encrypted = true)
      raise ArgumentError, 'Unencrypted voice connections are no longer supported.' unless encrypted

      chan = channel(chan.resolve_id)
      server_id = chan.server.id

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
    # @param server [Server, String, Integer] The server, or server ID, the voice connection is on.
    # @param destroy_vws [true, false] Whether or not the VWS should also be destroyed. If you're calling this method
    #   directly, you should leave it as true.
    def voice_destroy(server, destroy_vws = true)
      server = server.resolve_id
      @gateway.send_voice_state_update(server.to_s, nil, false, false)
      @voices[server].destroy if @voices[server] && destroy_vws
      @voices.delete(server)
    end

    # Revokes an invite to a server. Will fail unless you have the *Manage Server* permission.
    # It is recommended that you use {Invite#delete} instead.
    # @param code [String, Invite] The invite to revoke. For possible formats see {#resolve_invite_code}.
    def delete_invite(code)
      invite = resolve_invite_code(code)
      API::Invite.delete(token, invite)
    end

    # Sends a text message to a channel given its ID and the message's content.
    # @param channel [Channel, String, Integer] The channel, or its ID, to send something to.
    # @param content [String] The text that should be sent as a message. It is limited to 2000 characters (Discord imposed).
    # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
    # @param embed [Hash, Discordrb::Webhooks::Embed, nil] The rich embed to append to this message.
    # @param allowed_mentions [Hash, Discordrb::AllowedMentions, false, nil] Mentions that are allowed to ping on this message. `false` disables all pings
    # @param message_reference [Message, String, Integer, nil] The message, or message ID, to reply to if any.
    # @return [Message] The message that was sent.
    def send_message(channel, content, tts = false, embed = nil, attachments = nil, allowed_mentions = nil, message_reference = nil)
      channel = channel.resolve_id
      debug("Sending message to #{channel} with content '#{content}'")
      allowed_mentions = { parse: [] } if allowed_mentions == false
      message_reference = { message_id: message_reference.id } if message_reference

      response = API::Channel.create_message(token, channel, content, tts, embed&.to_hash, nil, attachments, allowed_mentions&.to_hash, message_reference)
      Message.new(JSON.parse(response), self)
    end

    # Sends a text message to a channel given its ID and the message's content,
    # then deletes it after the specified timeout in seconds.
    # @param channel [Channel, String, Integer] The channel, or its ID, to send something to.
    # @param content [String] The text that should be sent as a message. It is limited to 2000 characters (Discord imposed).
    # @param timeout [Float] The amount of time in seconds after which the message sent will be deleted.
    # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
    # @param embed [Hash, Discordrb::Webhooks::Embed, nil] The rich embed to append to this message.
    # @param attachments [Array<File>] Files that can be referenced in embeds via `attachment://file.png`
    # @param allowed_mentions [Hash, Discordrb::AllowedMentions, false, nil] Mentions that are allowed to ping on this message. `false` disables all pings
    # @param message_reference [Message, String, Integer, nil] The message, or message ID, to reply to if any.
    def send_temporary_message(channel, content, timeout, tts = false, embed = nil, attachments = nil, allowed_mentions = nil, message_reference = nil)
      Thread.new do
        Thread.current[:discordrb_name] = "#{@current_thread}-temp-msg"

        message = send_message(channel, content, tts, embed, attachments, allowed_mentions, message_reference)
        sleep(timeout)
        message.delete
      end

      nil
    end

    # Sends a file to a channel. If it is an image, it will automatically be embedded.
    # @note This executes in a blocking way, so if you're sending long files, be wary of delays.
    # @param channel [Channel, String, Integer] The channel, or its ID, to send something to.
    # @param file [File] The file that should be sent.
    # @param caption [string] The caption for the file.
    # @param tts [true, false] Whether or not this file's caption should be sent using Discord text-to-speech.
    # @param filename [String] Overrides the filename of the uploaded file
    # @param spoiler [true, false] Whether or not this file should appear as a spoiler.
    # @example Send a file from disk
    #   bot.send_file(83281822225530880, File.open('rubytaco.png', 'r'))
    def send_file(channel, file, caption: nil, tts: false, filename: nil, spoiler: nil)
      if file.respond_to?(:read)
        if spoiler
          filename ||= File.basename(file.path)
          filename = "SPOILER_#{filename}" unless filename.start_with? 'SPOILER_'
        end
        # https://github.com/rest-client/rest-client/blob/v2.0.2/lib/restclient/payload.rb#L160
        file.define_singleton_method(:original_filename) { filename } if filename
      end

      channel = channel.resolve_id
      response = API::Channel.upload_file(token, channel, file, caption: caption, tts: tts)
      Message.new(JSON.parse(response), self)
    end

    # Creates a server on Discord with a specified name and a region.
    # @note Discord's API doesn't directly return the server when creating it, so this method
    #   waits until the data has been received via the websocket. This may make the execution take a while.
    # @param name [String] The name the new server should have. Doesn't have to be alphanumeric.
    # @param region [Symbol] The region where the server should be created, for example 'eu-central' or 'hongkong'.
    # @return [Server] The server that was created.
    def create_server(name, region = :'eu-central')
      response = API::Server.create(token, name, region)
      id = JSON.parse(response)['id'].to_i
      sleep 0.1 until (server = @servers[id])
      debug "Successfully created server #{server.id} with name #{server.name}"
      server
    end

    # Creates a new application to do OAuth authorization with. This allows you to use OAuth to authorize users using
    # Discord. For information how to use this, see the docs: https://discord.com/developers/docs/topics/oauth2
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

    # Gets the users, channels, roles and emoji from a string.
    # @param mentions [String] The mentions, which should look like `<@12314873129>`, `<#123456789>`, `<@&123456789>` or `<:name:126328:>`.
    # @param server [Server, nil] The server of the associated mentions. (recommended for role parsing, to speed things up)
    # @return [Array<User, Channel, Role, Emoji>] The array of users, channels, roles and emoji identified by the mentions, or `nil` if none exists.
    def parse_mentions(mentions, server = nil)
      array_to_return = []
      # While possible mentions may be in message
      while mentions.include?('<') && mentions.include?('>')
        # Removing all content before the next possible mention
        mentions = mentions.split('<', 2)[1]
        # Locate the first valid mention enclosed in `<...>`, otherwise advance to the next open `<`
        next unless mentions.split('>', 2).first.length < mentions.split('<', 2).first.length

        # Store the possible mention value to be validated with RegEx
        mention = mentions.split('>', 2).first
        if /@!?(?<id>\d+)/ =~ mention
          array_to_return << user(id) unless user(id).nil?
        elsif /#(?<id>\d+)/ =~ mention
          array_to_return << channel(id, server) unless channel(id, server).nil?
        elsif /@&(?<id>\d+)/ =~ mention
          if server
            array_to_return << server.role(id) unless server.role(id).nil?
          else
            @servers.each_value do |element|
              array_to_return << element.role(id) unless element.role(id).nil?
            end
          end
        elsif /(?<animated>^a|^${0}):(?<name>\w+):(?<id>\d+)/ =~ mention
          array_to_return << (emoji(id) || Emoji.new({ 'animated' => !animated.nil?, 'name' => name, 'id' => id }, self, nil))
        end
      end
      array_to_return
    end

    # Gets the user, channel, role or emoji from a string.
    # @param mention [String] The mention, which should look like `<@12314873129>`, `<#123456789>`, `<@&123456789>` or `<:name:126328:>`.
    # @param server [Server, nil] The server of the associated mention. (recommended for role parsing, to speed things up)
    # @return [User, Channel, Role, Emoji] The user, channel, role or emoji identified by the mention, or `nil` if none exists.
    def parse_mention(mention, server = nil)
      parse_mentions(mention, server).first
    end

    # Updates presence status.
    # @param status [String] The status the bot should show up as. Can be `online`, `dnd`, `idle`, or `invisible`
    # @param activity [String, nil] The name of the activity to be played/watched/listened to/stream name on the stream.
    # @param url [String, nil] The Twitch URL to display as a stream. nil for no stream.
    # @param since [Integer] When this status was set.
    # @param afk [true, false] Whether the bot is AFK.
    # @param activity_type [Integer] The type of activity status to display.
    #   Can be 0 (Playing), 1 (Streaming), 2 (Listening), 3 (Watching), or 5 (Competing).
    # @see Gateway#send_status_update
    def update_status(status, activity, url, since = 0, afk = false, activity_type = 0)
      gateway_check

      @activity = activity
      @status = status
      @streamurl = url
      type = url ? 1 : activity_type

      activity_obj = activity || url ? { 'name' => activity, 'url' => url, 'type' => type } : nil
      @gateway.send_status_update(status, since, activity_obj, afk)

      # Update the status in the cache
      profile.update_presence('status' => status.to_s, 'activities' => [activity_obj].compact)
    end

    # Sets the currently playing game to the specified game.
    # @param name [String] The name of the game to be played.
    # @return [String] The game that is being played now.
    def game=(name)
      gateway_check
      update_status(@status, name, nil)
    end

    alias_method :playing=, :game=

    # Sets the current listening status to the specified name.
    # @param name [String] The thing to be listened to.
    # @return [String] The thing that is now being listened to.
    def listening=(name)
      gateway_check
      update_status(@status, name, nil, nil, nil, 2)
    end

    # Sets the current watching status to the specified name.
    # @param name [String] The thing to be watched.
    # @return [String] The thing that is now being watched.
    def watching=(name)
      gateway_check
      update_status(@status, name, nil, nil, nil, 3)
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

    # Sets the currently competing status to the specified name.
    # @param name [String] The name of the game to be competing in.
    # @return [String] The game that is being competed in now.
    def competing=(name)
      gateway_check
      update_status(@status, name, nil, nil, nil, 5)
    end

    # Sets status to online.
    def online
      gateway_check
      update_status(:online, @activity, @streamurl)
    end

    alias_method :on, :online

    # Sets status to idle.
    def idle
      gateway_check
      update_status(:idle, @activity, nil)
    end

    alias_method :away, :idle

    # Sets the bot's status to DnD (red icon).
    def dnd
      gateway_check
      update_status(:dnd, @activity, nil)
    end

    # Sets the bot's status to invisible (appears offline).
    def invisible
      gateway_check
      update_status(:invisible, @activity, nil)
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
    # @deprecated Will be changed to blocking behavior in v4.0. Use {#add_await!} instead.
    def add_await(key, type, attributes = {}, &block)
      raise "You can't await an AwaitEvent!" if type == Discordrb::Events::AwaitEvent

      await = Await.new(self, key, type, attributes, block)
      @awaits ||= {}
      @awaits[key] = await
    end

    # Awaits an event, blocking the current thread until a response is received.
    # @param type [Class] The event class that should be listened for.
    # @option attributes [Numeric] :timeout the amount of time (in seconds) to wait for a response before returning `nil`. Waits forever if omitted.
    # @yield Executed when a matching event is received.
    # @yieldparam event [Event] The event object that was triggered.
    # @yieldreturn [true, false] Whether the event matches extra await criteria described by the block
    # @return [Event, nil] The event object that was triggered, or `nil` if a `timeout` was set and no event was raised in time.
    # @raise [ArgumentError] if `timeout` is given and is not a positive numeric value
    def add_await!(type, attributes = {})
      raise "You can't await an AwaitEvent!" if type == Discordrb::Events::AwaitEvent

      timeout = attributes[:timeout]
      raise ArgumentError, 'Timeout must be a number > 0' if timeout.is_a?(Numeric) && !timeout.positive?

      mutex = Mutex.new
      cv = ConditionVariable.new
      response = nil
      block = lambda do |event|
        mutex.synchronize do
          response = event
          if block_given?
            result = yield(event)
            cv.signal if result.is_a?(TrueClass)
          else
            cv.signal
          end
        end
      end

      handler = register_event(type, attributes, block)

      if timeout
        Thread.new do
          sleep timeout
          mutex.synchronize { cv.signal }
        end
      end

      mutex.synchronize { cv.wait(mutex) }

      remove_handler(handler)
      raise 'ConditionVariable was signaled without returning an event!' if response.nil? && timeout.nil?

      response
    end

    # Add a user to the list of ignored users. Those users will be ignored in message events at event processing level.
    # @note Ignoring a user only prevents any message events (including mentions, commands etc.) from them! Typing and
    #   presence and any other events will still be received.
    # @param user [User, String, Integer] The user, or its ID, to be ignored.
    def ignore_user(user)
      @ignored_ids << user.resolve_id
    end

    # Remove a user from the ignore list.
    # @param user [User, String, Integer] The user, or its ID, to be unignored.
    def unignore_user(user)
      @ignored_ids.delete(user.resolve_id)
    end

    # Checks whether a user is being ignored.
    # @param user [User, String, Integer] The user, or its ID, to check.
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

    # Makes the bot leave any groups with no recipients remaining
    def prune_empty_groups
      @channels.each_value do |channel|
        channel.leave_group if channel.group? && channel.recipients.empty?
      end
    end

    private

    # Throws a useful exception if there's currently no gateway connection.
    def gateway_check
      raise "A gateway connection is necessary to call this method! You'll have to do it inside any event (e.g. `ready`) or after `bot.run :async`." unless connected?
    end

    # Logs a warning if there are servers which are still unavailable.
    # e.g. due to a Discord outage or because the servers are large and taking a while to load.
    def unavailable_servers_check
      # Return unless there are servers that are unavailable.
      return unless @unavailable_servers&.positive?

      LOGGER.warn("#{@unavailable_servers} servers haven't been cached yet.")
      LOGGER.warn('Servers may be unavailable due to an outage, or your bot is on very large servers that are taking a while to load.')
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
      old_channel_id = old_voice_state.voice_channel&.id if old_voice_state

      server.update_voice_state(data)

      existing_voice = @voices[server_id]
      if user_id == @profile.id && existing_voice
        new_channel_id = data['channel_id']
        if new_channel_id
          new_channel = channel(new_channel_id)
          existing_voice.channel = new_channel
        else
          voice_destroy(server_id)
        end
      end

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
      @voices[server_id] = Discordrb::Voice::VoiceBot.new(channel, self, token, @session_id, endpoint)
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
      member.update_boosting_since(data['premium_since'])
    end

    # Internal handler for GUILD_MEMBER_DELETE
    def delete_guild_member(data)
      server_id = data['guild_id'].to_i
      server = self.server(server_id)
      return unless server

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
      existing_role = server.role(new_role.id)
      if existing_role
        existing_role.update_from(new_role)
      else
        server.add_role(new_role)
      end
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

      token = "Bot #{token}" unless type == :user
      token
    end

    def handle_dispatch(type, data)
      # Check whether there are still unavailable servers and there have been more than 10 seconds since READY
      if @unavailable_servers&.positive? && (Time.now - @unavailable_timeout_time) > 10 && !((@intents || 0) & INTENTS[:servers]).zero?
        # The server streaming timed out!
        LOGGER.debug("Server streaming timed out with #{@unavailable_servers} servers remaining")
        LOGGER.debug('Calling ready now because server loading is taking a long time. Servers may be unavailable due to an outage, or your bot is on very large servers.')

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
      when :INVITE_CREATE
        invite = Invite.new(data, self)
        raise_event(InviteCreateEvent.new(data, invite, self))
      when :INVITE_DELETE
        raise_event(InviteDeleteEvent.new(data, self))
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

        event = MessageUpdateEvent.new(message, self)
        raise_event(event)

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

        return if profile.id == data['user_id'].to_i && !should_parse_self

        event = ReactionAddEvent.new(data, self)
        raise_event(event)
      when :MESSAGE_REACTION_REMOVE
        remove_message_reaction(data)

        return if profile.id == data['user_id'].to_i && !should_parse_self

        event = ReactionRemoveEvent.new(data, self)
        raise_event(event)
      when :MESSAGE_REACTION_REMOVE_ALL
        remove_all_message_reactions(data)

        event = ReactionRemoveAllEvent.new(data, self)
        raise_event(event)
      when :PRESENCE_UPDATE
        # Ignore friends list presences
        return unless data['guild_id']

        now_playing = data['game'].nil? ? nil : data['game']['name']
        presence_user = @users[data['user']['id'].to_i]
        played_before = presence_user.nil? ? nil : presence_user.game
        update_presence(data)

        event = if now_playing == played_before
                  PresenceEvent.new(data, self)
                else
                  PlayingEvent.new(data, self)
                end

        raise_event(event)
      when :VOICE_STATE_UPDATE
        old_channel_id = update_voice_state(data)

        event = VoiceStateUpdateEvent.new(data, old_channel_id, self)
        raise_event(event)
      when :VOICE_SERVER_UPDATE
        update_voice_server(data)

        event = VoiceServerUpdateEvent.new(data, self)
        raise_event(event)
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
      when :WEBHOOKS_UPDATE
        event = WebhookUpdateEvent.new(data, self)
        raise_event(event)
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
      return unless handlers

      handlers.dup.each do |handler|
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
        rescue StandardError => e
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

    def calculate_intents(intents)
      intents.reduce(0) do |sum, intent|
        case intent
        when Symbol
          if INTENTS[intent]
            sum | INTENTS[intent]
          else
            LOGGER.warn("Unknown intent: #{intent}")
            sum
          end
        when Integer
          sum | intent
        else
          LOGGER.warn("Invalid intent: #{intent}")
          sum
        end
      end
    end
  end
end
