module Discordrb::API::Server
  module_function

  # Get a server's banned users
  def bans(token, server_id)
    Discordrb::API.request(
      __method__,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/bans",
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

  # Ban a user from a server and delete their messages from the last message_days days
  def ban_user(token, server_id, user_id, message_days)
    Discordrb::API.request(
      __method__,
      :put,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/bans/#{user_id}?delete-message-days=#{message_days}",
      nil,
      Authorization: token
    )
  end
end