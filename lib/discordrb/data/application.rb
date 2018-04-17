# frozen_string_literal: true

module Discordrb
  # OAuth Application information
  class Application
    include IDObject

    # @return [String] the application name
    attr_reader :name

    # @return [String] the application description
    attr_reader :description

    # @return [Array<String>] the application's origins permitted to use RPC
    attr_reader :rpc_origins

    # @return [Integer]
    attr_reader :flags

    # Gets the user object of the owner. May be limited to username, discriminator,
    # ID, and avatar if the bot cannot reach the owner.
    # @return [User] the user object of the owner
    attr_reader :owner

    def initialize(data, bot)
      @bot = bot

      @name = data['name']
      @id = data['id'].to_i
      @description = data['description']
      @icon_id = data['icon']
      @rpc_origins = data['rpc_origins']
      @flags = data['flags']
      @owner = @bot.ensure_user(data['owner'])
    end

    # Utility function to get a application's icon URL.
    # @return [String, nil] the URL of the icon image (nil if no image is set).
    def icon_url
      return nil if @icon_id.nil?

      API.app_icon_url(@id, @icon_id)
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Application name=#{@name} id=#{@id}>"
    end
  end
end
