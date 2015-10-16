# These classes hold relevant Discord data, such as messages or channels.

module Discordrb
  class User
    attr_reader :username, :id, :discriminator, :avatar
    
    attr_accessor :status
    attr_accessor :game_id
    attr_accessor :server_mute
    attr_accessor :server_deaf
    attr_accessor :self_mute
    attr_accessor :self_deaf
    attr_reader :voice_channel

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
    
    # Move a user into a voice channel
    def move(to_channel)
      return if to_channel && to_channel.type != 'voice'
      @voice_channel = to_channel
    end
  end

  class Channel
    attr_reader :name, :server, :type, :id, :is_private, :recipient, :topic

    def initialize(data, bot, server = nil)
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
        @server = server if !@server
      end
    end

    def send_message(content)
      @bot.send_message(@id, content)
    end
    
    def update_from(other)
      @topic = other.topic
      @name = other.name
      @is_private = other.is_private
      @recipient = other.recipient
    end
    
    # List of users currently in a channel
    def users
      if @type == 'text'
        @server.members.select {|u| u.status != :offline }
      else
        @server.members.select do |user|
          if user.voice_channel
            user.voice_channel.id == @id
          end
        end
      end
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
            user_id = element['user']['id'].to_i
            user = members_by_id[user_id]
            if user
              user.status = element['status'].to_sym
              user.game_id = element['game_id']
            end
          end
        end
      end
      
      @channels = []
      channels_by_id = {}

      if data['channels']
        data['channels'].each do |element|
          channel = Channel.new(element, bot, self)
          @channels << channel
          channels_by_id[channel.id] = channel
        end
      end
      
      if data['voice_states']
        data['voice_states'].each do |element|
          user_id = element['user_id'].to_i
          user = members_by_id[user_id]
          if user
            user.server_mute = element['mute']
            user.server_deaf = element['deaf']
            user.self_mute = element['self_mute']
            user.self_mute = element['self_mute']
            channel_id = element['channel_id']
            channel = nil
            if channel_id
              channel = channels_by_id[channel_id]
            end
            user.move(channel)
          end
        end
      end
    end
  end
end
