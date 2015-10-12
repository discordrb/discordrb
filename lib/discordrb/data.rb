# These classes hold relevant Discord data, such as messages or channels.

module Discordrb
  class User
    attr_reader :username, :id, :discriminator, :avatar

    # Is the user online, offline, or away?
    attr_reader :status

    alias_method :name, :username

    def initialize(data, bot)
      @bot = bot

      @username = data['username']
      @id = data['id'].to_i
      @discriminator = data['discriminator']
      @avatar = data['avatar']
      
      @status = :offline
    end

    # Utility function to mention users in messages
    def mention
      "<@#{@id}>"
    end

    # Utility function to send a PM
    def pm(content = nil)
      if content
        # Recursively call pm to get the channel, then send a message to it
        channel = pm
        channel.send_message(content)
      else
        # If no message was specified, return the PM channel
        @bot.private_channel(@id)
      end
    end
  end

  class Channel
    attr_reader :name, :server, :type, :id, :is_private, :recipient, :topic

    def initialize(data, bot)
      @bot = bot

      #data is a sometimes a Hash and othertimes an array of Hashes, you only want the last one if it's an array
      data = data[-1] if data.is_a?(Array)

      @id = data['id'].to_i
      @type = data['type'] || 'text'
      @topic = data['topic']

      @is_private = data['is_private']
      if @is_private
        @recipient = User.new(data['recipient'], bot)
        @name = @recipient.username
      else
        @name = data['name']
        @server = bot.server(data['guild_id'].to_i)
      end
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

    # Array of channels on the server
    attr_reader :channels

    def initialize(data, bot)
      @bot = bot
      @region = data['region']
      @name = data['name']
      @owner_id = data['owner_id'].to_i
      @id = data['id'].to_i

      @members = []
      members_by_id = {}

      data['members'].each do |element|
        user = User.new(element['user'], bot)
        @members << user
        members_by_id[user.id] = user
      end

      # Update user statuses with presence info
      if data['presences']
        data['presences'].each do |element|
          if element['user']
            user = members_by_id[element['user']['id'].to_i]
            if user && element['status']
              # I don't want to make User#status writable, so we'll use
              # instance_exec to open the object and set the status
              user.instance_exec(element['status']) do |status|
                @status = status.to_sym
              end
            end
          end
        end
      end

      @channels = []

      if data['channels']
        data['channels'].each do |element|
          @channels << Channel.new(element, bot)
        end
      end
    end
  end
end
