# frozen_string_literal: true

# API calls for Invite object
module Discordrb::API::Invite
  module_function

  # Resolve an invite
  # https://discordapp.com/developers/docs/resources/invite#get-invite
  def resolve(token, invite_code, counts = true)
    Discordrb::API.request(
      :invite_code,
      nil,
      :GET,
      "/invite/#{invite_code}#{counts ? '?with_counts=true' : ''}",
      headers: { Authorization: token }
    )
  end

  # Delete an invite by code
  # https://discordapp.com/developers/docs/resources/invite#delete-invite
  def delete(token, code, reason = nil)
    Discordrb::API.request(
      :invites_code,
      nil,
      :DELETE,
      "/invites/#{code}",
      headers: { Authorization: token, 'X-Audit-Log-Reason': reason }
    )
  end

  # Join a server using an invite
  # https://discordapp.com/developers/docs/resources/invite#accept-invite
  def accept(token, invite_code)
    Discordrb::API.request(
      :invite_code,
      nil,
      :POST,
      "/invite/#{invite_code}",
      headers: { Authorization: token }
    )
  end
end
