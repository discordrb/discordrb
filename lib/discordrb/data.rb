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
    other.respond_to?(:resolve_id) ? (one_id.resolve_id == other.resolve_id) : (one_id == other)
  end

  # User on Discord, including internal data like discriminators
  class User
    # @return [String] this user's username
    attr_reader :username

    # @return [Integer] this user's ID which uniquely identifies them across Discord.
    attr_reader :id

    # @return [String] this user's discriminator which is used internally to identify users with identical usernames.
    attr_reader :discriminator

    # @return [String] the ID of this user's current avatar, can be used to generate an avatar URL.
    # @see #avatar_url
    attr_reader :avatar_id

    # @return [Channel, nil] the voice channel this user is on currently.
    attr_reader :voice_channel

    # @return [Hash<Integer => Array<Role>>] the roles this user has, grouped by server ID.
    attr_reader :roles

    # @!attribute [r] status
    #   @return [Symbol] the current online status of the user (`:online`, `:offline` or `:idle`)
    attr_accessor :status

    # @!attribute [r] game
    #   @return [String, nil] the game the user is currently playing, or `nil` if none is being played.
    attr_accessor :game

    # @!attribute [r] self_mute
    #   @return [true, false] whether or not the user is currently muted by the bot.
    attr_accessor :self_mute

    # @todo Fix these (server_mute and _deaf should be server specific, not sure about self_deaf or what it does anyway)
    # @!visibility private
    attr_accessor :server_mute, :server_deaf, :self_deaf

    alias_method :name, :username
    alias_method :resolve_id, :id

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
    # @return [String] the mention code in the form of <@id>
    def mention
      "<@#{@id}>"
    end

    # Utility function to get a user's avatar URL.
    # @return [String] the URL to the avatar image.
    def avatar_url
      API.avatar_url(@id, @avatar_id)
    end

    # Get a user's PM channel or send them a PM
    # @overload pm
    #   Creates a private message channel for this user or returns an existing one if it already exists
    #   @return [Channel] the PM channel to this user.
    # @overload pm(content)
    #   Sends a private to this user.
    #   @param content [String] The content to send.
    #   @return [Message] the message sent to this user.
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
    # @!visibility private
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
    # @!visibility private
    def update_roles(server, roles)
      @roles ||= {}
      @roles[server.id] = roles
    end

    # Merge this user's roles with the roles from another instance of this user (from another server)
    # @note For internal use only
    # @!visibility private
    def merge_roles(server, roles)
      @roles[server.id] = if @roles[server.id]
                            (@roles[server.id] + roles).uniq
                          else
                            roles
                          end
    end

    # Delete a specific server from the roles (in case a user leaves a server)
    # @note For internal use only
    # @!visibility private
    def delete_roles(server_id)
      @roles.delete(server_id)
    end

    # Add an await for a message from this user. Specifically, this adds a global await for a MessageEvent with this
    # user's ID as a :from attribute.
    # @see Bot#add_await
    def await(key, attributes = {}, &block)
      @bot.add_await(key, Discordrb::Events::MessageEvent, { from: @id }.merge(attributes), &block)
    end

    # Is the user the bot?
    # @return [true, false] whether this user is the bot
    def bot?
      @bot.bot_user.id == @id
    end

    # Determines whether this user has a specific permission on a server (and channel).
    # @param action [Symbol] The permission that should be checked. See also {Permissions::Flags} for a list.
    # @param server [Server] The server on which the permission should be checked.
    # @param channel [Channel, nil] If channel overrides should be checked too, this channel specifies where the overrides should be checked.
    # @return [true, false] whether or not this user has the permission.
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

  # This class is a special variant of User that represents the bot's user profile (things like email addresses and the avatar).
  # It can be accessed using {Bot#profile}.
  class Profile < User
    def initialize(data, bot, email, password)
      super(data, bot)
      @email = email
      @password = password
    end

    # Whether or not the user is the bot. The Profile can only ever be the bot user, so this always returns true.
    # @return [true]
    def bot?
      true
    end

    # Sets the bot's username.
    # @param username [String] The new username.
    def username=(username)
      update_server_data(username: username)
    end

    # Sets the bot's email address. If you use this method, make sure that the login email in the script matches this
    # one afterwards, so the bot doesn't have any trouble logging in in the future.
    # @param email [String] The new email address.
    def email=(email)
      update_server_data(email: email)
    end

    # Changes the bot's password. This will invalidate all tokens so you will have to relog the bot.
    # @param password [String] The new password.
    def password=(password)
      update_server_data(new_password: password)
    end

    # Changes the bot's avatar.
    # @param avatar [String, File] A JPG file to be used as the avatar, either as a File object or as a base64-encoded String.
    def avatar=(avatar)
      if avatar.is_a? File
        avatar_string = 'data:image/jpg;base64,'
        avatar_string += Base64.strict_encode64(avatar.read)
        update_server_data(avatar: avatar_string)
      else
        update_server_data(avatar: avatar)
      end
    end

    # Updates the cached profile data with the new one.
    # @note For internal use only.
    # @!visibility private
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
    # @return [Permissions] this role's permissions.
    attr_reader :permissions

    # @return [String] this role's name ("new role" if it hasn't been changed)
    attr_reader :name

    # @return [Integer] the ID used to identify this role internally
    attr_reader :id

    # @return [true, false] whether or not this role should be displayed separately from other users
    attr_reader :hoist

    # @return [ColourRGB] the role colour
    attr_reader :colour

    alias_method :color, :colour
    alias_method :resolve_id, :id

    # This class is used internally as a wrapper to a Role object that allows easy writing of permission data.
    class RoleWriter
      # @!visibility private
      def initialize(role, token)
        @role = role
        @token = token
      end

      # Write the specified permission data to the role, without updating the permission cache
      # @param bits [Integer] The packed permissions to write.
      def write(bits)
        @role.send(:packed=, bits, false)
      end
    end

    # @!visibility private
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

    # Updates the data cache from another Role object
    # @note For internal use only
    # @!visibility private
    def update_from(other)
      @permissions = other.permissions
      @name = other.name
      @hoist = other.hoist
      @colour = other.colour
    end

    # Updates the data cache from a hash containing data
    # @note For internal use only
    # @!visibility private
    def update_data(new_data)
      @name = new_data[:name] || new_data['name'] || @name
      @hoist = new_data['hoist'] unless new_data['hoist'].nil?
      @hoist = new_data[:hoist] unless new_data[:hoist].nil?
      @colour = new_data[:colour] || (new_data['color'] ? ColourRGB.new(new_data['color']) : @colour)
    end

    # Sets the role name to something new
    # @param name [String] The name that should be set
    def name=(name)
      update_role_data(name: name)
    end

    # Changes whether or not this role is displayed at the top of the user list
    # @param hoist [true, false] The value it should be changed to
    def hoist=(hoist)
      update_role_data(hoist: hoist)
    end

    # Sets the role colour to something new
    # @param colour [ColourRGB] The new colour
    def colour=(colour)
      update_role_data(colour: colour)
    end

    alias_method :color=, :colour=

    # Changes the internal packed permissions
    # @note For internal use only
    # @!visibility private
    def packed=(packed, update_perms = true)
      update_role_data(permissions: packed)
      @permissions.bits = packed if update_perms
    end

    # Delets this role. This cannot be undone without recreating the role!
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
    # @return [Channel] the channel this invite references.
    attr_reader :channel

    # @return [Server] the server this invite references.
    attr_reader :server

    # @return [Integer] the amount of uses left on this invite.
    attr_reader :uses

    # @return [User, nil] the user that made this invite. May also be nil if the user can't be determined.
    attr_reader :inviter

    # @return [true, false] whether or not this invite is temporary.
    attr_reader :temporary

    # @return [true, false] whether this invite is still valid.
    attr_reader :revoked

    # @return [true, false] whether this invite is in xkcd format (i. e. "Human readable" in the invite settings)
    attr_reader :xkcd

    # @return [String] this invite's code
    attr_reader :code

    alias_method :max_uses, :uses
    alias_method :user, :inviter

    alias_method :temporary?, :temporary
    alias_method :revoked?, :revoked
    alias_method :xkcd?, :xkcd

    # @!visibility private
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

    # Code based comparison
    def ==(other)
      other.respond_to?(:code) ? (@code == other.code) : (@code == other)
    end

    # Deletes this invite
    def delete
      API.delete_invite(@bot.token, @code)
    end

    alias_method :revoke, :delete
  end

  # A Discord channel, including data like the topic
  class Channel
    # @return [String] this channel's name.
    attr_reader :name

    # @return [Server] the server this channel is on.
    attr_reader :server

    # @return [String] the type of this channel (currently either 'text' or 'voice')
    attr_reader :type

    # @note If this channel is a #general channel, its ID will be equal to the server on which it is on.
    # @return [Integer] the channel's unique ID.
    attr_reader :id

    # @note This data is sent by Discord and it's possible for this to falsely be true for certain kinds of integration
    #   channels (like Twitch subscriber ones). This appears to be a Discord bug that I can't reproduce myself, due to
    #   not having any integrations in place. If this occurs to you please tell me.
    # @deprecated Use {#private?} instead, it's guaranteed to be accurate.
    # @return [true, false] whether or not this channel is a private messaging channel.
    attr_reader :is_private

    # @return [User, nil] the recipient of the private messages, or nil if this is not a PM channel
    attr_reader :recipient

    # @return [String] the channel's topic
    attr_reader :topic

    # @return [Integer] the channel's position on the channel list
    attr_reader :position

    # This channel's permission overwrites, represented as a hash of role/user ID to an OpenStruct which has the
    # `allow` and `deny` properties which are {Permissions} objects respectively.
    # @return [Hash<Integer => OpenStruct>] the channel's permission overwrites
    attr_reader :permission_overwrites

    alias_method :resolve_id, :id

    # @return [true, false] whether or not this channel is a PM channel, with more accuracy than {#is_private}.
    def private?
      @server.nil?
    end

    # @!visibility private
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

    # Sends a message to this channel.
    # @param content [String] The content to send. Should not be longer than 2000 characters or it will result in an error.
    # @return [Message] the message that was sent.
    def send_message(content)
      @bot.send_message(@id, content)
    end

    # Sends a file to this channel. If it is an image, it will be embedded.
    # @param file [File] The file to send. There's no clear size limit for this, you'll have to attempt it for yourself (most non-image files are fine, large images may fail to embed)
    def send_file(file)
      @bot.send_file(@id, file)
    end

    # Permanently deletes this channel
    def delete
      API.delete_channel(@bot.token, @id)
    end

    # Sets this channel's name. The name must be alphanumeric with dashes, unless this is a voice channel (then there are no limitations)
    # @param name [String] The new name.
    def name=(name)
      @name = name
      update_channel_data
    end

    # Sets this channel's topic.
    # @param topic [String] The new topic.
    def topic=(topic)
      @topic = topic
      update_channel_data
    end

    # Sets this channel's position in the list.
    # @param position [Integer] The new position.
    def position=(position)
      @position = position
      update_channel_data
    end

    # Updates the cached data from another channel.
    # @note For internal use only
    # @!visibility private
    def update_from(other)
      @topic = other.topic
      @name = other.name
      @is_private = other.is_private
      @recipient = other.recipient
      @permission_overwrites = other.permission_overwrites
    end

    # The list of users currently in this channel. This is mostly useful for a voice channel, for a text channel it will
    # just return the users on the server that are online.
    # @return [Array<User>] the users in this channel
    def users
      if @type == 'text'
        @server.members.select { |u| u.status != :offline }
      else
        @server.members.select do |user|
          user.voice_channel.id == @id if user.voice_channel
        end
      end
    end

    # Retrieves some of this channel's message history.
    # @param amount [Integer] How many messages to retrieve. This must be less than or equal to 100, if it is higher
    #   than 100 it will be treated as 100 on Discord's side.
    # @param before_id [Integer] The ID of the most recent message the retrieval should start at, or nil if it should
    #   start at the current message.
    # @param after_id [Integer] The ID of the oldest message the retrieval should start at, or nil if it should start
    #   as soon as possible with the specified amount.
    # @return [Array<Message>] the retrieved messages.
    def history(amount, before_id = nil, after_id = nil)
      logs = API.channel_log(@bot.token, @id, amount, before_id, after_id)
      JSON.parse(logs).map { |message| Message.new(message, @bot) }
    end

    # Updates the cached permission overwrites
    # @note For internal use only
    # @!visibility private
    def update_overwrites(overwrites)
      @permission_overwrites = overwrites
    end

    # Add an {Await} for a message in this channel. This is identical in functionality to adding a
    # {Discordrb::Events::MessageEvent} await with the `in` attribute as this channel.
    # @see Bot#add_await
    def await(key, attributes = {}, &block)
      @bot.add_await(key, Discordrb::Events::MessageEvent, { in: @id }.merge(attributes), &block)
    end

    # Creates a new invite to this channel.
    # @param max_age [Integer] How many seconds this invite should last.
    # @param max_uses [Integer] How many times this invite should be able to be used.
    # @param temporary [true, false] Whether membership should be temporary (kicked after going offline).
    # @param xkcd [true, false] Whether or not the invite should be human-readable.
    # @return [Invite] the created invite.
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
    # @return [String] the content of this message.
    attr_reader :content

    # @return [User] the user that sent this message.
    attr_reader :author

    # @return [Channel] the channel in which this message was sent.
    attr_reader :channel

    # @return [Time] the timestamp at which this message was sent.
    attr_reader :timestamp

    # @return [Integer] the ID used to uniquely identify this message.
    attr_reader :id

    # @return [Array<User>] the users that were mentioned in this message.
    attr_reader :mentions

    alias_method :user, :author
    alias_method :text, :content
    alias_method :to_s, :content
    alias_method :resolve_id, :id

    # @!visibility private
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

    # Replies to this message with the specified content.
    # @see Channel#send_message
    def reply(content)
      @channel.send_message(content)
    end

    # Edits this message to have the specified content instead.
    # @param new_content [String] the new content the message should have.
    def edit(new_content)
      API.edit_message(@bot.token, @channel.id, @id, new_content)
    end

    # Deletes this message.
    def delete
      API.delete_message(@bot.token, @channel.id, @id)
    end

    # Add an {Await} for a message with the same user and channel.
    # @see Bot#add_await
    def await(key, attributes = {}, &block)
      @bot.add_await(key, Discordrb::Events::MessageEvent, { from: @author.id, in: @channel.id }.merge(attributes), &block)
    end

    # @return [true, false] whether this message was sent by the current {Bot}.
    def from_bot?
      @author.bot?
    end
  end

  # A server on Discord
  class Server
    # @return [String] the region the server is on (e. g. `amsterdam`).
    attr_reader :region

    # @return [String] this server's name.
    attr_reader :name

    # @deprecated Use #owner instead, then get the resulting {User}'s {User#id}.
    # @return [Integer] the server owner's user ID.
    attr_reader :owner_id

    # @return [User] The server owner.
    attr_reader :owner

    # @return [Integer] the ID used to uniquely identify this server.
    attr_reader :id

    # @return [Array<User>] an array of all the users on this server.
    attr_reader :members
    alias_method :users, :members

    # @return [Array<Channel>] an array of all the channels (text and voice) on this server.
    attr_reader :channels

    # @return [Array<Role>] an array of all the roles created on this server.
    attr_reader :roles

    # @return [true, false] whether or not this server is large (members > 100). If it is,
    # it means the members list may be inaccurate for a couple seconds after starting up the bot.
    attr_reader :large
    alias_method :large?, :large

    # @return [Integer] the absolute number of members on this server, offline or not.
    attr_reader :member_count

    # @todo Make this behave like user.avatar where a URL is available as well.
    # @return [String] the hexadecimal ID used to identify this server's icon.
    attr_reader :icon

    # @return [Integer] the amount of time after which a voice user gets moved into the AFK channel, in seconds.
    attr_reader :afk_timeout

    # @todo Make this a reader that returns a {Channel}
    # @return [Integer] the channel ID of the AFK channel, or `nil` if none is set.
    attr_reader :afk_channel_id

    alias_method :resolve_id, :id

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @owner_id = data['owner_id'].to_i
      @owner = bot.user(@owner_id)
      @id = data['id'].to_i
      update_data(data)

      @large = data['large']
      @member_count = data['member_count']

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

    # @return [Channel] The default channel on this server (usually called #general)
    def default_channel
      @bot.channel(@id)
    end

    alias_method :general_channel, :default_channel

    # Gets a role on this server based on its ID.
    # @param id [Integer] The role ID to look for.
    def role(id)
      @roles.find { |e| e.id == id }
    end

    # Adds a role to the role cache
    # @note For internal use only
    # @!visibility private
    def add_role(role)
      @roles << role
    end

    # Removes a role from the role cache
    # @note For internal use only
    # @!visibility private
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
    # @!visibility private
    def add_user(user)
      @members << user unless @members.include? user
      @member_count += 1
    end

    # Removes a user from the user cache.
    # @note For internal use only
    # @!visibility private
    def delete_user(user_id)
      @members.reject! { |member| member.id == user_id }.length
      @member_count -= 1
    end

    # Creates a channel on this server with the given name.
    # @return [Channel] the created channel.
    def create_channel(name)
      response = API.create_channel(@bot.token, @id, name, 'text')
      Channel.new(JSON.parse(response), @bot)
    end

    # Creates a role on this server which can then be modified. It will be initialized (on Discord's side)
    # with the regular role defaults the client uses, i. e. name is "new role", permissions are the default,
    # colour is the default etc.
    # @return [Role] the created role.
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

    # Sets the server's name.
    # @param name [String] The new server name.
    def name=(name)
      update_server_data(name: name)
    end

    # Moves the server to another region. This will cause a voice interruption of at most a second.
    # @param region [String] The new region the server should be in.
    def region=(region)
      update_server_data(region: region.to_s)
    end

    # Sets the server's icon.
    # @todo Make this behave in a similar way to User#avatar=.
    # @param icon [String] The new icon, in base64-encoded JPG format.
    def icon=(icon)
      update_server_data(icon: icon)
    end

    # Sets the server's AFK channel.
    # @param afk_channel [Channel, nil] The new AFK channel, or `nil` if there should be none set.
    def afk_channel=(afk_channel)
      update_server_data(afk_channel_id: afk_channel.resolve_id)
    end

    # @deprecated Use #afk_channel= with the ID instead.
    def afk_channel_id=(afk_channel_id)
      update_server_data(afk_channel_id: afk_channel_id)
    end

    # Sets the amount of time after which a user gets moved into the AFK channel.
    # @param afk_timeout [Integer] The AFK timeout, in seconds.
    def afk_timeout=(afk_timeout)
      update_server_data(afk_timeout: afk_timeout)
    end

    # Updates the cached data with new data
    # @note For internal use only
    # @!visibility private
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

  # A colour (red, green and blue values). Used for role colours. If you prefer the American spelling, the alias
  # {ColorRGB} is also available.
  class ColourRGB
    # @return [Integer] the red part of this colour (0-255).
    attr_reader :red

    # @return [Integer] the green part of this colour (0-255).
    attr_reader :green

    # @return [Integer] the blue part of this colour (0-255).
    attr_reader :blue

    # @return [Integer] the colour's RGB values combined into one integer.
    attr_reader :combined

    # Make a new colour from the combined value.
    # @param combined [Integer] The colour's RGB values combined into one integer
    def initialize(combined)
      @combined = combined
      @red = (combined >> 16) & 0xFF
      @green = (combined >> 8) & 0xFF
      @blue = combined & 0xFF
    end
  end

  # Alias for the class {ColourRGB}
  ColorRGB = ColourRGB
end
