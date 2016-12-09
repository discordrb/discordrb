# API calls for Server
module Discordrb::API::Server
  module_function

  # Create a server
  # https://discordapp.com/developers/docs/resources/guild#create-guild
  def create(token, name, region = :london)
    Discordrb::API.generic_request(
      token, nil, 'guilds', :guilds, :post,
      { name: name, region: region.to_s }.to_json
    )
  end

  # Get a server's data
  # https://discordapp.com/developers/docs/resources/guild#get-guild
  def resolve(token, server_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}", :guilds_sid, :get)
  end

  # Update a server
  # https://discordapp.com/developers/docs/resources/guild#modify-guild
  def update(token, server_id, data)
    Discordrb::API.generic_request(
      token, server_id, "guilds/#{server_id}", :guilds_sid, :patch,
      data.to_json
    )
  end

  # Transfer server ownership
  def transfer_ownership(token, server_id, user_id)
    Discordrb::API.generic_request(
      token, server_id, "guilds/#{server_id}", :guilds_sid, :patch,
      { owner_id: user_id }.to_json
    )
  end

  # Delete a server
  # https://discordapp.com/developers/docs/resources/guild#delete-guild
  def delete(token, server_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}", :guilds_sid, :delete)
  end

  # Get a server's channels list
  # https://discordapp.com/developers/docs/resources/guild#get-guild-channels
  def channels(token, server_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/channels", :guilds_sid_channels, :get)
  end

  # Create a channel
  # https://discordapp.com/developers/docs/resources/guild#create-guild-channel
  def create_channel(token, server_id, name, type)
    Discordrb::API.generic_request(
      token, server_id, "guilds/#{server_id}/channels", :guilds_sid_channels, :post,
      { name: name, type: type }.to_json
    )
  end

  # Update a channels position
  # https://discordapp.com/developers/docs/resources/guild#modify-guild-channel
  def update_channel(token, server_id, channel_id, position)
    Discordrb::API.generic_request(
      token, server_id, "guilds/#{server_id}/channels", :guilds_sid_channels, :patch,
      { id: channel_id, position: position }.to_json
    )
  end

  # Get a member's data
  # https://discordapp.com/developers/docs/resources/guild#get-guild-member
  def resolve_member(token, server_id, user_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/members/#{user_id}", :guilds_sid_members_uid, :get)
  end

  # Gets members from the server
  # https://discordapp.com/developers/docs/resources/guild#list-guild-members
  def resolve_members(token, server_id, limit, after = nil)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/members?limit=#{limit}#{"&after=#{after}" if after}", :guilds_sid_members, :get)
  end

  # Update a user properties
  # https://discordapp.com/developers/docs/resources/guild#modify-guild-member
  def update_member(token, server_id, user_id, nick: nil, roles: nil, mute: nil, deaf: nil, channel_id: nil)
    Discordrb::API.generic_request(
      token, server_id, "guilds/#{server_id}/members/#{user_id}", :guilds_sid_members_uid, :patch,
      { roles: roles, nick: nick, mute: mute, deaf: deaf, channel_id: channel_id }.reject { |_, v| v.nil? }.to_json
    )
  end

  # Remove user from server
  # https://discordapp.com/developers/docs/resources/guild#remove-guild-member
  def remove_member(token, server_id, user_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/members/#{user_id}", :guilds_sid_members_uid, :delete)
  end

  # Get a server's banned users
  # https://discordapp.com/developers/docs/resources/guild#get-guild-bans
  def bans(token, server_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/bans", :guilds_sid_bans, :get)
  end

  # Ban a user from a server and delete their messages from the last message_days days
  # https://discordapp.com/developers/docs/resources/guild#create-guild-ban
  def ban_user(token, server_id, user_id, message_days)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/bans/#{user_id}?delete-message-days=#{message_days}", :guilds_sid_bans_uid, :put, nil)
  end

  # Unban a user from a server
  # https://discordapp.com/developers/docs/resources/guild#remove-guild-ban
  def unban_user(token, server_id, user_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/bans/#{user_id}", :guilds_sid_bans_uid, :delete)
  end

  # Get server roles
  # https://discordapp.com/developers/docs/resources/guild#get-guild-roles
  def roles(token, server_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/roles", :guilds_sid_roles, :get)
  end

  # Create a role (parameters such as name and colour will have to be set by update_role afterwards)
  # https://discordapp.com/developers/docs/resources/guild#get-guild-roles
  def create_role(token, server_id)
    Discordrb::API.request(
      :guilds_sid_roles,
      server_id,
      :post,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/roles",
      nil,
      Authorization: token
    )
  end

  # Update a role
  # Permissions are the Discord defaults; allowed: invite creation, reading/sending messages,
  # sending TTS messages, embedding links, sending files, reading the history, mentioning everybody,
  # connecting to voice, speaking and voice activity (push-to-talk isn't mandatory)
  # https://discordapp.com/developers/docs/resources/guild#batch-modify-guild-role
  def update_role(token, server_id, role_id, name, colour, hoist = false, mentionable = false, packed_permissions = 36_953_089)
    Discordrb::API.generic_request(
      token, server_id, "guilds/#{server_id}/roles/#{role_id}", :guilds_sid_roles_rid, :patch,
      { color: colour, name: name, hoist: hoist, mentionable: mentionable, permissions: packed_permissions }.to_json
    )
  end

  # Delete a role
  # https://discordapp.com/developers/docs/resources/guild#delete-guild-role
  def delete_role(token, server_id, role_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/roles/#{role_id}", :guilds_sid_roles_rid, :delete)
  end

  # Get server prune count
  # https://discordapp.com/developers/docs/resources/guild#get-guild-prune-count
  def prune_count(token, server_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/prune", :guilds_sid_prune, :get)
  end

  # Begin server prune
  # https://discordapp.com/developers/docs/resources/guild#begin-guild-prune
  def begin_prune(token, server_id, days)
    Discordrb::API.request(
      :guilds_sid_prune,
      server_id,
      :post,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/prune",
      { days: days },
      Authorization: token
    )
  end

  # Get invites from server
  # https://discordapp.com/developers/docs/resources/guild#get-guild-invites
  def invites(token, server_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/invites", :guilds_sid_invites, :get)
  end

  # Get server integrations
  # https://discordapp.com/developers/docs/resources/guild#get-guild-integrations
  def integrations(token, server_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/integrations", :guilds_sid_integrations, :get)
  end

  # Create a server integration
  # https://discordapp.com/developers/docs/resources/guild#create-guild-integration
  def create_integration(token, server_id, type, id)
    Discordrb::API.request(
      :guilds_sid_integrations,
      server_id,
      :post,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/integrations",
      { type: type, id: id },
      Authorization: token
    )
  end

  # Update integration from server
  # https://discordapp.com/developers/docs/resources/guild#modify-guild-integration
  def update_integration(token, server_id, integration_id, expire_behavior, expire_grace_period, enable_emoticons)
    Discordrb::API.generic_request(
      token, server_id, "guilds/#{server_id}/integrations/#{integration_id}", :guilds_sid_integrations_iid, :patch,
      { expire_behavior: expire_behavior, expire_grace_period: expire_grace_period, enable_emoticons: enable_emoticons }.to_json
    )
  end

  # Delete a server integration
  # https://discordapp.com/developers/docs/resources/guild#delete-guild-integration
  def delete_integration(token, server_id, integration_id)
    Discordrb::API.generic_request(token, server_id, "guilds/#{server_id}/integrations/#{integration_id}", :guilds_sid_integrations_iid, :delete)
  end

  # Sync an integration
  # https://discordapp.com/developers/docs/resources/guild#sync-guild-integration
  def sync_integration(token, server_id, integration_id)
    Discordrb::API.request(
      :guilds_sid_integrations_iid_sync,
      server_id,
      :post,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/integrations/#{integration_id}/sync",
      nil,
      Authorization: token
    )
  end
end
