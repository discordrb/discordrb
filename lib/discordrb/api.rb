# frozen_string_literal: true

require 'rest-client'
require 'json'

require 'discordrb/errors'

# List of methods representing endpoints in Discord's API
module Discordrb::API
  # The base URL of the Discord REST API.
  APIBASE = 'https://discordapp.com/api'.freeze

  module_function

  # @return [String] the currently used API base URL.
  def api_base
    @api_base || APIBASE
  end

  # Sets the API base URL to something.
  def api_base=(value)
    @api_base = value
  end

  # @return [String] the bot name, previously specified using #bot_name=.
  def bot_name
    @bot_name
  end

  # Sets the bot name to something.
  def bot_name=(value)
    @bot_name = value
  end

  # Generate a user agent identifying this requester as discordrb.
  def user_agent
    # This particular string is required by the Discord devs.
    required = "DiscordBot (https://github.com/meew0/discordrb, v#{Discordrb::VERSION})"
    @bot_name ||= ''

    "rest-client/#{RestClient::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION}p#{RUBY_PATCHLEVEL} discordrb/#{Discordrb::VERSION} #{required} #{@bot_name}"
  end

  # Resets all rate limit mutexes
  def reset_mutexes
    @mutexes = {}
  end

  # Performs a RestClient request.
  # @param type [Symbol] The type of HTTP request to use.
  # @param attributes [Array] The attributes for the request.
  def raw_request(type, attributes)
    RestClient.send(type, *attributes)
  rescue RestClient::Forbidden
    raise Discordrb::Errors::NoPermission, "The bot doesn't have the required permission to do this!"
  rescue RestClient::BadGateway
    Discordrb::LOGGER.warn('Got a 502 while sending a request! Not a big deal, retrying the request')
    retry
  end

  # Make an API request. Utility function to implement message queueing
  # in the future
  def request(key, type, *attributes)
    # Add a custom user agent
    attributes.last[:user_agent] = user_agent if attributes.last.is_a? Hash

    begin
      if key
        @mutexes[key] = Mutex.new unless @mutexes[key]

        # Lock and unlock, i. e. wait for the mutex to unlock and don't do anything with it afterwards
        @mutexes[key].lock
        @mutexes[key].unlock
      end

      response = raw_request(type, attributes)
    rescue RestClient::TooManyRequests => e
      raise "Got an HTTP 429 for an untracked API call! Please report this bug together with the following information: #{type} #{attributes}" unless key

      unless @mutexes[key].locked?
        response = JSON.parse(e.response)
        wait_seconds = response['retry_after'].to_i / 1000.0
        Discordrb::LOGGER.warn("Locking RL mutex (key: #{key}) for #{wait_seconds} seconds due to Discord rate limiting")

        # Wait the required time synchronized by the mutex (so other incoming requests have to wait) but only do it if
        # the mutex isn't locked already so it will only ever wait once
        @mutexes[key].synchronize { sleep wait_seconds }
      end

      retry
    end

    response
  end

  # Make an avatar URL from the user and avatar IDs
  def avatar_url(user_id, avatar_id)
    "#{api_base}/users/#{user_id}/avatars/#{avatar_id}.jpg"
  end

  # Make an icon URL from server and icon IDs
  def icon_url(server_id, icon_id)
    "#{api_base}/guilds/#{server_id}/icons/#{icon_id}.jpg"
  end

  # Make an icon URL from application and icon IDs
  def app_icon_url(app_id, icon_id)
    "https://cdn.discordapp.com/app-icons/#{app_id}/#{icon_id}.jpg"
  end

  # Ban a user from a server and delete their messages from the last message_days days
  def ban_user(token, server_id, user_id, message_days)
    request(
      __method__,
      :put,
      "#{api_base}/guilds/#{server_id}/bans/#{user_id}?delete-message-days=#{message_days}",
      nil,
      Authorization: token
    )
  end

  # Unban a user from a server
  def unban_user(token, server_id, user_id)
    request(
      __method__,
      :delete,
      "#{api_base}/guilds/#{server_id}/bans/#{user_id}",
      Authorization: token
    )
  end

  # Kick a user from a server
  def kick_user(token, server_id, user_id)
    request(
      __method__,
      :delete,
      "#{api_base}/guilds/#{server_id}/members/#{user_id}",
      Authorization: token
    )
  end

  # Move a user to a different voice channel
  def move_user(token, server_id, user_id, channel_id)
    request(
      __method__,
      :patch,
      "#{api_base}/guilds/#{server_id}/members/#{user_id}",
      { channel_id: channel_id }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Change the current bot's nickname on a server
  def change_own_nickname(token, server_id, nick)
    request(
      __method__,
      :patch,
      "#{api_base}/guilds/#{server_id}/members/@me/nick",
      { nick: nick }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Change a user's nickname on a server
  def change_nickname(token, server_id, user_id, nick)
    request(
      __method__,
      :patch,
      "#{api_base}/guilds/#{server_id}/members/#{user_id}",
      { nick: nick }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get a server's banned users
  def bans(token, server_id)
    request(
      __method__,
      :get,
      "#{api_base}/guilds/#{server_id}/bans",
      Authorization: token
    )
  end

  # Get a server's channels list
  def channels(token, server_id)
    request(
      __method__,
      :get,
      "#{api_base}/guilds/#{server_id}/channels",
      Authorization: token
    )
  end

  # Get a channel's invite list
  def channel_invites(token, channel_id)
    request(
      __method__,
      :get,
      "#{api_base}/channels/#{channel_id}/invites",
      Authorization: token
    )
  end

  # Logout from the server
  def logout(token)
    request(
      __method__,
      :post,
      "#{api_base}/auth/logout",
      nil,
      Authorization: token
    )
  end

  # Create an OAuth application
  def create_oauth_application(token, name, redirect_uris)
    request(
      __method__,
      :post,
      "#{api_base}/oauth2/applications",
      { name: name, redirect_uris: redirect_uris }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Change an OAuth application's properties
  def update_oauth_application(token, name, redirect_uris, description = '', icon = nil)
    request(
      __method__,
      :put,
      "#{api_base}/oauth2/applications",
      { name: name, redirect_uris: redirect_uris, description: description, icon: icon }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get the bot's OAuth application's information
  def oauth_application(token)
    request(
      __method__,
      :get,
      "#{api_base}/oauth2/applications/@me",
      Authorization: token
    )
  end

  # Create a server
  def create_server(token, name, region = :london)
    request(
      __method__,
      :post,
      "#{api_base}/guilds",
      { name: name, region: region.to_s }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a server
  def update_server(token, server_id, name, region, icon, afk_channel_id, afk_timeout)
    request(
      __method__,
      :patch,
      "#{api_base}/guilds/#{server_id}",
      { name: name, region: region, icon: icon, afk_channel_id: afk_channel_id, afk_timeout: afk_timeout }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Transfer server ownership
  def transfer_ownership(token, server_id, user_id)
    request(
      __method__,
      :patch,
      "#{api_base}/guilds/#{server_id}",
      { owner_id: user_id }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a server
  def delete_server(token, server_id)
    request(
      __method__,
      :delete,
      "#{api_base}/guilds/#{server_id}",
      Authorization: token
    )
  end

  # Leave a server
  def leave_server(token, server_id)
    request(
      __method__,
      :delete,
      "#{api_base}/users/@me/guilds/#{server_id}",
      Authorization: token
    )
  end

  # Get a channel's data
  def channel(token, channel_id)
    request(
      __method__,
      :get,
      "#{api_base}/channels/#{channel_id}",
      Authorization: token
    )
  end

  # Get a server's data
  def server(token, server_id)
    request(
      __method__,
      :get,
      "#{api_base}/guilds/#{server_id}",
      Authorization: token
    )
  end

  # Get a member's data
  def member(token, server_id, user_id)
    request(
      __method__,
      :get,
      "#{api_base}/guilds/#{server_id}/members/#{user_id}",
      Authorization: token
    )
  end

  # Create a channel
  def create_channel(token, server_id, name, type)
    request(
      __method__,
      :post,
      "#{api_base}/guilds/#{server_id}/channels",
      { name: name, type: type }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a channel's data
  def update_channel(token, channel_id, name, topic, position = 0)
    request(
      __method__,
      :patch,
      "#{api_base}/channels/#{channel_id}",
      { name: name, position: position, topic: topic }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a channel
  def delete_channel(token, channel_id)
    request(
      __method__,
      :delete,
      "#{api_base}/channels/#{channel_id}",
      Authorization: token
    )
  end

  # Join a server using an invite
  def join_server(token, invite_code)
    request(
      __method__,
      :post,
      "#{api_base}/invite/#{invite_code}",
      nil,
      Authorization: token
    )
  end

  # Resolve an invite
  def resolve_invite(token, invite_code)
    request(
      __method__,
      :get,
      "#{api_base}/invite/#{invite_code}",
      Authorization: token
    )
  end

  # Create a private channel
  def create_private(token, bot_user_id, user_id)
    request(
      __method__,
      :post,
      "#{api_base}/users/#{bot_user_id}/channels",
      { recipient_id: user_id }.to_json,
      Authorization: token,
      content_type: :json
    )
  rescue RestClient::BadRequest
    raise 'Attempted to PM the bot itself!'
  end

  # Create an instant invite from a server or a channel id
  def create_invite(token, channel_id, max_age = 0, max_uses = 0, temporary = false)
    request(
      __method__,
      :post,
      "#{api_base}/channels/#{channel_id}/invites",
      { max_age: max_age, max_uses: max_uses, temporary: temporary }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete an invite by code
  def delete_invite(token, code)
    request(
      __method__,
      :delete,
      "#{api_base}/invites/#{code}",
      Authorization: token
    )
  end

  # Send a message to a channel
  def send_message(token, channel_id, message, mentions = [], tts = false, guild_id = nil)
    request(
      "message-#{guild_id}".to_sym,
      :post,
      "#{api_base}/channels/#{channel_id}/messages",
      { content: message, mentions: mentions, tts: tts }.to_json,
      Authorization: token,
      content_type: :json
    )
  rescue RestClient::InternalServerError
    raise Discordrb::Errors::MessageTooLong, "Message over the character limit (#{message.length} > 2000)"
  end

  # Delete a message
  def delete_message(token, channel_id, message_id)
    request(
      __method__,
      :delete,
      "#{api_base}/channels/#{channel_id}/messages/#{message_id}",
      Authorization: token
    )
  end

  # Delete messages in bulk
  def bulk_delete(token, channel_id, messages = [])
    request(
      __method__,
      :post,
      "#{api_base}/channels/#{channel_id}/messages/bulk_delete",
      { messages: messages }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Edit a message
  def edit_message(token, channel_id, message_id, message, mentions = [])
    request(
      :message,
      :patch,
      "#{api_base}/channels/#{channel_id}/messages/#{message_id}",
      { content: message, mentions: mentions }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Pin a message
  def pin_message(token, channel_id, message_id)
    request(
      __method__,
      :put,
      "#{api_base}/channels/#{channel_id}/pins/#{message_id}",
      nil,
      Authorization: token
    )
  end

  # Unpin a message
  def unpin_message(token, channel_id, message_id)
    request(
      __method__,
      :delete,
      "#{api_base}/channels/#{channel_id}/pins/#{message_id}",
      Authorization: token
    )
  end

  # Acknowledge that a message has been received
  # The last acknowledged message will be sent in the ready packet,
  # so this is an easy way to catch up on messages
  def acknowledge_message(token, channel_id, message_id)
    request(
      __method__,
      :post,
      "#{api_base}/channels/#{channel_id}/messages/#{message_id}/ack",
      nil,
      Authorization: token
    )
  end

  # Send a file as a message to a channel
  def send_file(token, channel_id, file, caption: nil, tts: false)
    request(
      __method__,
      :post,
      "#{api_base}/channels/#{channel_id}/messages",
      { file: file, content: caption, tts: tts },
      Authorization: token
    )
  end

  # Create a role (parameters such as name and colour will have to be set by update_role afterwards)
  def create_role(token, server_id)
    request(
      __method__,
      :post,
      "#{api_base}/guilds/#{server_id}/roles",
      nil,
      Authorization: token
    )
  end

  # Update a role
  # Permissions are the Discord defaults; allowed: invite creation, reading/sending messages,
  # sending TTS messages, embedding links, sending files, reading the history, mentioning everybody,
  # connecting to voice, speaking and voice activity (push-to-talk isn't mandatory)
  def update_role(token, server_id, role_id, name, colour, hoist = false, mentionable = false, packed_permissions = 36_953_089)
    request(
      __method__,
      :patch,
      "#{api_base}/guilds/#{server_id}/roles/#{role_id}",
      { color: colour, name: name, hoist: hoist, mentionable: mentionable, permissions: packed_permissions }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a role
  def delete_role(token, server_id, role_id)
    request(
      __method__,
      :delete,
      "#{api_base}/guilds/#{server_id}/roles/#{role_id}",
      Authorization: token
    )
  end

  # Update a user's roles
  def update_user_roles(token, server_id, user_id, roles)
    request(
      __method__,
      :patch,
      "#{api_base}/guilds/#{server_id}/members/#{user_id}",
      { roles: roles }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a user's server deafened state
  def update_user_deafen(token, server_id, user_id, state)
    request(
      __method__,
      :patch,
      "#{api_base}/guilds/#{server_id}/members/#{user_id}",
      { deaf: state }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a user's server muted state
  def update_user_mute(token, server_id, user_id, state)
    request(
      __method__,
      :patch,
      "#{api_base}/guilds/#{server_id}/members/#{user_id}",
      { mute: state }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a user's permission overrides in a channel
  def update_user_overrides(token, channel_id, user_id, allow, deny)
    request(
      __method__,
      :put,
      "#{api_base}/channels/#{channel_id}/permissions/#{user_id}",
      { type: 'member', id: user_id, allow: allow, deny: deny }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a role's permission overrides in a channel
  def update_role_overrides(token, channel_id, role_id, allow, deny)
    request(
      __method__,
      :put,
      "#{api_base}/channels/#{channel_id}/permissions/#{role_id}",
      { type: 'role', id: role_id, allow: allow, deny: deny }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get the gateway to be used
  def gateway(token)
    request(
      __method__,
      :get,
      "#{api_base}/gateway",
      Authorization: token
    )
  end

  # Validate a token (this request will fail if the token is invalid)
  def validate_token(token)
    request(
      __method__,
      :post,
      "#{api_base}/auth/login",
      {}.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Start typing (needs to be resent every 5 seconds to keep up the typing)
  def start_typing(token, channel_id)
    request(
      __method__,
      :post,
      "#{api_base}/channels/#{channel_id}/typing",
      nil,
      Authorization: token
    )
  end

  # Get user data
  def user(token, user_id)
    request(
      __method__,
      :get,
      "#{api_base}/users/#{user_id}",
      Authorization: token
    )
  end

  # Get profile data
  def profile(token)
    request(
      __method__,
      :get,
      "#{api_base}/users/@me",
      Authorization: token
    )
  end

  # Get information about a user's connections
  def connections(token)
    request(
      __method__,
      :get,
      "#{api_base}/users/@me/connections",
      Authorization: token
    )
  end

  # Update user data
  def update_user(token, new_username, avatar)
    request(
      __method__,
      :patch,
      "#{api_base}/users/@me",
      { avatar: avatar, username: new_username }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get the servers a user is connected to
  def servers(token)
    request(
      __method__,
      :get,
      "#{api_base}/users/@me/guilds",
      Authorization: token
    )
  end

  # Get a list of messages from a channel's history
  def channel_log(token, channel_id, amount, before = nil, after = nil)
    request(
      __method__,
      :get,
      "#{api_base}/channels/#{channel_id}/messages?limit=#{amount}#{"&before=#{before}" if before}#{"&after=#{after}" if after}",
      Authorization: token
    )
  end

  # Get a single message from a channel's history by id
  def channel_message(token, channel_id, message_id)
    request(
      __method__,
      :get,
      "#{api_base}/channels/#{channel_id}/messages/#{message_id}",
      Authorization: token
    )
  end

  # Get a list of pinned messages in a channel
  def pins(token, channel_id)
    request(
      __method__,
      :get,
      "#{api_base}/channels/#{channel_id}/pins",
      Authorization: token
    )
  end
end

Discordrb::API.reset_mutexes
