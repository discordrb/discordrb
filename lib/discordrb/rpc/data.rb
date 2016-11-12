require 'json'

require 'discordrb/data'

# Support for Discord's RPC protocol
module Discordrb::RPC
  # Represents a user as sent over RPC.
  class RPCUser
    include Discordrb::IDObject
    include Discordrb::UserAttributes

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @username = data['username']
      @id = data['id'].to_i
      @discriminator = data['discriminator']
      @avatar_id = data['avatar']

      @bot_account = false
      @bot_account = true if data['bot']
    end
  end

  # Represents a server as sent over RPC, without member data (i.e. only ID,
  # name, and icon URL).
  class RPCLightServer
    include Discordrb::IDObject
    include Discordrb::ServerAttributes

    # @return [String, nil] the URL to the server icon image, or nil if none exists.
    attr_reader :icon_url

    # @!visibility private
    def initialize(data)
      @id = data['id'].to_i
      @name = data['name']

      return unless data['icon_url']

      @icon_id = data['icon_url'].scan(/[0-9a-f]{32}/).first
      @icon_url = data['icon_url']
    end
  end

  # Represents a server as sent over RPC.
  class RPCServer < RPCLightServer
  end
end
