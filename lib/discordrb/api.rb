require 'rest-client'
require 'json'

require 'discordrb/errors'

# List of methods representing endpoints in Discord's API
module Discordrb::API
  # The base URL of the Discord REST API.
  APIBASE = 'https://discordapp.com/api'.freeze

  module_function

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

  # Performs a RestClient request.
  # @param type [Symbol] The type of HTTP request to use.
  # @param attributes [Array] The attributes for the request.
  def raw_request(type, attributes)
    RestClient.send(type, *attributes)
  rescue RestClient::Forbidden
    raise Discordrb::Errors::NoPermission, "The bot doesn't have the required permission to do this!"
  end

  # Make an API request. Utility function to implement message queueing
  # in the future
  def request(type, *attributes)
    # Add a custom user agent
    attributes.last[:user_agent] = user_agent if attributes.last.is_a? Hash
    response = raw_request(type, attributes)

    while response.code == 429
      wait_seconds = response[:retry_after].to_i / 1000.0
      LOGGER.debug("WARNING: Discord rate limiting will cause a delay of #{wait_seconds} seconds for the request: #{type} #{attributes}")
      sleep wait_seconds / 1000.0
      response = raw_request(type, attributes)
    end

    response
  end

  # Make an avatar URL from the user and avatar IDs
  def avatar_url(user_id, avatar_id)
    "#{APIBASE}/users/#{user_id}/avatars/#{avatar_id}.jpg"
  end

  # Ban a user from a server and delete their messages from the last message_days days
  def ban_user(token, server_id, user_id, message_days)
    request(
      :put,
      "#{APIBASE}/guilds/#{server_id}/bans/#{user_id}?delete-message-days=#{message_days}",
      nil,
      Authorization: token
    )
  end

  # Unban a user from a server
  def unban_user(token, server_id, user_id)
    request(
      :delete,
      "#{APIBASE}/guilds/#{server_id}/bans/#{user_id}",
      Authorization: token
    )
  end

  # Kick a user from a server
  def kick_user(token, server_id, user_id)
    request(
      :delete,
      "#{APIBASE}/guilds/#{server_id}/members/#{user_id}",
      Authorization: token
    )
  end

  # Move a user to a different voice channel
  def move_user(token, server_id, user_id, channel_id)
    request(
      :patch,
      "#{APIBASE}/guilds/#{server_id}/members/#{user_id}",
      { channel_id: channel_id }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get a server's banned users
  def bans(token, server_id)
    request(
      :get,
      "#{APIBASE}/guilds/#{server_id}/bans",
      Authorization: token
    )
  end

  # Login to the server
  def login(email, password)
    request(
      :post,
      "#{APIBASE}/auth/login",
      email: email,
      password: password
    )
  end

  # Logout from the server
  def logout(token)
    request(
      :post,
      "#{APIBASE}/auth/logout",
      nil,
      Authorization: token
    )
  end

  # Create a server
  def create_server(token, name, region = :london)
    request(
      :post,
      "#{APIBASE}/guilds",
      { name: name, region: region.to_s }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a server
  def update_server(token, server_id, name, region, icon, afk_channel_id, afk_timeout)
    request(
      :patch,
      "#{APIBASE}/guilds/#{server_id}",
      { name: name, region: region, icon: icon, afk_channel_id: afk_channel_id, afk_timeout: afk_timeout }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Transfer server ownership
  def transfer_ownership(token, server_id, user_id)
    request(
      :patch,
      "#{APIBASE}/guilds/#{server_id}",
      { owner_id: user_id }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a server
  def delete_server(token, server_id)
    request(
      :delete,
      "#{APIBASE}/guilds/#{server_id}",
      Authorization: token
    )
  end

  # Leave a server
  def leave_server(token, server_id)
    request(
      :delete,
      "#{APIBASE}/users/@me/guilds/#{server_id}",
      Authorization: token
    )
  end

  # Get a channel's data
  def channel(token, channel_id)
    request(
      :get,
      "#{APIBASE}/channels/#{channel_id}",
      Authorization: token
    )
  end

  # Get a member's data
  def member(token, server_id, user_id)
    request(
      :get,
      "#{APIBASE}/guilds/#{server_id}/members/#{user_id}",
      Authorization: token
    )
  end

  # Create a channel
  def create_channel(token, server_id, name, type)
    request(
      :post,
      "#{APIBASE}/guilds/#{server_id}/channels",
      { name: name, type: type }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a channel's data
  def update_channel(token, channel_id, name, topic, position = 0)
    request(
      :patch,
      "#{APIBASE}/channels/#{channel_id}",
      { name: name, position: position, topic: topic }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a channel
  def delete_channel(token, channel_id)
    request(
      :delete,
      "#{APIBASE}/channels/#{channel_id}",
      Authorization: token
    )
  end

  # Join a server using an invite
  def join_server(token, invite_code)
    request(
      :post,
      "#{APIBASE}/invite/#{invite_code}",
      nil,
      Authorization: token
    )
  end

  # Resolve an invite
  def resolve_invite(token, invite_code)
    request(
      :get,
      "#{APIBASE}/invite/#{invite_code}",
      Authorization: token
    )
  end

  # Create a private channel
  def create_private(token, bot_user_id, user_id)
    request(
      :post,
      "#{APIBASE}/users/#{bot_user_id}/channels",
      { recipient_id: user_id }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Create an instant invite from a server or a channel id
  def create_invite(token, channel_id, max_age = 0, max_uses = 0, temporary = false, xkcd = false)
    request(
      :post,
      "#{APIBASE}/channels/#{channel_id}/invites",
      { max_age: max_age, max_uses: max_uses, temporary: temporary, xkcdpass: xkcd }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete an invite by code
  def delete_invite(token, code)
    request(
      :delete,
      "#{APIBASE}/invites/#{code}",
      Authorization: token
    )
  end

  # Send a message to a channel
  def send_message(token, channel_id, message, mentions = [], tts = false)
    request(
      :post,
      "#{APIBASE}/channels/#{channel_id}/messages",
      { content: message, mentions: mentions, tts => tts }.to_json,
      Authorization: token,
      content_type: :json
    )
  rescue RestClient::InternalServerError
    raise Discordrb::Errors::MessageTooLong, "Message over the character limit (#{message.length} > 2000)"
  end

  # Delete a message
  def delete_message(token, channel_id, message_id)
    request(
      :delete,
      "#{APIBASE}/channels/#{channel_id}/messages/#{message_id}",
      Authorization: token
    )
  end

  # Edit a message
  def edit_message(token, channel_id, message_id, message, mentions = [])
    request(
      :patch,
      "#{APIBASE}/channels/#{channel_id}/messages/#{message_id}",
      { content: message, mentions: mentions }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Acknowledge that a message has been received
  # The last acknowledged message will be sent in the ready packet,
  # so this is an easy way to catch up on messages
  def acknowledge_message(token, channel_id, message_id)
    request(
      :post,
      "#{APIBASE}/channels/#{channel_id}/messages/#{message_id}/ack",
      nil,
      Authorization: token
    )
  end

  # Send a file as a message to a channel
  def send_file(token, channel_id, file)
    request(
      :post,
      "#{APIBASE}/channels/#{channel_id}/messages",
      { file: file },
      Authorization: token
    )
  end

  # Create a role (parameters such as name and colour will have to be set by update_role afterwards)
  def create_role(token, server_id)
    request(
      :post,
      "#{APIBASE}/guilds/#{server_id}/roles",
      nil,
      Authorization: token
    )
  end

  # Update a role
  # Permissions are the Discord defaults; allowed: invite creation, reading/sending messages,
  # sending TTS messages, embedding links, sending files, reading the history, mentioning everybody,
  # connecting to voice, speaking and voice activity (push-to-talk isn't mandatory)
  def update_role(token, server_id, role_id, name, colour, hoist = false, packed_permissions = 36_953_089)
    request(
      :patch,
      "#{APIBASE}/guilds/#{server_id}/roles/#{role_id}",
      { color: colour, name: name, hoist: hoist, permissions: packed_permissions }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a role
  def delete_role(token, server_id, role_id)
    request(
      :delete,
      "#{APIBASE}/guilds/#{server_id}/roles/#{role_id}",
      Authorization: token
    )
  end

  # Update a user's roles
  def update_user_roles(token, server_id, user_id, roles)
    request(
      :patch,
      "#{APIBASE}/guilds/#{server_id}/members/#{user_id}",
      { roles: roles }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a user's permission overrides in a channel
  def update_user_overrides(token, channel_id, user_id, allow, deny)
    request(
      :put,
      "#{APIBASE}/channels/#{channel_id}/permissions/#{user_id}",
      { type: 'member', id: user_id, allow: allow, deny: deny }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a role's permission overrides in a channel
  def update_role_overrides(token, channel_id, role_id, allow, deny)
    request(
      :put,
      "#{APIBASE}/channels/#{channel_id}/permissions/#{role_id}",
      { type: 'role', id: role_id, allow: allow, deny: deny }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get the gateway to be used
  def gateway(token)
    request(
      :get,
      "#{APIBASE}/gateway",
      Authorization: token
    )
  end

  # Start typing (needs to be resent every 5 seconds to keep up the typing)
  def start_typing(token, channel_id)
    request(
      :post,
      "#{APIBASE}/channels/#{channel_id}/typing",
      nil,
      Authorization: token
    )
  end

  # Get user data
  def user(token, user_id)
    request(
      :get,
      "#{APIBASE}/users/#{user_id}",
      Authorization: token
    )
  end

  # Update user data
  def update_user(token, email, password, new_username, avatar, new_password = nil)
    request(
      :patch,
      "#{APIBASE}/users/@me",
      { avatar: avatar, email: email, new_password: new_password, password: password, username: new_username }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get a list of messages from a channel's history
  def channel_log(token, channel_id, amount, before = nil, after = nil)
    request(
      :get,
      "#{APIBASE}/channels/#{channel_id}/messages?limit=#{amount}#{"&before=#{before}" if before}#{"&after=#{after}" if after}",
      Authorization: token
    )
  end
end
