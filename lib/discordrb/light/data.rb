# frozen_string_literal: true

require 'discordrb/data'

module Discordrb::Light
  # Represents the bot account used for the light bot, but without any methods to change anything.
  class LightProfile
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

      @verified = data['verified']

      @email = data['email']
    end
  end

  # A server that only has an icon, a name, and an ID associated with it, like for example an integration's server.
  class UltraLightServer
    include Discordrb::IDObject
    include Discordrb::ServerAttributes

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @id = data['id'].to_i

      @name = data['name']
      @icon_id = data['icon']
    end
  end

  # Represents a light server which only has a fraction of the properties of any other server.
  class LightServer < UltraLightServer
    # @return [true, false] whether or not the LightBot this server belongs to is the owner of the server.
    attr_reader :bot_is_owner
    alias_method :bot_is_owner?, :bot_is_owner

    # @return [Discordrb::Permissions] the permissions the LightBot has on this server
    attr_reader :bot_permissions

    # @!visibility private
    def initialize(data, bot)
      super(data, bot)

      @bot_is_owner = data['owner']
      @bot_permissions = Discordrb::Permissions.new(data['permissions'])
    end
  end

  # A channel that only as  name, type, parent server ID, and channel ID associated with it.
  class UltraLightChannel
    include Discordrb::IDObject
    include Discordrb::ChannelAttributes

    def initialize(data, bot)
      @bot = bot

      @id = data['id'].to_i
      @server_id = data['guild_id'].to_i

      @name = data['name']
      @type = data['type']
    end
  end

  # Represents a light channel which only has a fraction of the properties of any other channel.
  class LightChannel < UltraLightChannel
    # @return [Discordrb::Permissions] the specific overrides for the user in this channel
    attr_reader :permission_overwrites

    # @return [true, false] whether or not this channel is the server's default (usually "#general") channel.
    def default_channel
      @id == @server_id
    end
    alias_method :default_channel?, :default_channel

    # @!visibility private
    def initialize(data, bot)
      super(data, bot)

      @bot_permissions = Discordrb::Permissions.new(data['permission_overwrites'])
    end
  end
end
