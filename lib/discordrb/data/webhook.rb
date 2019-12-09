# frozen_string_literal: true

module Discordrb
  # A webhook on a server channel
  class Webhook
    include IDObject

    # @return [String] the webhook name.
    attr_reader :name

    # @return [Channel] the channel that the webhook is currently connected to.
    attr_reader :channel

    # @return [Server] the server that the webhook is currently connected to.
    attr_reader :server

    # @return [String, nil] the webhook's token, if this is an Incoming Webhook.
    attr_reader :token

    # @return [String] the webhook's avatar id.
    attr_reader :avatar

    # @return [Integer] the webhook's type (1: Incoming, 2: Channel Follower)
    attr_reader :type

    # Gets the user object of the creator of the webhook. May be limited to username, discriminator,
    # ID and avatar if the bot cannot reach the owner
    # @return [Member, User, nil] the user object of the owner or nil if the webhook was requested using the token.
    attr_reader :owner

    def initialize(data, bot)
      @bot = bot

      @name = data['name']
      @id = data['id'].to_i
      @channel = bot.channel(data['channel_id'])
      @server = @channel.server
      @token = data['token']
      @avatar = data['avatar']
      @type = data['type']

      # Will not exist if the data was requested through a webhook token
      return unless data['user']

      @owner = @server.member(data['user']['id'].to_i)
      return if @owner

      Discordrb::LOGGER.debug("Member with ID #{data['user']['id']} not cached (possibly left the server).")
      @owner = @bot.ensure_user(data['user'])
    end

    # Sets the webhook's avatar.
    # @param avatar [String, #read] The new avatar, in base64-encoded JPG format.
    def avatar=(avatar)
      update_webhook(avatar: avatarise(avatar))
    end

    # Deletes the webhook's avatar.
    def delete_avatar
      update_webhook(avatar: nil)
    end

    # Sets the webhook's channel
    # @param channel [Channel, String, Integer] The channel the webhook should use.
    def channel=(channel)
      update_webhook(channel_id: channel.resolve_id)
    end

    # Sets the webhook's name.
    # @param name [String] The webhook's new name.
    def name=(name)
      update_webhook(name: name)
    end

    # Updates the webhook if you need to edit more than 1 attribute.
    # @param data [Hash] the data to update.
    # @option data [String, #read, nil] :avatar The new avatar, in base64-encoded JPG format, or nil to delete the avatar.
    # @option data [Channel, String, Integer] :channel The channel the webhook should use.
    # @option data [String] :name The webhook's new name.
    # @option data [String] :reason The reason for the webhook changes.
    def update(data)
      # Only pass a value for avatar if the key is defined as sending nil will delete the
      data[:avatar] = avatarise(data[:avatar]) if data.key?(:avatar)
      data[:channel_id] = data[:channel].resolve_id
      data.delete(:channel)
      update_webhook(data)
    end

    # Deletes the webhook.
    # @param reason [String] The reason the invite is being deleted.
    def delete(reason = nil)
      if token?
        API::Webhook.token_delete_webhook(@token, @id, reason)
      else
        API::Webhook.delete_webhook(@bot.token, @id, reason)
      end
    end

    # Utility function to get a webhook's avatar URL.
    # @return [String] the URL to the avatar image
    def avatar_url
      return API::User.default_avatar unless @avatar

      API::User.avatar_url(@id, @avatar)
    end

    # The `inspect` method is overwritten to give more useful output.
    def inspect
      "<Webhook name=#{@name} id=#{@id}>"
    end

    # Utility function to know if the webhook was requested through a webhook token, rather than auth.
    # @return [true, false] whether the webhook was requested by token or not.
    def token?
      @owner.nil?
    end

    private

    def avatarise(avatar)
      if avatar.respond_to? :read
        "data:image/jpg;base64,#{Base64.strict_encode64(avatar.read)}"
      else
        avatar
      end
    end

    def update_internal(data)
      @name = data['name']
      @avatar_id = data['avatar']
      @channel = @bot.channel(data['channel_id'])
    end

    def update_webhook(new_data)
      reason = new_data.delete(:reason)
      data = JSON.parse(if token?
                          API::Webhook.token_update_webhook(@token, @id, new_data, reason)
                        else
                          API::Webhook.update_webhook(@bot.token, @id, new_data, reason)
                        end)
      # Only update cache if API call worked
      update_internal(data) if data['name']
    end
  end
end
