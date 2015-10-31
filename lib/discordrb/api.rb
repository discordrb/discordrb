require 'rest-client'
require 'json'

module Discordrb::API
  APIBASE = 'https://discordapp.com/api'
  module_function

  # Ban a user from a server and delete their messages from the last message_days days
  def ban_user(token, server_id, user_id, message_days)
    RestClient.put(
      "#{APIBASE}/guilds/#{server_id}/bans/#{user_id}?delete-message-days=#{message_days}",
      Authorization: token
    )
  end

  # Get a server's banned users
  def bans(token, server_id)
    RestClient.get(
      "#{APIBASE}/guilds/#{server_id}/bans",
      Authorization: token
    )
  end

  # Login to the server
  def login(email, password)
    RestClient.post(
      "#{APIBASE}/auth/login",
      email: email,
      password: password
    )
  end

  # Logout from the server
  def logout(token)
    RestClient.post(
      "#{APIBASE}/auth/logout",
      Authorization: token
    )
  end

  # Create a server
  def create_server(token, name, region)
    RestClient.post(
      "#{APIBASE}/guilds",
      { 'name' => name, 'region' => region }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Leave a server
  def leave_server(server_id)
    RestClient.delete(
      "#{APIBASE}/guilds/#{server_id}",
      Authorization: token
    )
  end

  # Get a channel's data
  def channel(token, channel_id)
    RestClient.get(
      "#{APIBASE}/channels/#{channel_id}",
      Authorization: token
    )
  end

  # Create a channel
  def create_channel(token, server_id, name, type)
    RestClient.post(
      "#{APIBASE}/guilds/#{server_id}/channels",
      { 'name' => name, 'type' => type }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a channel's data
  def update_channel(token, channel_id, name, topic, position = 0)
    RestClient.patch(
      "#{APIBASE}/channels/#{channel_id}",
      { 'name' => name, 'position' => position, 'topic' => topic }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a channel
  def delete_channel(token, channel_id)
    RestClient.delete(
      "#{APIBASE}/channels/#{channel_id}",
      Authorization: token
    )
  end

  # Join a server using an invite
  def join_server(token, invite_id)
    RestClient.post(
      "#{APIBASE}/invite/#{invite_id}",
      Authorization: token
    )
  end

  # Resolve an invite
  def resolve_invite(token, code)
    RestClient.get(
      "#{APIBASE}/invite/#{code}",
      Authorization: token
    )
  end

  # Create a private channel
  def create_private(token, bot_user_id, user_id)
    RestClient.post(
      "#{APIBASE}/users/#{bot_user_id}/channels",
      { 'recipient_id' => user_id }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Create an instant invite from a server or a channel id
  def create_invite(token, id, max_age = 0, max_uses = 0, temporary = false, xkcd = false)
    RestClient.post(
      "#{APIBASE}/channels/#{id}/invites",
      { 'max_age' => max_age, 'max_uses' => max_uses, 'temporary' => temporary, 'xkcdpass' => xkcd }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Send a message to a channel
  def send_message(token, channel_id, message, mentions = [], tts = false)
    RestClient.post(
      "#{APIBASE}/channels/#{channel_id}/messages",
      { 'content' => message, 'mentions' => mentions, tts => tts }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a message
  def delete_message(token, channel_id, message_id)
    RestClient.delete(
      "#{APIBASE}/channels/#{channel_id}/messages/#{message_id}",
      Authorization: token
    )
  end

  # Edit a message
  def edit_message(token, channel_id, message, mentions = [])
    RestClient.patch(
      "#{APIBASE}/channels/#{channel_id}/messages",
      { 'content' => message, 'mentions' => mentions }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Acknowledge that a message has been received
  # The last acknowledged message will be sent in the ready packet,
  # so this is an easy way to catch up on messages
  def acknowledge_message(token, channel_id, message_id)
    RestClient.post(
      "#{APIBASE}/channels/#{channel_id}/messages/#{message_id}/ack",
      Authorization: token
    )
  end

  # Send a file as a message to a channel
  def send_file(token, channel_id, file, filename = 'filename')
    RestClient.post(
      "#{APIBASE}/channels/#{channel_id}/messages",
      (filename.to_sym) => file,
      Authorization: token
    )
  end

  # Create a role (parameters such as name and colour will have to be set by update_role afterwards)
  def create_role(token, server_id)
    RestClient.post(
      "#{APIBASE}/guilds/#{server_id}/roles",
      Authorization: token
    )
  end

  # Update a role
  # Permissions are the Discord defaults; allowed: invite creation, reading/sending messages,
  # sending TTS messages, embedding links, sending files, reading the history, mentioning everybody,
  # connecting to voice, speaking and voice activity (push-to-talk isn't mandatory)
  def update_role(token, server_id, role_id, name, colour, hoist = false, packed_permissions = 36953089)
    RestClient.patch(
      "#{APIBASE}/guilds/#{server_id}/roles/#{role_id}",
      { 'color' => colour, 'name' => name, 'hoist' => hoist, 'permissions' => packed_permissions }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a role
  def delete_role(token, server_id, role_id)
    RestClient.delete(
      "#{APIBASE}/guilds/#{server_id}/roles/#{role_id}",
      Authorization: token
    )
  end

  # Update a user's roles
  def update_user_roles(token, server_id, user_id, roles)
    RestClient.patch(
      "#{APIBASE}/guilds/#{server_id}/members/#{user_id}",
      { 'roles' => roles }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a user's permission overrides in a channel
  def update_user_overrides(token, channel_id, user_id, allow, deny)
    RestClient.put(
      "#{APIBASE}/channels/#{channel_id}/permissions/#{user_id}",
      { 'type' => 'member', 'id' => user_id, 'allow' => allow, 'deny' => deny }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a role's permission overrides in a channel
  def update_role_overrides(token, channel_id, role_id, allow, deny)
    RestClient.put(
      "#{APIBASE}/channels/#{channel_id}/permissions/#{role_id}",
      { 'type' => 'role', 'id' => role_id, 'allow' => allow, 'deny' => deny }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get the gateway to be used
  def gateway(token)
    RestClient.get(
      "#{APIBASE}/gateway",
      Authorization: token
    )
  end

  # Start typing (needs to be resent every 5 seconds to keep up the typing)
  def start_typing(token, channel_id)
    RestClient.post(
      "#{APIBASE}/channels/#{channel_id}/typing",
      Authorization: token
    )
  end

  # Get user data
  def user(token, user_id)
    RestClient.get(
      "#{APIBASE}/users/#{user_id}",
      Authorization: token
    )
  end

  # Update user data
  def update_user(token, email, password, new_username, avatar, new_password = nil)
    RestClient.patch(
      "#{APIBASE}/users/@me",
      { 'avatar' => avatar, 'email' => email, 'new_password' => new_password, 'password' => password, 'username' => new_username }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get a list of messages from a channel's history
  def channel_log(token, channel_id, amount, before = nil, after = nil)
    RestClient.get(
      "#{APIBASE}/channels/#{channel_id}/messages?limit=#{amount}#{"&before=#{before}" if before}#{"&after=#{after}" if after}",
      Authorization: token
    )
  end

end
