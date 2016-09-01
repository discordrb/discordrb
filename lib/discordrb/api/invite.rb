# API calls for Invite object
module Discordrb::API::Invite
  module_function

  # Resolve an invite
  # https://discordapp.com/developers/docs/resources/invite#get-invite
  def resolve(token, invite_code)
    Discordrb::API.request(
      __method__,
      :get,
      "#{Discordrb::API.api_base}/invite/#{invite_code}",
      Authorization: token
    )
  end

  # Delete an invite by code
  # https://discordapp.com/developers/docs/resources/invite#delete-invite
  def delete(token, code)
    Discordrb::API.request(
      __method__,
      :delete,
      "#{Discordrb::API.api_base}/invites/#{code}",
      Authorization: token
    )
  end

  # Join a server using an invite
  # https://discordapp.com/developers/docs/resources/invite#accept-invite
  def accept(token, invite_code)
    Discordrb::API.request(
      __method__,
      :post,
      "#{Discordrb::API.api_base}/invite/#{invite_code}",
      nil,
      Authorization: token
    )
  end
end