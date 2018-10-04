# frozen_string_literal: true

# API calls for Server
module Discordrb::API::Server
  module_function

  # Create a server
  # https://discordapp.com/developers/docs/resources/guild#create-guild
  def create(token, name, region = :'eu-central')
    Discordrb::API.request(
      :guilds,
      nil,
      :POST,
      '/guilds',
      { name: name, region: region.to_s }.to_json,
      headers: { Authorization: token, content_type: :json }
    )
  end

  # Get a server's data
  # https://discordapp.com/developers/docs/resources/guild#get-guild
  def resolve(token, server_id)
    Discordrb::API.request(
      :guilds_sid,
      server_id,
      :GET,
      "/guilds/#{server_id}",
      headers: { Authorization: token }
    )
  end

  # Update a server
  # https://discordapp.com/developers/docs/resources/guild#modify-guild
  def update(token, server_id, name, region, icon, afk_channel_id, afk_timeout, splash, default_message_notifications, verification_level, explicit_content_filter, system_channel_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid,
      server_id,
      :PATCH,
      "/guilds/#{server_id}",
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason },
      payload: { name: name, region: region, icon: icon, afk_channel_id: afk_channel_id, afk_timeout: afk_timeout, splash: splash, default_message_notifications: default_message_notifications, verification_level: verification_level, explicit_content_filter: explicit_content_filter, system_channel_id: system_channel_id }
    )
  end

  # Transfer server ownership
  def transfer_ownership(token, server_id, user_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid,
      server_id,
      :PATCH,
      "/guilds/#{server_id}",
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason },
      payload: { owner_id: user_id }
    )
  end

  # Delete a server
  # https://discordapp.com/developers/docs/resources/guild#delete-guild
  def delete(token, server_id)
    Discordrb::API.request(
      :guilds_sid,
      server_id,
      :DELETE,
      "/guilds/#{server_id}",
      headers: { Authorization: token }
    )
  end

  # Get a server's channels list
  # https://discordapp.com/developers/docs/resources/guild#get-guild-channels
  def channels(token, server_id)
    Discordrb::API.request(
      :guilds_sid_channels,
      server_id,
      :GET,
      "/guilds/#{server_id}/channels",
      headers: { Authorization: token }
    )
  end

  # Create a channel
  # https://discordapp.com/developers/docs/resources/guild#create-guild-channel
  def create_channel(token, server_id, name, type, topic, bitrate, user_limit, permission_overwrites, parent_id, nsfw, reason = nil)
    Discordrb::API.request(
      :guilds_sid_channels,
      server_id,
      :POST,
      "/guilds/#{server_id}/channels",
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason },
      payload: { name: name, type: type, topic: topic, bitrate: bitrate, user_limit: user_limit, permission_overwrites: permission_overwrites, parent_id: parent_id, nsfw: nsfw }
    )
  end

  # Update a channels position
  # https://discordapp.com/developers/docs/resources/guild#modify-guild-channel-positions
  def update_channel_positions(token, server_id, positions)
    Discordrb::API.request(
      :guilds_sid_channels,
      server_id,
      :PATCH,
      "/guilds/#{server_id}/channels",
      headers: { Authorization: token, content_type: :json },
      payload: positions
    )
  end

  # Get a member's data
  # https://discordapp.com/developers/docs/resources/guild#get-guild-member
  def resolve_member(token, server_id, user_id)
    Discordrb::API.request(
      :guilds_sid_members_uid,
      server_id,
      :GET,
      "/guilds/#{server_id}/members/#{user_id}",
      headers: { Authorization: token }
    )
  end

  # Gets members from the server
  # https://discordapp.com/developers/docs/resources/guild#list-guild-members
  def resolve_members(token, server_id, limit, after = nil)
    Discordrb::API.request(
      :guilds_sid_members,
      server_id,
      :GET,
      "/guilds/#{server_id}/members?limit=#{limit}#{"&after=#{after}" if after}",
      headers: { Authorization: token }
    )
  end

  # Update a user properties
  # https://discordapp.com/developers/docs/resources/guild#modify-guild-member
  def update_member(token, server_id, user_id, nick: nil, roles: nil, mute: nil, deaf: nil, channel_id: nil, reason: nil)
    data = {
      roles: roles,
      nick: nick,
      mute: mute,
      deaf: deaf,
      channel_id: channel_id
    }.reject { |_, v| v.nil? }

    Discordrb::API.request(
      :guilds_sid_members_uid,
      server_id,
      :PATCH,
      "/guilds/#{server_id}/members/#{user_id}",
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason },
      payload: data
    )
  end

  # Remove user from server
  # https://discordapp.com/developers/docs/resources/guild#remove-guild-member
  def remove_member(token, server_id, user_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_members_uid,
      server_id,
      :DELETE,
      "/guilds/#{server_id}/members/#{user_id}",
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Get a server's banned users
  # https://discordapp.com/developers/docs/resources/guild#get-guild-bans
  def bans(token, server_id)
    Discordrb::API.request(
      :guilds_sid_bans,
      server_id,
      :GET,
      "/guilds/#{server_id}/bans",
      headers: { Authorization: token }
    )
  end

  # Ban a user from a server and delete their messages from the last message_days days
  # https://discordapp.com/developers/docs/resources/guild#create-guild-ban
  def ban_user(token, server_id, user_id, message_days, reason = nil)
    Discordrb::API.request(
      :guilds_sid_bans_uid,
      server_id,
      :PUT,
      "/guilds/#{server_id}/bans/#{user_id}?delete-message-days=#{message_days}&reason=#{reason}",
      nil,
      headers: { Authorization: token }
    )
  end

  # Unban a user from a server
  # https://discordapp.com/developers/docs/resources/guild#remove-guild-ban
  def unban_user(token, server_id, user_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_bans_uid,
      server_id,
      :DELETE,
      "/guilds/#{server_id}/bans/#{user_id}",
      headers: { Authorization: token, 'X-Audit-Log-Reason': reason }
    )
  end

  # Get server roles
  # https://discordapp.com/developers/docs/resources/guild#get-guild-roles
  def roles(token, server_id)
    Discordrb::API.request(
      :guilds_sid_roles,
      server_id,
      :GET,
      "/guilds/#{server_id}/roles",
      headers: { Authorization: token }
    )
  end

  # Create a role (parameters such as name and colour if not set can be set by update_role afterwards)
  # Permissions are the Discord defaults; allowed: invite creation, reading/sending messages,
  # sending TTS messages, embedding links, sending files, reading the history, mentioning everybody,
  # connecting to voice, speaking and voice activity (push-to-talk isn't mandatory)
  # https://discordapp.com/developers/docs/resources/guild#get-guild-roles
  def create_role(token, server_id, name, colour, hoist, mentionable, packed_permissions, reason = nil)
    Discordrb::API.request(
      :guilds_sid_roles,
      server_id,
      :POST,
      "/guilds/#{server_id}/roles",
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason },
      payload: { color: colour, name: name, hoist: hoist, mentionable: mentionable, permissions: packed_permissions }
    )
  end

  # Update a role
  # Permissions are the Discord defaults; allowed: invite creation, reading/sending messages,
  # sending TTS messages, embedding links, sending files, reading the history, mentioning everybody,
  # connecting to voice, speaking and voice activity (push-to-talk isn't mandatory)
  # https://discordapp.com/developers/docs/resources/guild#batch-modify-guild-role
  def update_role(token, server_id, role_id, name, colour, hoist = false, mentionable = false, packed_permissions = 104_324_161, reason = nil)
    Discordrb::API.request(
      :guilds_sid_roles_rid,
      server_id,
      :PATCH,
      "/guilds/#{server_id}/roles/#{role_id}",
      headers: { Authorization: token,      content_type: :json, 'X-Audit-Log-Reason': reason },
      payload: { color: colour, name: name, hoist: hoist, mentionable: mentionable, permissions: packed_permissions }
    )
  end

  # Update role positions
  # https://discordapp.com/developers/docs/resources/guild#modify-guild-role-positions
  def update_role_positions(token, server_id, roles)
    Discordrb::API.request(
      :guilds_sid_roles,
      server_id,
      :PATCH,
      "/guilds/#{server_id}/roles",
      headers: { Authorization: token, content_type: :json },
      payload: roles
    )
  end

  # Delete a role
  # https://discordapp.com/developers/docs/resources/guild#delete-guild-role
  def delete_role(token, server_id, role_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_roles_rid,
      server_id,
      :DELETE,
      "/guilds/#{server_id}/roles/#{role_id}",
      headers: { Authorization: token, 'X-Audit-Log-Reason': reason }
    )
  end

  # Adds a single role to a member
  # https://discordapp.com/developers/docs/resources/guild#add-guild-member-role
  def add_member_role(token, server_id, user_id, role_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_members_uid_roles_rid,
      server_id,
      :PUT,
      "/guilds/#{server_id}/members/#{user_id}/roles/#{role_id}",
      headers: { Authorization: token, 'X-Audit-Log-Reason': reason }
    )
  end

  # Removes a single role from a member
  # https://discordapp.com/developers/docs/resources/guild#remove-guild-member-role
  def remove_member_role(token, server_id, user_id, role_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_members_uid_roles_rid,
      server_id,
      :DELETE,
      "/guilds/#{server_id}/members/#{user_id}/roles/#{role_id}",
      headers: { Authorization: token, 'X-Audit-Log-Reason': reason }
    )
  end

  # Get server prune count
  # https://discordapp.com/developers/docs/resources/guild#get-guild-prune-count
  def prune_count(token, server_id, days)
    Discordrb::API.request(
      :guilds_sid_prune,
      server_id,
      :GET,
      "/guilds/#{server_id}/prune?days=#{days}",
      headers: { Authorization: token }
    )
  end

  # Begin server prune
  # https://discordapp.com/developers/docs/resources/guild#begin-guild-prune
  def begin_prune(token, server_id, days, reason = nil)
    Discordrb::API.request(
      :guilds_sid_prune,
      server_id,
      :POST,
      "/guilds/#{server_id}/prune",
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason },
      payload: { days: days }
    )
  end

  # Get invites from server
  # https://discordapp.com/developers/docs/resources/guild#get-guild-invites
  def invites(token, server_id)
    Discordrb::API.request(
      :guilds_sid_invites,
      server_id,
      :GET,
      "/guilds/#{server_id}/invites",
      headers: { Authorization: token }
    )
  end

  # Gets a server's audit logs
  # https://discordapp.com/developers/docs/resources/audit-log#get-guild-audit-log
  def audit_logs(token, server_id, limit, userid = nil, actiontype = nil, before = nil)
    Discordrb::API.request(
      :guilds_sid_auditlogs,
      server_id,
      :GET,
      "/guilds/#{server_id}/audit-logs?limit=#{limit}#{"&user_id=#{userid}" if userid}#{"&action_type=#{actiontype}" if actiontype}#{"&before=#{before}" if before}",
      headers: { Authorization: token }
    )
  end

  # Get server integrations
  # https://discordapp.com/developers/docs/resources/guild#get-guild-integrations
  def integrations(token, server_id)
    Discordrb::API.request(
      :guilds_sid_integrations,
      server_id,
      :GET,
      "/guilds/#{server_id}/integrations",
      headers: { Authorization: token }
    )
  end

  # Create a server integration
  # https://discordapp.com/developers/docs/resources/guild#create-guild-integration
  def create_integration(token, server_id, type, id)
    Discordrb::API.request(
      :guilds_sid_integrations,
      server_id,
      :POST,
      "/guilds/#{server_id}/integrations",
      headers: { Authorization: token, content_type: :json },
      payload: { type: type, id: id }
    )
  end

  # Update integration from server
  # https://discordapp.com/developers/docs/resources/guild#modify-guild-integration
  def update_integration(token, server_id, integration_id, expire_behavior, expire_grace_period, enable_emoticons)
    Discordrb::API.request(
      :guilds_sid_integrations_iid,
      server_id,
      :PATCH,
      "/guilds/#{server_id}/integrations/#{integration_id}",
      headers: { Authorization: token, content_type: :json },
      payload: { expire_behavior: expire_behavior, expire_grace_period: expire_grace_period, enable_emoticons: enable_emoticons }
    )
  end

  # Delete a server integration
  # https://discordapp.com/developers/docs/resources/guild#delete-guild-integration
  def delete_integration(token, server_id, integration_id)
    Discordrb::API.request(
      :guilds_sid_integrations_iid,
      server_id,
      :DELETE,
      "/guilds/#{server_id}/integrations/#{integration_id}",
      headers: { Authorization: token }
    )
  end

  # Sync an integration
  # https://discordapp.com/developers/docs/resources/guild#sync-guild-integration
  def sync_integration(token, server_id, integration_id)
    Discordrb::API.request(
      :guilds_sid_integrations_iid_sync,
      server_id,
      :POST,
      "/guilds/#{server_id}/integrations/#{integration_id}/sync",
      headers: { Authorization: token }
    )
  end

  # Retrieves a server's embed information
  # https://discordapp.com/developers/docs/resources/guild#get-guild-embed
  def embed(token, server_id)
    Discordrb::API.request(
      :guilds_sid_embed,
      server_id,
      :GET,
      "/guilds/#{server_id}/embed",
      headers: { Authorization: token }
    )
  end

  # Modify a server's embed settings
  # https://discordapp.com/developers/docs/resources/guild#modify-guild-embed
  def modify_embed(token, server_id, enabled, channel_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_embed,
      server_id,
      :PATCH,
      "/guilds/#{server_id}/embed",
      headers: { Authorization: token, 'X-Audit-Log-Reason': reason, content_type: :json },
      payload: { enabled: enabled, channel_id: channel_id }
    )
  end

  # Adds a custom emoji
  def add_emoji(token, server_id, image, name, reason = nil)
    Discordrb::API.request(
      :guilds_sid_emojis,
      server_id,
      :POST,
      "/guilds/#{server_id}/emojis",
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason },
      payload: { image: image, name: name }
    )
  end

  # Changes an emoji name
  def edit_emoji(token, server_id, emoji_id, name, reason = nil)
    Discordrb::API.request(
      :guilds_sid_emojis_eid,
      server_id,
      :PATCH,
      "/guilds/#{server_id}/emojis/#{emoji_id}",
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason },
      payload: { name: name }
    )
  end

  # Deletes a custom emoji
  def delete_emoji(token, server_id, emoji_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_emojis_eid,
      server_id,
      :DELETE,
      "/guilds/#{server_id}/emojis/#{emoji_id}",
      headers: { Authorization: token, 'X-Audit-Log-Reason': reason }
    )
  end

  # Available voice regions for this server
  def regions(token, server_id)
    Discordrb::API.request(
      :guilds_sid_regions,
      server_id,
      :GET,
      "/guilds/#{server_id}/regions",
      headers: { Authorization: token }
    )
  end

  # Get server webhooks
  # https://discordapp.com/developers/docs/resources/webhook#get-guild-webhooks
  def webhooks(token, server_id)
    Discordrb::API.request(
      :guilds_sid_webhooks,
      server_id,
      :GET,
      "/guilds/#{server_id}/webhooks",
      headers: { Authorization: token }
    )
  end

  # Adds a member to a server with an OAuth2 Bearer token that has been granted `guilds.join`
  # https://discordapp.com/developers/docs/resources/guild#add-guild-member
  def add_member(token, server_id, user_id, access_token, nick = nil, roles = [], mute = false, deaf = false)
    Discordrb::API.request(
      :guilds_sid_members_uid,
      server_id,
      :PUT,
      "/guilds/#{server_id}/members/#{user_id}",
      headers: { content_type: :json, Authorization: token },
      payload: { access_token: access_token, nick: nick, roles: roles, mute: mute, deaf: deaf }
    )
  end
end
