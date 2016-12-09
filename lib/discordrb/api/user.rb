# API calls for User object
module Discordrb::API::User
  module_function

  # Returns users based on a query
  # https://discordapp.com/developers/docs/resources/user#query-users
  def query(token, query, limit = nil)
    Discordrb::API.generic_request(token, nil, "users?q=#{query}#{"&limit=#{limit}" if limit}", :users, :get)
  end

  # Get user data
  # https://discordapp.com/developers/docs/resources/user#get-user
  def resolve(token, user_id)
    Discordrb::API.generic_request(token, user_id, "users/#{user_id}", :users_uid, :get)
  end

  # Get profile data
  # https://discordapp.com/developers/docs/resources/user#get-current-user
  def profile(token)
    Discordrb::API.generic_request(token, nil, 'users/@me', :users_me, :get)
  end

  # Change the current bot's nickname on a server
  def change_own_nickname(token, server_id, nick)
    Discordrb::API.update(token, server_id, "guilds/#{server_id}/members/@me/nick", :guilds_sid_members_me_nick, { nick: nick }.to_json)
  end

  # Update user data
  # https://discordapp.com/developers/docs/resources/user#modify-current-user
  def update_profile(token, email, password, new_username, avatar, new_password = nil)
    Discordrb::API.generic_request(
      token, nil, 'users/@me', :users_me, :patch,
      { avatar: avatar, email: email, new_password: new_password, password: password, username: new_username }.to_json
    )
  end

  # Get the servers a user is connected to
  # https://discordapp.com/developers/docs/resources/user#get-current-user-guilds
  def servers(token)
    Discordrb::API.generic_request(token, nil, 'users/@me/guilds', :users_me_guilds, :get)
  end

  # Leave a server
  # https://discordapp.com/developers/docs/resources/user#leave-guild
  def leave_server(token, server_id)
    Discordrb::API.generic_request(token, nil, "users/@me/guilds/#{server_id}", :users_me_guilds_sid, :delete)
  end

  # Get the DMs for the current user
  # https://discordapp.com/developers/docs/resources/user#get-user-dms
  def user_dms(token)
    Discordrb::API.generic_request(token, nil, 'users/@me/channels', :users_me_channels, :get)
  end

  # Create a DM to another user
  # https://discordapp.com/developers/docs/resources/user#create-dm
  def create_pm(token, recipient_id)
    Discordrb::API.generic_request(
      token, nil, 'users/@me/channels', :users_me_channels, :post,
      { recipient_id: recipient_id }.to_json
    )
  end

  # Get information about a user's connections
  # https://discordapp.com/developers/docs/resources/user#get-users-connections
  def connections(token)
    Discordrb::API.generic_request(token, nil, 'users/@me/connections', :users_me_connections, :get)
  end

  # Change user status setting
  def change_status_setting(token, status)
    Discordrb::API.generic_request(
      token, nil, 'users/@me/settings', :user_me_settings, :patch,
      { status: status }.to_json
    )
  end

  # Make an avatar URL from the user and avatar IDs
  def avatar_url(user_id, avatar_id)
    "#{Discordrb::API.api_base}/users/#{user_id}/avatars/#{avatar_id}.jpg"
  end
end
