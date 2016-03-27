module Discordrb::Light
  # A connection of your Discord account to a particular other service (currently, Twitch and YouTube)
  class Connection
    # @return [Symbol] what type of connection this is (either :twitch or :youtube currently)
    attr_reader :type

    # @return [true, false] whether this connection is revoked
    attr_reader :revoked
    alias_method :revoked?, :revoked

    # @return [String] the name of the connected account
    attr_reader :name

    # @return [String] the ID of the connected account
    attr_reader :id

    # @return [Array<Integration>] the integrations associated with this connection
    attr_reader :integrations

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @revoked = data['revoked']
      @type = data['type']
      @name = data['name']
      @id = data['id']
    end
  end

  # An integration of a connection into a particular server, for example being a member of a subscriber-only Twitch
  # server.
  class Integration
  end
end
