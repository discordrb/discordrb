# API calls for User object
module Discordrb::API::User
  module_function

  # Returns users based on a query
  # https://discordapp.com/developers/docs/resources/user#query-users
  def query(token, query, limit = nil)
    Discordrb::API.request(
      __method__,
      :get,
      "#{Discordrb::API.api_base}/users?q=#{query}#{"&limit=#{limit}" if limit}",
      Authorization: token
    )
  end

  # Get user data
  # https://discordapp.com/developers/docs/resources/user#get-user
  def resolve(token, user_id)
    Discordrb::API.request(
      __method__,
      :get,
      "#{Discordrb::API.api_base}/users/#{user_id}",
      Authorization: token
    )
  end

  # Get profile data
  # https://discordapp.com/developers/docs/resources/user#get-current-user
  def profile(token)
    Discordrb::API.request(
      __method__,
      :get,
      "#{Discordrb::API.api_base}/users/@me",
      Authorization: token
    )
  end

  # Change the current bot's nickname on a server
  def change_own_nickname(token, server_id, nick)
    Discordrb::API.request(
      __method__,
      :patch,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/members/@me/nick",
      { nick: nick }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update user data
  # https://discordapp.com/developers/docs/resources/user#modify-current-user
  def update_profile(token, email, password, new_username, avatar, new_password = nil)
    Discordrb::API.request(
      __method__,
      :patch,
      "#{Discordrb::API.api_base}/users/@me",
      { avatar: avatar, email: email, new_password: new_password, password: password, username: new_username }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get the servers a user is connected to
  # https://discordapp.com/developers/docs/resources/user#get-current-user-guilds
  def servers(token)
    Discordrb::API.request(
      __method__,
      :get,
      "#{Discordrb::API.api_base}/users/@me/guilds",
      Authorization: token
    )
  end

  # Leave a server
  # https://discordapp.com/developers/docs/resources/user#leave-guild
  def leave_server(token, server_id)
    Discordrb::API.request(
      __method__,
      :delete,
      "#{Discordrb::API.api_base}/users/@me/guilds/#{server_id}",
      Authorization: token
    )
  end

  # Get the DMs for the current user
  # https://discordapp.com/developers/docs/resources/user#get-user-dms
  def user_dms(token)
    Discordrb::API.request(
      __method__,
      :get,
      "#{Discordrb::API.api_base}/users/@me/channels",
      Authorization: token
    )
  end

  # Create a DM to another user
  # https://discordapp.com/developers/docs/resources/user#create-dm
  def create_private(token, recipient_id)
    Discordrb::API.request(
      __method__,
      :post,
      "#{Discordrb::API.api_base}/users/@me/channels",
      { recipient_id: recipient_id }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get information about a user's connections
  # https://discordapp.com/developers/docs/resources/user#get-users-connections
  def connections(token)
    Discordrb::API.request(
      __method__,
      :get,
      "#{Discordrb::API.api_base}/users/@me/connections",
      Authorization: token
    )
  end

  # Make an avatar URL from the user and avatar IDs
  def avatar_url(user_id, avatar_id)
    "#{Discordrb::API.api_base}/users/#{user_id}/avatars/#{avatar_id}.jpg"
  end
end
