# frozen_string_literal: true

# API calls for Server
module Discordrb::API::Server
  module_function

  # Create a server
  # https://discord.com/developers/docs/resources/guild#create-guild
  def create(token, name, region = :'eu-central')
    Discordrb::API.request(
      :guilds,
      nil,
      :post,
      "#{Discordrb::API.api_base}/guilds",
      { name: name, region: region.to_s }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get a server's data
  # https://discord.com/developers/docs/resources/guild#get-guild
  def resolve(token, server_id, with_counts = nil)
    Discordrb::API.request(
      :guilds_sid,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}#{'?with_counts=true' if with_counts}",
      Authorization: token
    )
  end

  # Update a server
  # https://discord.com/developers/docs/resources/guild#modify-guild
  def update(token, server_id, name, region, icon, afk_channel_id, afk_timeout, splash, default_message_notifications, verification_level, explicit_content_filter, system_channel_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid,
      server_id,
      :patch,
      "#{Discordrb::API.api_base}/guilds/#{server_id}",
      { name: name, region: region, icon: icon, afk_channel_id: afk_channel_id, afk_timeout: afk_timeout, splash: splash, default_message_notifications: default_message_notifications, verification_level: verification_level, explicit_content_filter: explicit_content_filter, system_channel_id: system_channel_id }.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Transfer server ownership
  # https://discord.com/developers/docs/resources/guild#modify-guild
  def transfer_ownership(token, server_id, user_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid,
      server_id,
      :patch,
      "#{Discordrb::API.api_base}/guilds/#{server_id}",
      { owner_id: user_id }.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Delete a server
  # https://discord.com/developers/docs/resources/guild#delete-guild
  def delete(token, server_id)
    Discordrb::API.request(
      :guilds_sid,
      server_id,
      :delete,
      "#{Discordrb::API.api_base}/guilds/#{server_id}",
      Authorization: token
    )
  end

  # Get a server's channels list
  # https://discord.com/developers/docs/resources/guild#get-guild-channels
  def channels(token, server_id)
    Discordrb::API.request(
      :guilds_sid_channels,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/channels",
      Authorization: token
    )
  end

  # Create a channel
  # https://discord.com/developers/docs/resources/guild#create-guild-channel
  def create_channel(token, server_id, name, type, topic, bitrate, user_limit, permission_overwrites, parent_id, nsfw, rate_limit_per_user, position, reason = nil)
    Discordrb::API.request(
      :guilds_sid_channels,
      server_id,
      :post,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/channels",
      { name: name, type: type, topic: topic, bitrate: bitrate, user_limit: user_limit, permission_overwrites: permission_overwrites, parent_id: parent_id, nsfw: nsfw, rate_limit_per_user: rate_limit_per_user, position: position }.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Update a channels position
  # https://discord.com/developers/docs/resources/guild#modify-guild-channel-positions
  def update_channel_positions(token, server_id, positions)
    Discordrb::API.request(
      :guilds_sid_channels,
      server_id,
      :patch,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/channels",
      positions.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get a member's data
  # https://discord.com/developers/docs/resources/guild#get-guild-member
  def resolve_member(token, server_id, user_id)
    Discordrb::API.request(
      :guilds_sid_members_uid,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/members/#{user_id}",
      Authorization: token
    )
  end

  # Gets members from the server
  # https://discord.com/developers/docs/resources/guild#list-guild-members
  def resolve_members(token, server_id, limit, after = nil)
    Discordrb::API.request(
      :guilds_sid_members,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/members?limit=#{limit}#{"&after=#{after}" if after}",
      Authorization: token
    )
  end

  # Update a user properties
  # https://discord.com/developers/docs/resources/guild#modify-guild-member
  def update_member(token, server_id, user_id, nick: nil, roles: nil, mute: nil, deaf: nil, channel_id: nil, reason: nil)
    Discordrb::API.request(
      :guilds_sid_members_uid,
      server_id,
      :patch,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/members/#{user_id}", {
        roles: roles,
        nick: nick,
        mute: mute,
        deaf: deaf,
        channel_id: channel_id
      }.compact.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Remove user from server
  # https://discord.com/developers/docs/resources/guild#remove-guild-member
  def remove_member(token, server_id, user_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_members_uid,
      server_id,
      :delete,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/members/#{user_id}",
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Get a server's banned users
  # https://discord.com/developers/docs/resources/guild#get-guild-bans
  def bans(token, server_id)
    Discordrb::API.request(
      :guilds_sid_bans,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/bans",
      Authorization: token
    )
  end

  # Ban a user from a server and delete their messages from the last message_days days
  # https://discord.com/developers/docs/resources/guild#create-guild-ban
  def ban_user(token, server_id, user_id, message_days, reason = nil)
    reason = URI.encode_www_form_component(reason) if reason
    Discordrb::API.request(
      :guilds_sid_bans_uid,
      server_id,
      :put,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/bans/#{user_id}?delete-message-days=#{message_days}&reason=#{reason}",
      nil,
      Authorization: token
    )
  end

  # Unban a user from a server
  # https://discord.com/developers/docs/resources/guild#remove-guild-ban
  def unban_user(token, server_id, user_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_bans_uid,
      server_id,
      :delete,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/bans/#{user_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Get server roles
  # https://discord.com/developers/docs/resources/guild#get-guild-roles
  def roles(token, server_id)
    Discordrb::API.request(
      :guilds_sid_roles,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/roles",
      Authorization: token
    )
  end

  # Create a role (parameters such as name and colour if not set can be set by update_role afterwards)
  # Permissions are the Discord defaults; allowed: invite creation, reading/sending messages,
  # sending TTS messages, embedding links, sending files, reading the history, mentioning everybody,
  # connecting to voice, speaking and voice activity (push-to-talk isn't mandatory)
  # https://discord.com/developers/docs/resources/guild#get-guild-roles
  def create_role(token, server_id, name, colour, hoist, mentionable, packed_permissions, reason = nil)
    Discordrb::API.request(
      :guilds_sid_roles,
      server_id,
      :post,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/roles",
      { color: colour, name: name, hoist: hoist, mentionable: mentionable, permissions: packed_permissions }.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Update a role
  # Permissions are the Discord defaults; allowed: invite creation, reading/sending messages,
  # sending TTS messages, embedding links, sending files, reading the history, mentioning everybody,
  # connecting to voice, speaking and voice activity (push-to-talk isn't mandatory)
  # https://discord.com/developers/docs/resources/guild#batch-modify-guild-role
  def update_role(token, server_id, role_id, name, colour, hoist = false, mentionable = false, packed_permissions = 104_324_161, reason = nil)
    Discordrb::API.request(
      :guilds_sid_roles_rid,
      server_id,
      :patch,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/roles/#{role_id}",
      { color: colour, name: name, hoist: hoist, mentionable: mentionable, permissions: packed_permissions }.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Update role positions
  # https://discord.com/developers/docs/resources/guild#modify-guild-role-positions
  def update_role_positions(token, server_id, roles)
    Discordrb::API.request(
      :guilds_sid_roles,
      server_id,
      :patch,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/roles",
      roles.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a role
  # https://discord.com/developers/docs/resources/guild#delete-guild-role
  def delete_role(token, server_id, role_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_roles_rid,
      server_id,
      :delete,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/roles/#{role_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Adds a single role to a member
  # https://discord.com/developers/docs/resources/guild#add-guild-member-role
  def add_member_role(token, server_id, user_id, role_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_members_uid_roles_rid,
      server_id,
      :put,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/members/#{user_id}/roles/#{role_id}",
      nil,
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Removes a single role from a member
  # https://discord.com/developers/docs/resources/guild#remove-guild-member-role
  def remove_member_role(token, server_id, user_id, role_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_members_uid_roles_rid,
      server_id,
      :delete,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/members/#{user_id}/roles/#{role_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Get server prune count
  # https://discord.com/developers/docs/resources/guild#get-guild-prune-count
  def prune_count(token, server_id, days)
    Discordrb::API.request(
      :guilds_sid_prune,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/prune?days=#{days}",
      Authorization: token
    )
  end

  # Begin server prune
  # https://discord.com/developers/docs/resources/guild#begin-guild-prune
  def begin_prune(token, server_id, days, reason = nil)
    Discordrb::API.request(
      :guilds_sid_prune,
      server_id,
      :post,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/prune",
      { days: days },
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Get invites from server
  # https://discord.com/developers/docs/resources/guild#get-guild-invites
  def invites(token, server_id)
    Discordrb::API.request(
      :guilds_sid_invites,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/invites",
      Authorization: token
    )
  end

  # Gets a server's audit logs
  # https://discord.com/developers/docs/resources/audit-log#get-guild-audit-log
  def audit_logs(token, server_id, limit, user_id = nil, action_type = nil, before = nil)
    Discordrb::API.request(
      :guilds_sid_auditlogs,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/audit-logs?limit=#{limit}#{"&user_id=#{user_id}" if user_id}#{"&action_type=#{action_type}" if action_type}#{"&before=#{before}" if before}",
      Authorization: token
    )
  end

  # Get server integrations
  # https://discord.com/developers/docs/resources/guild#get-guild-integrations
  def integrations(token, server_id)
    Discordrb::API.request(
      :guilds_sid_integrations,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/integrations",
      Authorization: token
    )
  end

  # Create a server integration
  # https://discordapp.com/developers/docs/resources/guild#create-guild-integration
  def create_integration(token, server_id, type, id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_integrations,
      server_id,
      :post,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/integrations",
      { type: type, id: id },
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Update integration from server
  # https://discord.com/developers/docs/resources/guild#modify-guild-integration
  def update_integration(token, server_id, integration_id, expire_behavior, expire_grace_period, enable_emoticons)
    Discordrb::API.request(
      :guilds_sid_integrations_iid,
      server_id,
      :patch,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/integrations/#{integration_id}",
      { expire_behavior: expire_behavior, expire_grace_period: expire_grace_period, enable_emoticons: enable_emoticons }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a server integration
  # https://discordapp.com/developers/docs/resources/guild#delete-guild-integration
  def delete_integration(token, server_id, integration_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_integrations_iid,
      server_id,
      :delete,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/integrations/#{integration_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Sync an integration
  # https://discord.com/developers/docs/resources/guild#sync-guild-integration
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

  # Retrieves a server's embed information
  # https://discord.com/developers/docs/resources/guild#get-guild-embed
  def embed(token, server_id)
    Discordrb::API.request(
      :guilds_sid_embed,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/embed",
      Authorization: token
    )
  end

  # Modify a server's embed settings
  # https://discord.com/developers/docs/resources/guild#modify-guild-embed
  def modify_embed(token, server_id, enabled, channel_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_embed,
      server_id,
      :patch,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/embed",
      { enabled: enabled, channel_id: channel_id }.to_json,
      Authorization: token,
      'X-Audit-Log-Reason': reason,
      content_type: :json
    )
  end

  # Adds a custom emoji.
  # https://discord.com/developers/docs/resources/emoji#create-guild-emoji
  def add_emoji(token, server_id, image, name, roles = [], reason = nil)
    Discordrb::API.request(
      :guilds_sid_emojis,
      server_id,
      :post,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/emojis",
      { image: image, name: name, roles: roles }.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Changes an emoji name and/or roles.
  # https://discord.com/developers/docs/resources/emoji#modify-guild-emoji
  def edit_emoji(token, server_id, emoji_id, name, roles = nil, reason = nil)
    Discordrb::API.request(
      :guilds_sid_emojis_eid,
      server_id,
      :patch,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/emojis/#{emoji_id}",
      { name: name, roles: roles }.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Deletes a custom emoji
  # https://discord.com/developers/docs/resources/emoji#delete-guild-emoji
  def delete_emoji(token, server_id, emoji_id, reason = nil)
    Discordrb::API.request(
      :guilds_sid_emojis_eid,
      server_id,
      :delete,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/emojis/#{emoji_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Available voice regions for this server
  # https://discord.com/developers/docs/resources/guild#get-guild-voice-regions
  def regions(token, server_id)
    Discordrb::API.request(
      :guilds_sid_regions,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/regions",
      Authorization: token
    )
  end

  # Get server webhooks
  # https://discord.com/developers/docs/resources/webhook#get-guild-webhooks
  def webhooks(token, server_id)
    Discordrb::API.request(
      :guilds_sid_webhooks,
      server_id,
      :get,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/webhooks",
      Authorization: token
    )
  end

  # Adds a member to a server with an OAuth2 Bearer token that has been granted `guilds.join`
  # https://discord.com/developers/docs/resources/guild#add-guild-member
  def add_member(token, server_id, user_id, access_token, nick = nil, roles = [], mute = false, deaf = false)
    Discordrb::API.request(
      :guilds_sid_members_uid,
      server_id,
      :put,
      "#{Discordrb::API.api_base}/guilds/#{server_id}/members/#{user_id}",
      { access_token: access_token, nick: nick, roles: roles, mute: mute, deaf: deaf }.to_json,
      content_type: :json,
      Authorization: token
    )
  end
end
