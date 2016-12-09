# API calls for Channel
module Discordrb::API::Channel
  module_function

  # Get a channel's data
  # https://discordapp.com/developers/docs/resources/channel#get-channel
  def resolve(token, channel_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}", :channels_cid, :get)
  end

  # Update a channel's data
  # https://discordapp.com/developers/docs/resources/channel#modify-channel
  def update(token, channel_id, data)
    Discordrb::API.generic_request(
      token, channel_id, "channels/#{channel_id}", :channels_cid, :patch,
      data.to_json
    )
  end

  # Delete a channel
  # https://discordapp.com/developers/docs/resources/channel#deleteclose-channel
  def delete(token, channel_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}", :channels_cid, :delete)
  end

  # Get a list of messages from a channel's history
  # https://discordapp.com/developers/docs/resources/channel#get-channel-messages
  def messages(token, channel_id, amount, before = nil, after = nil)
    Discordrb::API.generic_request(
      token, channel_id,
      "/#{channel_id}/messages?limit=#{amount}#{"&before=#{before}" if before}#{"&after=#{after}" if after}",
      :channels_cid_messages, :get
    )
  end

  # Get a single message from a channel's history by id
  # https://discordapp.com/developers/docs/resources/channel#get-channel-message
  def message(token, channel_id, message_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/messages/#{message_id}", :channels_cid_messages_mid, :get)
  end

  # Send a message to a channel
  # https://discordapp.com/developers/docs/resources/channel#create-message
  def create_message(token, channel_id, message, mentions = [], tts = false, embed = nil) # send message
    Discordrb::API.generic_request(
      token, channel_id, "channels/#{channel_id}/messages", :channels_cid_messages_mid, :post,
      { content: message, mentions: mentions, tts: tts, embed: embed }.to_json
    )
  rescue RestClient::BadRequest => e
    parsed = JSON.parse(e.response.body)
    raise Discordrb::Errors::MessageTooLong, "Message over the character limit (#{message.length} > 2000)" if parsed['content'] && parsed['content'].is_a?(Array) && parsed['content'].first == 'Must be 2000 or less characters long.'
    raise
  end

  # Send a file as a message to a channel
  # https://discordapp.com/developers/docs/resources/channel#upload-file
  def upload_file(token, channel_id, file, caption: nil, tts: false)
    Discordrb::API.request(
      :channels_cid_messages_mid,
      channel_id,
      :post,
      "#{Discordrb::API.api_base}/channels/#{channel_id}/messages",
      { file: file, content: caption, tts: tts },
      Authorization: token
    )
  end

  # Edit a message
  # https://discordapp.com/developers/docs/resources/channel#edit-message
  def edit_message(token, channel_id, message_id, message, mentions = [], embed = nil)
    Discordrb::API.generic_request(
      token, channel_id, "channels/#{channel_id}/messages/#{message_id}", :channels_cid_messages_mid, :patch,
      { content: message, mentions: mentions, embed: embed }.to_json
    )
  end

  # Delete a message
  # https://discordapp.com/developers/docs/resources/channel#delete-message
  def delete_message(token, channel_id, message_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/messages/#{message_id}", :channels_cid_messages_mid, :delete)
  end

  # Delete messages in bulk
  # https://discordapp.com/developers/docs/resources/channel#bulk-delete-messages
  def bulk_delete_messages(token, channel_id, messages = [])
    Discordrb::API.create(
      token, channel_id, "channels/#{channel_id}/messages/bulk_delete", :channels_cid_messages_bulk_delete,
      { messages: messages }.to_json
    )
  end

  # Create a reaction on a message using this client
  # https://discordapp.com/developers/docs/resources/channel#create-reaction
  def create_reaction(token, channel_id, message_id, emoji)
    emoji = URI.encode(emoji) unless emoji.ascii_only?
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/@me", :channels_cid_messages_mid_reactions_emoji_me, :put, nil)
  end

  # Delete this client's own reaction on a message
  # https://discordapp.com/developers/docs/resources/channel#delete-own-reaction
  def delete_own_reaction(token, channel_id, message_id, emoji)
    emoji = URI.encode(emoji) unless emoji.ascii_only?
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/@me", :channels_cid_messages_mid_reactions_emoji_me, :delete)
  end

  # Delete another client's reaction on a message
  # https://discordapp.com/developers/docs/resources/channel#delete-user-reaction
  def delete_user_reaction(token, channel_id, message_id, emoji, user_id)
    emoji = URI.encode(emoji) unless emoji.ascii_only?
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/#{user_id}", :channels_cid_messages_mid_reactions_emoji_uid, :delete)
  end

  # Get a list of clients who reacted with a specific reaction on a message
  # https://discordapp.com/developers/docs/resources/channel#get-reactions
  def get_reactions(token, channel_id, message_id, emoji)
    emoji = URI.encode(emoji) unless emoji.ascii_only?
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}", :channels_cid_messages_mid_reactions_emoji, :get)
  end

  # Deletes all reactions on a message from all clients
  # https://discordapp.com/developers/docs/resources/channel#delete-all-reactions
  def delete_all_reactions(token, channel_id, message_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/messages/#{message_id}/reactions", :channels_cid_messages_mid_reactions, :delete)
  end

  # Update a channels permission for a role or member
  # https://discordapp.com/developers/docs/resources/channel#edit-channel-permissions
  def update_permission(token, channel_id, overwrite_id, allow, deny, type)
    Discordrb::API.generic_request(
      token, channel_id, "channels/#{channel_id}/permissions/#{overwrite_id}", :channels_cid_permissions_oid, :put,
      { type: type, id: overwrite_id, allow: allow, deny: deny }.to_json
    )
  end

  # Get a channel's invite list
  # https://discordapp.com/developers/docs/resources/channel#get-channel-invites
  def invites(token, channel_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/invites", :channels_cid_invites, :get)
  end

  # Create an instant invite from a server or a channel id
  # https://discordapp.com/developers/docs/resources/channel#create-channel-invite
  def create_invite(token, channel_id, max_age = 0, max_uses = 0, temporary = false)
    Discordrb::API.generic_request(
      token, channel_id, "channels/#{channel_id}/invites", :channels_cid_invites, :post,
      { max_age: max_age, max_uses: max_uses, temporary: temporary }.to_json
    )
  end

  # Delete channel permission
  # https://discordapp.com/developers/docs/resources/channel#delete-channel-permission
  def delete_permission(token, channel_id, overwrite_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/permissions/#{overwrite_id}", :channels_cid_permissions_oid, :delete)
  end

  # Start typing (needs to be resent every 5 seconds to keep up the typing)
  # https://discordapp.com/developers/docs/resources/channel#trigger-typing-indicator
  def start_typing(token, channel_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/typing", :channels_cid_typing, :post, nil)
  end

  # Get a list of pinned messages in a channel
  # https://discordapp.com/developers/docs/resources/channel#get-pinned-messages
  def pinned_messages(token, channel_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/pins", :channels_cid_pins, :get)
  end

  # Pin a message
  # https://discordapp.com/developers/docs/resources/channel#add-pinned-channel-message
  def pin_message(token, channel_id, message_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/pins/#{message_id}", :channels_cid_pins_mid, :put, nil)
  end

  # Unpin a message
  # https://discordapp.com/developers/docs/resources/channel#delete-pinned-channel-message
  def unpin_message(token, channel_id, message_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/pins/#{message_id}", :channels_cid_pins_mid, :delete)
  end

  # Create an empty group channel.
  def create_empty_group(token, bot_user_id)
    Discordrb::API.generic_request(token, bot_user_id, "users/#{bot_user_id}/channels", :users_uid_channels, :post, '{}')
  end

  # Create a group channel.
  def create_group(token, channel_id, user_id)
    Discordrb::API.put(token, channel_id, "channels/#{channel_id}/recipients/#{user_id}", :channels_cid_recipients_uid, '{}')
  rescue RestClient::InternalServerError
    raise 'Attempted to add self as a new group channel recipient!'
  rescue RestClient::NoContent
    raise 'Attempted to create a group channel with the PM channel recipient!'
  rescue RestClient::Forbidden
    raise 'Attempted to add a user to group channel without permission!'
  end

  # Add a user to a group channel.
  def add_group_user(token, channel_id, user_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/recipients/#{user_id}", :channels_cid_recipients_uid, :put, '{}')
  end

  # Remove a user from a group channel.
  def remove_group_user(token, channel_id, user_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}/recipients/#{user_id}", :channels_cid_recipients_uid, :delete)
  end

  # Leave a group channel.
  def leave_group(token, channel_id)
    Discordrb::API.generic_request(token, channel_id, "channels/#{channel_id}", :channels_cid, :delete)
  end
end
