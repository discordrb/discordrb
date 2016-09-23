# API calls for Channel
module Discordrb::API::Channel
  module_function

  # Get a channel's data
  # https://discordapp.com/developers/docs/resources/channel#get-channel
  def resolve(token, channel_id)
    Discordrb::API.request(
      :channels_cid,
      :get,
      "#{Discordrb::API.api_base}/channels/#{channel_id}",
      Authorization: token
    )
  end

  # Update a channel's data
  # https://discordapp.com/developers/docs/resources/channel#modify-channel
  def update(token, channel_id, name, topic, position = 0)
    Discordrb::API.request(
      :channels_cid,
      :patch,
      "#{Discordrb::API.api_base}/channels/#{channel_id}",
      { name: name, position: position, topic: topic }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a channel
  # https://discordapp.com/developers/docs/resources/channel#deleteclose-channel
  def delete(token, channel_id)
    Discordrb::API.request(
      :channels_cid,
      :delete,
      "#{Discordrb::API.api_base}/channels/#{channel_id}",
      Authorization: token
    )
  end

  # Get a list of messages from a channel's history
  # https://discordapp.com/developers/docs/resources/channel#get-channel-messages
  def messages(token, channel_id, amount, before = nil, after = nil)
    Discordrb::API.request(
      :channels_cid_messages,
      :get,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/messages?limit=#{amount}#{"&before=#{before}" if before}#{"&after=#{after}" if after}",
      Authorization: token
    )
  end

  # Get a single message from a channel's history by id
  # https://discordapp.com/developers/docs/resources/channel#get-channel-message
  def message(token, channel_id, message_id)
    Discordrb::API.request(
      :channels_cid_messages_mid,
      :get,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/messages/#{message_id}",
      Authorization: token
    )
  end

  # Send a message to a channel
  # https://discordapp.com/developers/docs/resources/channel#create-message
  def create_message(token, channel_id, message, mentions = [], tts = false, _server_id = nil) # send message
    Discordrb::API.request(
      :channels_cid_messages_mid,
      :post,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/messages",
      { content: message, mentions: mentions, tts: tts }.to_json,
      Authorization: token,
      content_type: :json
    )
  rescue RestClient::InternalServerError
    raise Discordrb::Errors::MessageTooLong, "Message over the character limit (#{message.length} > 2000)"
  end

  # Send a file as a message to a channel
  # https://discordapp.com/developers/docs/resources/channel#upload-file
  def upload_file(token, channel_id, file, caption: nil, tts: false)
    Discordrb::API.request(
      :channels_cid_messages_mid,
      :post,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/messages",
      { file: file, content: caption, tts: tts },
      Authorization: token
    )
  end

  # Edit a message
  # https://discordapp.com/developers/docs/resources/channel#edit-message
  def edit_message(token, channel_id, message_id, message, mentions = [])
    Discordrb::API.request(
      :channels_cid_messages_mid,
      :patch,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/messages/#{message_id}",
      { content: message, mentions: mentions }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a message
  # https://discordapp.com/developers/docs/resources/channel#delete-message
  def delete_message(token, channel_id, message_id)
    Discordrb::API.request(
      :channels_cid_messages_mid,
      :delete,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/messages/#{message_id}",
      Authorization: token
    )
  end

  # Delete messages in bulk
  # https://discordapp.com/developers/docs/resources/channel#bulk-delete-messages
  def bulk_delete_messages(token, channel_id, messages = [])
    Discordrb::API.request(
      :channels_cid_messages_bulk_delete,
      :post,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/messages/bulk_delete",
      { messages: messages }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Update a channels permission for a role or member
  # https://discordapp.com/developers/docs/resources/channel#edit-channel-permissions
  def update_permission(token, channel_id, overwrite_id, allow, deny, type)
    Discordrb::API.request(
      :channels_cid_permissions_oid,
      :put,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/permissions/#{role_id}",
      { type: type, id: overwrite_id, allow: allow, deny: deny }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get a channel's invite list
  # https://discordapp.com/developers/docs/resources/channel#get-channel-invites
  def invites(token, channel_id)
    Discordrb::API.request(
      :channels_cid_invites,
      :get,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/invites",
      Authorization: token
    )
  end

  # Create an instant invite from a server or a channel id
  # https://discordapp.com/developers/docs/resources/channel#create-channel-invite
  def create_invite(token, channel_id, max_age = 0, max_uses = 0, temporary = false)
    Discordrb::API.request(
      :channels_cid_invites,
      :post,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/invites",
      { max_age: max_age, max_uses: max_uses, temporary: temporary }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete channel permission
  # https://discordapp.com/developers/docs/resources/channel#delete-channel-permission
  def delete_permission(token, channel_id, overwrite_id)
    Discordrb::API.request(
      :channels_cid_permissions_oid,
      :delete,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/permissions/#{overwrite_id}",
      Authorization: token
    )
  end

  # Start typing (needs to be resent every 5 seconds to keep up the typing)
  # https://discordapp.com/developers/docs/resources/channel#trigger-typing-indicator
  def start_typing(token, channel_id)
    Discordrb::API.request(
      :channels_cid_typing,
      :post,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/typing",
      nil,
      Authorization: token
    )
  end

  # Get a list of pinned messages in a channel
  # https://discordapp.com/developers/docs/resources/channel#get-pinned-messages
  def pinned_messages(token, channel_id)
    Discordrb::API.request(
      :channels_cid_pins,
      :get,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/pins",
      Authorization: token
    )
  end

  # Pin a message
  # https://discordapp.com/developers/docs/resources/channel#add-pinned-channel-message
  def pin_message(token, channel_id, message_id)
    Discordrb::API.request(
      :channels_cid_pins_mid,
      :put,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/pins/#{message_id}",
      nil,
      Authorization: token
    )
  end

  # Unpin a message
  # https://discordapp.com/developers/docs/resources/channel#delete-pinned-channel-message
  def unpin_message(token, channel_id, message_id)
    Discordrb::API.request(
      :channels_cid_pins_mid,
      :delete,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/pins/#{message_id}",
      Authorization: token
    )
  end

  # Update a user's permission overrides in a channel
  def update_user_overrides(token, channel_id, user_id, allow, deny)
    update_permission(token, channel_id, user_id, allow, deny, 'member')
  end

  # Update a role's permission overrides in a channel
  def update_role_overrides(token, channel_id, role_id, allow, deny)
    update_permission(token, channel_id, role_id, allow, deny, 'role')
  end
end
