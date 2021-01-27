# frozen_string_literal: true

# API calls for User object
module Discordrb::API::User
  module_function

  # Get user data
  # https://discord.com/developers/docs/resources/user#get-user
  def resolve(token, user_id)
    Discordrb::API.request(
      :users_uid,
      nil,
      :get,
      "#{Discordrb::API.api_base}/users/#{user_id}",
      Authorization: token
    )
  end

  # Get profile data
  # https://discord.com/developers/docs/resources/user#get-current-user
  def profile(token)
    Discordrb::API.request(
      :users_me,
      nil,
      :get,
      "#{Discordrb::API.api_base}/users/@me",
      Authorization: token
    )
  end

  # Change the current bot's nickname on a server
  # https://discord.com/developers/docs/resources/user#modify-current-user
  def change_own_nickname(token, server_id, nick, reason = nil)
    Discordrb::API.request(
      :guilds_sid_members_me_nick,
      server_id, # This is technically a guild endpoint
      :patch,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/members/@me/nick",
      { nick: nick }.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Update user data
  # https://discord.com/developers/docs/resources/user#modify-current-user
  def update_profile(token, email, password, new_username, avatar, new_password = nil)
    Discordrb::API.request(
      :users_me,
      nil,
      :patch,
      "#{Discordrb::API.api_base}/users/@me",
      { avatar: avatar, email: email, new_password: new_password, password: password, username: new_username }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get the servers a user is connected to
  # https://discord.com/developers/docs/resources/user#get-current-user-guilds
  def servers(token)
    Discordrb::API.request(
      :users_me_guilds,
      nil,
      :get,
      "#{Discordrb::API.api_base}/users/@me/guilds",
      Authorization: token
    )
  end

  # Leave a server
  # https://discord.com/developers/docs/resources/user#leave-guild
  def leave_server(token, server_id)
    Discordrb::API.request(
      :users_me_guilds_sid,
      nil,
      :delete,
      "#{Discordrb::API.api_base}/users/@me/guilds/#{server_id}",
      Authorization: token
    )
  end

  # Get the DMs for the current user
  # https://discord.com/developers/docs/resources/user#get-user-dms
  def user_dms(token)
    Discordrb::API.request(
      :users_me_channels,
      nil,
      :get,
      "#{Discordrb::API.api_base}/users/@me/channels",
      Authorization: token
    )
  end

  # Create a DM to another user
  # https://discord.com/developers/docs/resources/user#create-dm
  def create_pm(token, recipient_id)
    Discordrb::API.request(
      :users_me_channels,
      nil,
      :post,
      "#{Discordrb::API.api_base}/users/@me/channels",
      { recipient_id: recipient_id }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get information about a user's connections
  # https://discord.com/developers/docs/resources/user#get-users-connections
  def connections(token)
    Discordrb::API.request(
      :users_me_connections,
      nil,
      :get,
      "#{Discordrb::API.api_base}/users/@me/connections",
      Authorization: token
    )
  end

  # Change user status setting
  def change_status_setting(token, status)
    Discordrb::API.request(
      :users_me_settings,
      nil,
      :patch,
      "#{Discordrb::API.api_base}/users/@me/settings",
      { status: status }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Returns one of the "default" discord avatars from the CDN given a discriminator
  def default_avatar(discrim = 0)
    index = discrim.to_i % 5
    "#{Discordrb::API.cdn_url}/embed/avatars/#{index}.png"
  end

  # Make an avatar URL from the user and avatar IDs
  def avatar_url(user_id, avatar_id, format = nil)
    format ||= if avatar_id.start_with?('a_')
                 'gif'
               else
                 'webp'
               end
    "#{Discordrb::API.cdn_url}/avatars/#{user_id}/#{avatar_id}.#{format}"
  end
end
