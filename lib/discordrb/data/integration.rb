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

  # Server integration
  class Integration
    include IDObject

    # @return [String] the integration name
    attr_reader :name

    # @return [Server] the server the integration is linked to
    attr_reader :server

    # @return [User] the user the integration is linked to
    attr_reader :user

    # @return [Role, nil] the role that this integration uses for "subscribers"
    attr_reader :role

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
      @role = server.role(data['role_id']) || nil
      @emoticon = data['enable_emoticons']
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Integration name=#{@name} id=#{@id} type=#{@type} enabled=#{@enabled}>"
    end
  end
end
