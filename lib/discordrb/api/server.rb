module Discordrb::API::Server
  module_function

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