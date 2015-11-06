# These classes hold relevant Discord data, such as messages or channels.

require 'ostruct'
require 'discordrb/permissions'
require 'discordrb/api'
require 'discordrb/games'

module Discordrb
  class User
    attr_reader :username, :id, :discriminator, :avatar

    attr_accessor :status
    attr_accessor :game
    attr_accessor :server_mute
    attr_accessor :server_deaf
    attr_accessor :self_mute
    attr_accessor :self_deaf
    attr_reader :voice_channel

    # Hash of user roles.
    # Key: Server ID
    # Value: Array of roles.
    attr_reader :roles

    alias_method :name, :username

    def initialize(data, bot)
      @bot = bot

      @username = data['username']
      @id = data['id'].to_i
      @discriminator = data['discriminator']
      @avatar = data['avatar']
      @roles = {}

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

    # Set this user's roles
    def update_roles(server, roles)
      @roles[server.id] = roles
    end

    # Merge this user's roles with the roles from another instance of this user (from another server)
    def merge_roles(server, roles)
      if @roles[server.id]
        @roles[server.id] = (@roles[server.id] + roles).uniq
      else
        @roles[server.id] = roles
      end
    end

    # Determine if the user has permission to do an action
    # action is a permission from Permissions::Flags.
    # channel is the channel in which the action takes place (not applicable for server-wide actions).
    def has_permission?(action, server, channel = nil)
      # For each role, check if
      #   (1) the channel explicitly allows or permits an action for the role and
      #   (2) if the user is allowed to do the action if the channel doesn't specify
      return false if !@roles[server.id]

      @roles[server.id].reduce(false) do |can_act, role|
        channel_allow = nil
        if channel && channel.permission_overwrites[role.id]
          allow = channel.permission_overwrites[role.id].allow
          deny = channel.permission_overwrites[role.id].deny
          if allow.instance_variable_get("@#{action}")
            channel_allow = true
          elsif deny.instance_variable_get("@#{action}")
            channel_allow = false
          # else
          #   If the channel has nothing to say on the matter, we can defer to the role itself
          end
        end
        if channel_allow == false
          can_act = can_act || false
        elsif channel_allow == true
          can_act = true
        else # channel_allow == nil
          can_act = role.permissions.instance_variable_get("@#{action}") || can_act
        end
      end
    end

    # Define methods for querying permissions
    Discordrb::Permissions::Flags.each_value do |flag|
      define_method "can_#{flag}?" do |server, channel = nil|
        has_permission? flag, server, channel
      end
    end
  end

  class Role
    attr_reader :permissions
    attr_reader :name
    attr_reader :id
    attr_reader :hoist
    attr_reader :color

    def initialize(data, bot, server = nil)
      @permissions = Permissions.new(data['permissions'])
      @name = data['name']
      @id = data['id'].to_i
      @hoist = data['hoist']
      @color = ColorRGB.new(data['color'])
    end

    def update_from(other)
      @permissions = other.permissions
      @name = other.name
      @hoist = other.hoist
      @color = other.color
    end
  end

  class Channel
    attr_reader :name, :server, :type, :id, :is_private, :recipient, :topic, :position

    attr_reader :permission_overwrites

    def initialize(data, bot, server = nil)
      @bot = bot

      #data is a sometimes a Hash and othertimes an array of Hashes, you only want the last one if it's an array
      data = data[-1] if data.is_a?(Array)

      @id = data['id'].to_i
      @type = data['type'] || 'text'
      @topic = data['topic']
      @position = data['position']

      @is_private = data['is_private']
      if @is_private
        @recipient = User.new(data['recipient'], bot)
        @name = @recipient.username
      else
        @name = data['name']
        @server = bot.server(data['guild_id'].to_i)
        @server = server if !@server
      end

      # Populate permission overwrites
      @permission_overwrites = {}
      if data['permission_overwrites']
        data['permission_overwrites'].each do |element|
          role_id = element['id'].to_i
          deny = Permissions.new(element['deny'])
          allow = Permissions.new(element['allow'])
          @permission_overwrites[role_id] = OpenStruct.new
          @permission_overwrites[role_id].deny = deny
          @permission_overwrites[role_id].allow = allow
        end
      end
    end

    def send_message(content)
      @bot.send_message(@id, content)
    end

    def send_file(file)
      @bot.send_file(@id, file)
    end

    def delete
      API.delete_channel(@bot.token, @id)
    end

    def name=(name)
      @name = name
      update_channel_data
    end

    def topic=(topic)
      @topic = topic
      update_channel_data
    end

    def position=(position)
      @position = position
      update_channel_data
    end

    def update_from(other)
      @topic = other.topic
      @name = other.name
      @is_private = other.is_private
      @recipient = other.recipient
      @permission_overwrites = other.permission_overwrites
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

    def update_overwrites(overwrites)
      @permission_overwrites = overwrites
    end

    alias_method :send, :send_message
    alias_method :message, :send_message

    private

    def update_channel_data
      API.update_channel(@bot.token, @id, @name, @topic, @position)
    end
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

    def reply(content)
      @channel.send_message(content)
    end

    def edit(new_content)
      API.edit_message(@bot.token, @channel.id, @id, new_content)
    end

    def delete
      API.delete_message(@bot.token, @channel.id, @id)
    end
  end

  class Server
    attr_reader :region, :name, :owner_id, :id, :members

    # Array of channels on the server
    attr_reader :channels

    # Array of roles on the server
    attr_reader :roles

    def initialize(data, bot)
      @bot = bot
      @region = data['region']
      @name = data['name']
      @owner_id = data['owner_id'].to_i
      @id = data['id'].to_i

      # Create roles
      @roles = []
      roles_by_id = {}
      data['roles'].each do |element|
        role = Role.new(element, bot)
        @roles << role
        roles_by_id[role.id] = role
      end

      @members = []
      members_by_id = {}

      data['members'].each do |element|
        user = User.new(element['user'], bot)
        @members << user
        members_by_id[user.id] = user
        user_roles = []
        element['roles'].each do |element|
          role_id = element.to_i
          user_roles << roles_by_id[role_id]
        end
        user.update_roles(self, user_roles)
      end

      # Update user statuses with presence info
      if data['presences']
        data['presences'].each do |element|
          if element['user']
            user_id = element['user']['id'].to_i
            user = members_by_id[user_id]
            if user
              user.status = element['status'].to_sym
              user.game = Discordrb::Games.find_game(element['game_id'])
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

    def add_role(role)
      @roles << role
    end

    def delete_role(role_id)
      @roles.reject! {|r| r.id == role_id}
      @members.each do |user|
        new_roles = user.roles.reject {|r| r.id == role_id}
        user.update_roles(self, new_roles)
      end
      @channels.each do |channel|
        overwrites = channel.permission_overwrites.reject {|id, perm| id == role_id}
        channel.update_overwrites(overwrites)
      end
    end

    def create_channel(name)
      response = API.create_channel(@bot.token, @id, name, 'text')
      Channel.new(JSON.parse(response), @bot)
    end
  end

  class ColorRGB
    attr_reader :red, :green, :blue

    def initialize(combined)
      @red = (combined >> 16) & 0xFF
      @green = (combined >> 8) & 0xFF
      @blue = combined & 0xFF
    end
  end
end
