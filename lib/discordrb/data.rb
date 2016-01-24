# These classes hold relevant Discord data, such as messages or channels.

require 'ostruct'
require 'discordrb/permissions'
require 'discordrb/api'
require 'discordrb/events/message'
require 'time'
require 'base64'

# Discordrb module
module Discordrb
  # Compares two objects based on IDs - either the objects' IDs are equal, or one object is equal to the other's ID.
  def self.id_compare(one_id, other)
    other.respond_to?(:id) ? (one_id == other.id) : (one_id == other)
  end

  # User on Discord, including internal data like discriminators
  class User
    # @!attribute [r] username
    #   @return [String] This user's username

    # @!attribute [r] id
    #   @return [Integer] This user's ID which uniquely identifies them across Discord.

    # @!attribute [r] discriminator
    #   @return [String] This user's discriminator which is used internally to identify users with identical usernames.

    # @!attribute [r] avatar_id
    #   @return [String] The ID of this user's current avatar, can be used to generate an avatar URL.
    #   @see #avatar_url

    # @!attribute [r] voice_channel
    #   @return [Channel, nil] The voice channel this user is on currently.

    # @!attribute [r] roles
    #   @return [Hash<Integer => Array<Role>>] The roles this user has, grouped by server ID.
    attr_reader :username, :id, :discriminator, :avatar_id, :voice_channel, :roles

    # @!attribute [r] status
    #   @return [Symbol] The current online status of the user (`:online`, `:offline` or `:idle`)

    # @!attribute [r] game
    #   @return [String, nil] The game the user is currently playing, or `nil` if none is being played.

    # @!attribute [r] self_mute
    #   @return [true, false] Whether or not the user is currently muted by the bot.
    attr_accessor :status, :game, :server_mute, :server_deaf, :self_mute, :self_deaf

    alias_method :name, :username

    def initialize(data, bot)
      @bot = bot

      @username = data['username']
      @id = data['id'].to_i
      @discriminator = data['discriminator']
      @avatar_id = data['avatar']
      @roles = {}

      @status = :offline
    end

    # ID based comparison
    def ==(other)
      Discordrb.id_compare(@id, other)
    end

    # Gets the user's avatar ID.
    # @deprecated Use {#avatar_id} instead.
    def avatar
      LOGGER.debug('Warning: Deprecated reader User.avatar was used! Use User.avatar_id (or User.avatar_url if you just want the URL) instead.', true)
      @avatar_id
    end

    # Utility function to mention users in messages
    # @return [String] The mention code in the form of <@id>
    def mention
      "<@#{@id}>"
    end

    # Utility function to get a user's avatar URL.
    # @return [String] The URL to the avatar image.
    def avatar_url
      API.avatar_url(@id, @avatar_id)
    end

    # @overload pm
    #   Creates a private message channel for this user or returns an existing one if it already exists
    #   @return [Channel] The PM channel to this user.
    # @overload pm(content)
    #   Sends a private to this user.
    #   @param content [String] The content to send.
    #   @return [Message] The message sent to this user.
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

    # Changes a user's voice channel.
    # @note For internal use only
    def move(to_channel)
      return if to_channel && to_channel.type != 'voice'
      @voice_channel = to_channel
    end

    # Adds a role to this user on the specified server.
    # @param server [Server] The server on which to add the role.
    # @param role [Role] The role to add.
    def add_role(server, role)
      user_roles = @roles[server.id] || []
      user_roles << role
      ids = user_roles.map(&:id)
      API.update_user_roles(@bot.token, server.id, @id, ids)
    end

    # Removes a role from this user on the specified server.
    # @param server [Server] The server on which to remove the role.
    # @param role [Role] The role to remove.
    def remove_role(server, role)
      user_roles = @roles[server.id] || []

      # If the given role has an ID (i.e. is a Role object), then check whether its ID is equal, otherwise check whether it's equal directly
      user_roles.delete_if { |e| e == role }
      ids = user_roles.map(&:id)
      API.update_user_roles(@bot.token, server.id, @id, ids)
    end

    # Set this user's roles in the cache
    # @note For internal use only
    def update_roles(server, roles)
      @roles ||= {}
      @roles[server.id] = roles
    end

    # Merge this user's roles with the roles from another instance of this user (from another server)
    # @note For internal use only
    def merge_roles(server, roles)
      @roles[server.id] = if @roles[server.id]
                            (@roles[server.id] + roles).uniq
                          else
                            roles
                          end
    end

    # Delete a specific server from the roles (in case a user leaves a server)
    # @note For internal use only
    def delete_roles(server_id)
      @roles.delete(server_id)
    end

    # Add an await for a message from this user. Specifically, this adds a global await for a MessageEvent with this
    # user's ID as a :from attribute.
    # @param key [Symbol] The key to identify this await.
    # @param attributes [Hash<Symbol => Object>] The additional attributes to add to this event.
    # @yield Is executed when the await is triggered.
    # @yieldparam event [Event] The event object that was triggered.
    # @return [Await] The await that was created.
    def await(key, attributes = {}, &block)
      @bot.add_await(key, Discordrb::Events::MessageEvent, { from: @id }.merge(attributes), &block)
    end

    # Is the user the bot?
    # @return [true, false] Whether this user is the bot
    def bot?
      @bot.bot_user.id == @id
    end

    # Determines whether this user has a specific permission on a server (and channel).
    # @param action [Symbol] The permission that should be checked. See also {Permissions::Flags} for a list.
    # @param server [Server] The server on which the permission should be checked.
    # @param channel [Channel, nil] If channel overrides should be checked too, this channel specifies where the overrides should be checked.
    # @return [true, false] Whether or not this user has the permission.
    def permission?(action, server, channel = nil)
      # For each role, check if
      #   (1) the channel explicitly allows or permits an action for the role and
      #   (2) if the user is allowed to do the action if the channel doesn't specify
      return false unless @roles[server.id]

      @roles[server.id].reduce(false) do |can_act, role|
        channel_allow = nil
        if channel && channel.permission_overwrites[role.id]
          allow = channel.permission_overwrites[role.id].allow
          deny = channel.permission_overwrites[role.id].deny
          if allow.instance_variable_get("@#{action}")
            channel_allow = true
          elsif deny.instance_variable_get("@#{action}")
            channel_allow = false
          end
          # If the channel has nothing to say on the matter, we can defer to the role itself
        end
        can_act = if channel_allow.nil?
                    role.permissions.instance_variable_get("@#{action}") || can_act
                  else
                    channel_allow
                  end
        can_act
      end
    end

    # Define methods for querying permissions
    Discordrb::Permissions::Flags.each_value do |flag|
      define_method "can_#{flag}?" do |server, channel = nil|
        permission? flag, server, channel
      end
    end
  end

  # A class that represents the bot user itself and has methods to change stuff
  class Profile < User
    def initialize(data, bot, email, password)
      super(data, bot)
      @email = email
      @password = password
    end

    def bot?
      true
    end

    def username=(username)
      update_server_data(username: username)
    end

    def email=(email)
      update_server_data(email: email)
    end

    def password=(password)
      update_server_data(new_password: password)
    end

    def avatar=(avatar)
      if avatar.is_a? File
        avatar_string = 'data:image/jpg;base64,'
        avatar_string += Base64.strict_encode64(avatar.read)
        update_server_data(avatar: avatar_string)
      else
        update_server_data(avatar: avatar)
      end
    end

    def update_data(new_data)
      @email = new_data[:email] || @email
      @password = new_data[:new_password] || @password
      @username = new_data[:username] || @username
      @avatar_id = new_data[:avatar_id] || @avatar_id
    end

    private

    def update_server_data(new_data)
      API.update_user(@bot.token,
                      new_data[:email] || @email,
                      @password,
                      new_data[:username] || @username,
                      new_data[:avatar_id] || @avatar_id,
                      new_data[:new_password] || nil)
      update_data(new_data)
    end
  end

  # A Discord role that contains permissions and applies to certain users
  class Role
    attr_reader :permissions, :name, :id, :hoist, :colour
    alias_method :color, :colour

    # Class that writes data for a Permissions object
    class RoleWriter
      def initialize(role, token)
        @role = role
        @token = token
      end

      def write(bits)
        @role.send(:packed=, bits, false)
      end
    end

    def initialize(data, bot, server = nil)
      @bot = bot
      @server = server
      @permissions = Permissions.new(data['permissions'], RoleWriter.new(self, @bot.token))
      @name = data['name']
      @id = data['id'].to_i
      @hoist = data['hoist']
      @colour = ColourRGB.new(data['color'])
    end

    # ID based comparison
    def ==(other)
      Discordrb.id_compare(@id, other)
    end

    def update_from(other)
      @permissions = other.permissions
      @name = other.name
      @hoist = other.hoist
      @colour = other.colour
    end

    def update_data(new_data)
      @name = new_data[:name] || new_data['name'] || @name
      @hoist = new_data['hoist'] unless new_data['hoist'].nil?
      @hoist = new_data[:hoist] unless new_data[:hoist].nil?
      @colour = new_data[:colour] || (new_data['color'] ? ColourRGB.new(new_data['color']) : @colour)
    end

    def name=(name)
      update_role_data(name: name)
    end

    def hoist=(hoist)
      update_role_data(hoist: hoist)
    end

    def colour=(colour)
      update_role_data(colour: colour)
    end

    alias_method :color=, :colour=

    def packed=(packed, update_perms = true)
      update_role_data(permissions: packed)
      @permissions.bits = packed if update_perms
    end

    def delete
      API.delete_role(@bot.token, @server.id, @id)
      @server.delete_role(@id)
    end

    private

    def update_role_data(new_data)
      API.update_role(@bot.token, @server.id, @id,
                      new_data[:name] || @name,
                      (new_data[:colour] || @colour).combined,
                      new_data[:hoist].nil? ? false : !@hoist.nil?,
                      new_data[:permissions] || @permissions.bits)
      update_data(new_data)
    end
  end

  # A Discord invite to a channel
  class Invite
    attr_reader :channel, :server, :uses, :inviter, :temporary, :revoked, :xkcd, :code
    alias_method :max_uses, :uses
    alias_method :user, :inviter

    alias_method :temporary?, :temporary
    alias_method :revoked?, :revoked
    alias_method :xkcd?, :xkcd

    def initialize(data, bot)
      @bot = bot

      @channel = Channel.new(data['channel'], bot)
      @server = Server.new(data['guild'], bot)
      @uses = data['uses']
      @inviter = data['inviter'] ? (@bot.user(data['inviter']['id'].to_i) || User.new(data['inviter'], bot)) : nil
      @temporary = data['temporary']
      @revoked = data['revoked']
      @xkcd = data['xkcdpass']

      @code = data['code']
    end

    def ==(other)
      other.respond_to?(:code) ? (@code == other.code) : (@code == other)
    end

    def delete
      API.delete_invite(@bot.token, @code)
    end
  end

  # A Discord channel, including data like the topic
  class Channel
    attr_reader :name, :server, :type, :id, :is_private, :recipient, :topic, :position, :permission_overwrites

    def private?
      @server.nil?
    end

    def initialize(data, bot, server = nil)
      @bot = bot

      # data is a sometimes a Hash and othertimes an array of Hashes, you only want the last one if it's an array
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
        @server ||= server
      end

      # Populate permission overwrites
      @permission_overwrites = {}
      return unless data['permission_overwrites']
      data['permission_overwrites'].each do |element|
        role_id = element['id'].to_i
        deny = Permissions.new(element['deny'])
        allow = Permissions.new(element['allow'])
        @permission_overwrites[role_id] = OpenStruct.new
        @permission_overwrites[role_id].deny = deny
        @permission_overwrites[role_id].allow = allow
      end
    end

    # ID based comparison
    def ==(other)
      Discordrb.id_compare(@id, other)
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
        @server.members.select { |u| u.status != :offline }
      else
        @server.members.select do |user|
          user.voice_channel.id == @id if user.voice_channel
        end
      end
    end

    def history(amount, before_id = nil, after_id = nil)
      logs = API.channel_log(@bot.token, @id, amount, before_id, after_id)
      JSON.parse(logs).map { |message| Message.new(message, @bot) }
    end

    def update_overwrites(overwrites)
      @permission_overwrites = overwrites
    end

    # Add an await for a message in this channel
    def await(key, attributes = {}, &block)
      @bot.add_await(key, Discordrb::Events::MessageEvent, { in: @id }.merge(attributes), &block)
    end

    def make_invite(max_age = 0, max_uses = 0, temporary = false, xkcd = false)
      response = API.create_invite(@bot.token, @id, max_age, max_uses, temporary, xkcd)
      Invite.new(JSON.parse(response), @bot)
    end

    # Starts typing, which displays the typing indicator on the client for five seconds.
    # If you want to keep typing you'll have to resend this every five seconds. (An abstraction
    # for this will eventually be coming)
    def start_typing
      API.start_typing(@bot.token, @id)
    end

    alias_method :send, :send_message
    alias_method :message, :send_message
    alias_method :invite, :make_invite

    private

    def update_channel_data
      API.update_channel(@bot.token, @id, @name, @topic, @position)
    end
  end

  # A message on Discord that was sent to a text channel
  class Message
    attr_reader :content, :author, :channel, :timestamp, :id, :mentions
    alias_method :user, :author
    alias_method :text, :content
    alias_method :to_s, :content

    def initialize(data, bot)
      @bot = bot
      @content = data['content']
      @author = bot.user(data['author']['id'].to_i)
      @channel = bot.channel(data['channel_id'].to_i)
      @timestamp = Time.parse(data['timestamp'])
      @id = data['id'].to_i

      @mentions = []

      data['mentions'].each do |element|
        @mentions << User.new(element, bot)
      end
    end

    # ID based comparison
    def ==(other)
      Discordrb.id_compare(@id, other)
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

    # Add an await for a message with the same user and channel
    def await(key, attributes = {}, &block)
      @bot.add_await(key, Discordrb::Events::MessageEvent, { from: @author.id, in: @channel.id }.merge(attributes), &block)
    end

    def from_bot?
      @author.bot?
    end
  end

  # A server on Discord
  class Server
    attr_reader :region, :name, :owner_id, :id, :members, :channels, :roles, :icon, :afk_timeout, :afk_channel_id

    def initialize(data, bot)
      @bot = bot
      @owner_id = data['owner_id'].to_i
      @id = data['id'].to_i
      update_data(data)

      process_roles(data['roles'])
      process_members(data['members'])
      process_presences(data['presences'])
      process_channels(data['channels'])
      process_voice_states(data['voice_states'])
    end

    # ID based comparison
    def ==(other)
      Discordrb.id_compare(@id, other)
    end

    # Gets a role on this server based on its ID.
    # @param id [Integer] The role ID to look for.
    def role(id)
      @roles.find { |e| e.id == id }
    end

    # Adds a role to the role cache
    # @note For internal use only
    def add_role(role)
      @roles << role
    end

    # Removes a role from the role cache
    # @note For internal use only
    def delete_role(role_id)
      @roles.reject! { |r| r.id == role_id }
      @members.each do |user|
        new_roles = user.roles[@id].reject { |r| r.id == role_id }
        user.update_roles(self, new_roles)
      end
      @channels.each do |channel|
        overwrites = channel.permission_overwrites.reject { |id, _| id == role_id }
        channel.update_overwrites(overwrites)
      end
    end

    # Adds a user to the user cache.
    # @note For internal use only
    def add_user(user)
      @members << user
    end

    # Removes a user from the user cache.
    # @note For internal use only
    def delete_user(user_id)
      @members.reject! { |member| member.id == user_id }
    end

    # Creates a channel on this server with the given name.
    # @return [Channel] The created channel.
    def create_channel(name)
      response = API.create_channel(@bot.token, @id, name, 'text')
      Channel.new(JSON.parse(response), @bot)
    end

    # Creates a role on this server which can then be modified. It will be initialized (on Discord's side)
    # with the regular role defaults the client uses, i. e. name is "new role", permissions are the default,
    # colour is the default etc.
    # @return [Role] The created role.
    def create_role
      response = API.create_role(@bot.token, @id)
      role = Role.new(JSON.parse(response), @bot)
      @roles << role
      role
    end

    # Bans a user from this server.
    # @param user [User] The user to ban.
    # @param message_days [Integer] How many days worth of messages sent by the user should be deleted.
    def ban(user, message_days = 0)
      API.ban_user(@bot.token, @id, user.id, message_days)
    end

    # Unbans a previously banned user from this server.
    # @param user [User] The user to unban.
    def unban(user)
      API.unban_user(@bot.token, @id, user.id)
    end

    # Kicks a user from this server.
    # @param user [User] The user to kick.
    def kick(user)
      API.kick_user(@bot.token, @id, user.id)
    end

    # Forcibly moves a user into a different voice channel. Only works if the bot has the permission needed.
    # @param user [User] The user to move.
    # @param channel [Channel] The voice channel to move into.
    def move(user, channel)
      API.move_user(@bot.token, @id, user.id, channel.id)
    end

    # Deletes this server. Be aware that this is permanent and impossible to undo, so be careful!
    def delete
      API.delete_server(@bot.token, @id)
    end

    # Leave the server - to Discord, leaving a server and deleting it are the same, so be careful if the bot
    # is the server owner!
    alias_method :leave, :delete

    # Transfers server ownership to another user.
    # @param user [User] The user who should become the new owner.
    def owner=(user)
      API.transfer_ownership(@bot.token, @id, user.id)
    end

    def name=(name)
      update_server_data(name: name)
    end

    def region=(region)
      update_server_data(region: region.to_s)
    end

    def icon=(icon)
      update_server_data(icon: icon)
    end

    def afk_channel=(afk_channel)
      update_server_data(afk_channel_id: afk_channel.id)
    end

    def afk_channel_id=(afk_channel_id)
      update_server_data(afk_channel_id: afk_channel_id)
    end

    def afk_timeout=(afk_timeout)
      update_server_data(afk_timeout: afk_timeout)
    end

    def update_data(new_data)
      @name = new_data[:name] || new_data['name'] || @name
      @region = new_data[:region] || new_data['region'] || @region
      @icon = new_data[:icon] || new_data['icon'] || @icon
      @afk_timeout = new_data[:afk_timeout] || new_data['afk_timeout'].to_i || @afk_timeout

      @afk_channel_id = new_data[:afk_channel_id] || new_data['afk_channel_id'].to_i || @afk_channel.id
      @afk_channel = @bot.channel(@afk_channel_id) if @afk_channel_id != 0 && (!@afk_channel || @afk_channel_id != @afk_channel.id)
    end

    private

    def update_server_data(new_data)
      API.update_server(@bot.token, @id,
                        new_data[:name] || @name,
                        new_data[:region] || @region,
                        new_data[:icon] || @icon,
                        new_data[:afk_channel_id] || @afk_channel_id,
                        new_data[:afk_timeout] || @afk_timeout)
      update_data(new_data)
    end

    def process_roles(roles)
      # Create roles
      @roles = []
      @roles_by_id = {}

      return unless roles
      roles.each do |element|
        role = Role.new(element, @bot, self)
        @roles << role
        @roles_by_id[role.id] = role
      end
    end

    def process_members(members)
      @members = []
      @members_by_id = {}

      return unless members
      members.each do |element|
        user = User.new(element['user'], @bot)
        @members << user
        @members_by_id[user.id] = user
        user_roles = []
        element['roles'].each do |e|
          role_id = e.to_i
          user_roles << @roles_by_id[role_id]
        end
        user.update_roles(self, user_roles)
      end
    end

    def process_presences(presences)
      # Update user statuses with presence info
      return unless presences
      presences.each do |element|
        next unless element['user']
        user_id = element['user']['id'].to_i
        user = @members_by_id[user_id]
        if user
          user.status = element['status'].to_sym
          user.game = element['game'] ? element['game']['name'] : nil
        end
      end
    end

    def process_channels(channels)
      @channels = []
      @channels_by_id = {}

      return unless channels
      channels.each do |element|
        channel = Channel.new(element, @bot, self)
        @channels << channel
        @channels_by_id[channel.id] = channel
      end
    end

    def process_voice_states(voice_states)
      return unless voice_states
      voice_states.each do |element|
        user_id = element['user_id'].to_i
        user = @members_by_id[user_id]
        next unless user
        user.server_mute = element['mute']
        user.server_deaf = element['deaf']
        user.self_mute = element['self_mute']
        user.self_mute = element['self_mute']
        channel_id = element['channel_id'].to_i
        channel = channel_id ? @channels_by_id[channel_id] : nil
        user.move(channel)
      end
    end
  end

  # A colour (red, green and blue values). Used for role colours
  class ColourRGB
    attr_reader :red, :green, :blue, :combined

    def initialize(combined)
      @combined = combined
      @red = (combined >> 16) & 0xFF
      @green = (combined >> 8) & 0xFF
      @blue = combined & 0xFF
    end
  end

  ColorRGB = ColourRGB
end
