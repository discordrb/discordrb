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

  # Represents a light server which only has a fraction of the properties of any other server.
  class LightServer
  end
end
