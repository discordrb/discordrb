# These classes hold relevant Discord data, such as messages or channels.

module Discordrb
  class User
    attr_reader :username, :id, :discriminator, :avatar
    alias_method :name, :username

    def initialize(data, bot)
      @bot = bot
      @username = data['username']
      @id = data['id'].to_i
      @discriminator = data['discriminator']
      @avatar = data['avatar']
    end

    # Utility function to mention users in messages
    def mention
      "<@#{@id}>"
    end
  end

  class Channel
    attr_reader :name, :server_id, :type, :id, :is_private

    def initialize(data, bot)
      @bot = bot
      @name = data['name']
      @server_id = data['guild_id']
      @type = data['type']
      @id = data['id']
      @is_private = data['is_private']
    end

    def send_message(content)
      @bot.send_message(@id, content)
    end

    alias_method :send, :send_message
    alias_method :message, :send_message
  end

  class Message
    attr_reader :content, :author, :channel, :timestamp, :id, :mentions
    alias_method :user, :author
    alias_method :text, :content

    def initialize(data, bot)
      @bot = bot
      @content = data['content']
      @author = User.new(data['author'], bot)
      @channel = bot.channel(data['channel_id'].to_i)
      @timestamp = Time.at(data['timestamp'].to_i)
      @id = data['id'].to_i

      @mentions = []

      data['mentions'].each do |element|
        @mentions << User.new(element, bot)
      end
    end
  end

  class Server
    attr_reader :region, :name, :owner_id, :id, :members

    def initialize(data, bot)
      @bot = bot
      @region = data['region']
      @name = data['name']
      @owner_id = data['owner_id'].to_i
      @id = data['id'].to_i

      @members = []

      data['members'].each do |element|
        @members << User.new(element, bot)
      end
    end
  end
end
