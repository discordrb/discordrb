# API calls for Invite object
module Discordrb::API::Invite
  module_function

  # Resolve an invite
  # https://discordapp.com/developers/docs/resources/invite#get-invite
  def resolve(token, invite_code)
    Discordrb::API.generic_request(token, nil, "invite/#{invite_code}", :invite_code, :get)
  end

  # Delete an invite by code
  # https://discordapp.com/developers/docs/resources/invite#delete-invite
  def delete(token, code)
    Discordrb::API.generic_request(token, nil, "invites/#{code}", :invites_code, :delete)
  end

  # Join a server using an invite
  # https://discordapp.com/developers/docs/resources/invite#accept-invite
  def accept(token, invite_code)
    Discordrb::API.request(
      :invite_code,
      nil,
      :post,
      "#{Discordrb::API.api_base}/invite/#{invite_code}",
      nil,
      Authorization: token
    )
  end
end
