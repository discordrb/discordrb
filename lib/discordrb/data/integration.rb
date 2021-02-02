# frozen_string_literal: true

module Discordrb
  # Integration Account
  class IntegrationAccount
    # @return [String] this account's name.
    attr_reader :name

    # @return [Integer] this account's ID.
    attr_reader :id

    def initialize(data)
      @name = data['name']
      @id = data['id'].to_i
    end
  end

  # Bot/OAuth2 application for discord integrations
  class IntegrationApplication
    # @return [Integer] the ID of the application.
    attr_reader :id

    # @return [String] the name of the application.
    attr_reader :name

    # @return [String, nil] the icon hash of the application.
    attr_reader :icon

    # @return [String] the description of the application.
    attr_reader :description

    # @return [String] the summary of the application.
    attr_reader :summary

    # @return [User, nil] the bot associated with this application.
    attr_reader :bot

    def initialize(data, bot)
      @id = data['id'].to_i
      @name = data['name']
      @icon = data['icon']
      @description = data['description']
      @summary = data['summary']
      @bot = Discordrb::User.new(data['user'], bot) if data['user']
    end
  end

  # Server integration
  class Integration
    include IDObject

    # @return [String] the integration name
    attr_reader :name

    # @return [Server] the server the integration is linked to
    attr_reader :server

    # @return [User] the user the integration is linked to
    attr_reader :user

    # @return [Integer, nil] the role that this integration uses for "subscribers"
    attr_reader :role_id

    # @return [true, false] whether emoticons are enabled
    attr_reader :emoticon
    alias_method :emoticon?, :emoticon

    # @return [String] the integration type (YouTube, Twitch, etc.)
    attr_reader :type

    # @return [true, false] whether the integration is enabled
    attr_reader :enabled

    # @return [true, false] whether the integration is syncing
    attr_reader :syncing

    # @return [IntegrationAccount] the integration account information
    attr_reader :account

    # @return [Time] the time the integration was synced at
    attr_reader :synced_at

    # @return [Symbol] the behaviour of expiring subscribers (:remove = Remove User from role; :kick = Kick User from server)
    attr_reader :expire_behaviour
    alias_method :expire_behavior, :expire_behaviour

    # @return [Integer] the grace period before subscribers expire (in days)
    attr_reader :expire_grace_period

    # @return [Integer, nil] how many subscribers this integration has.
    attr_reader :subscriber_count

    # @return [true, false] has this integration been revoked.
    attr_reader :revoked

    def initialize(data, bot, server)
      @bot = bot

      @name = data['name']
      @server = server
      @id = data['id'].to_i
      @enabled = data['enabled']
      @syncing = data['syncing']
      @type = data['type']
      @account = IntegrationAccount.new(data['account'])
      @synced_at = Time.parse(data['synced_at'])
      @expire_behaviour = %i[remove kick][data['expire_behavior']]
      @expire_grace_period = data['expire_grace_period']
      @user = @bot.ensure_user(data['user'])
      @role_id = data['role_id']&.to_i
      @emoticon = data['enable_emoticons']
      @subscriber_count = data['subscriber_count']&.to_i
      @revoked = data['revoked']
      @application = IntegrationApplication.new(data['application'], bot) if data['application']
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Integration name=#{@name} id=#{@id} type=#{@type} enabled=#{@enabled}>"
    end
  end
end
