# frozen_string_literal: true

# These classes hold relevant Discord data, such as messages or channels.

require 'ostruct'
require 'discordrb/permissions'
require 'discordrb/api'
require 'discordrb/events/message'
require 'time'
require 'base64'

# Discordrb module
module Discordrb
  # The unix timestamp Discord IDs are based on
  DISCORD_EPOCH = 1_420_070_400_000

  # Compares two objects based on IDs - either the objects' IDs are equal, or one object is equal to the other's ID.
  def self.id_compare(one_id, other)
    other.respond_to?(:resolve_id) ? (one_id.resolve_id == other.resolve_id) : (one_id == other)
  end

  # The maximum length a Discord message can have
  CHARACTER_LIMIT = 2000

  # Splits a message into chunks of 2000 characters. Attempts to split by lines if possible.
  # @param msg [String] The message to split.
  # @return [Array<String>] the message split into chunks
  def self.split_message(msg)
    # If the messages is empty, return an empty array
    return [] if msg.empty?

    # Split the message into lines
    lines = msg.lines

    # Turn the message into a "triangle" of consecutively longer slices, for example the array [1,2,3,4] would become
    # [
    #  [1],
    #  [1, 2],
    #  [1, 2, 3],
    #  [1, 2, 3, 4]
    # ]
    tri = [*0..(lines.length - 1)].map { |i| lines.combination(i + 1).first }

    # Join the individual elements together to get an array of strings with consecutively more lines
    joined = tri.map(&:join)

    # Find the largest element that is still below the character limit, or if none such element exists return the first
    ideal = joined.max_by { |e| e.length > CHARACTER_LIMIT ? -1 : e.length }

    # If it's still larger than the character limit (none was smaller than it) split it into slices with the length
    # being the character limit, otherwise just return an array with one element
    ideal_ary = (ideal.length > CHARACTER_LIMIT) ? ideal.chars.each_slice(CHARACTER_LIMIT).map(&:join) : [ideal]

    # Slice off the ideal part and strip newlines
    rest = msg[ideal.length..-1].strip

    # If none remains, return an empty array -> we're done
    return [] unless rest

    # Otherwise, call the method recursively to split the rest of the string and add it onto the ideal array
    ideal_ary + split_message(rest)
  end

  # Mixin for objects that have IDs
  module IDObject
    # @return [Integer] the ID which uniquely identifies this object across Discord.
    attr_reader :id
    alias_method :resolve_id, :id

    # ID based comparison
    def ==(other)
      Discordrb.id_compare(@id, other)
    end

    # Estimates the time this object was generated on based on the beginning of the ID. This is fairly accurate but
    # shouldn't be relied on as Discord might change its algorithm at any time
    # @return [Time] when this object was created at
    def creation_time
      # Milliseconds
      ms = (@id >> 22) + DISCORD_EPOCH
      Time.at(ms / 1000.0)
    end
  end

  # Mixin for the attributes users should have
  module UserAttributes
    # @return [String] this user's username
    attr_reader :username
    alias_method :name, :username

    # @return [String] this user's discriminator which is used internally to identify users with identical usernames.
    attr_reader :discriminator
    alias_method :discrim, :discriminator
    alias_method :tag, :discriminator
    alias_method :discord_tag, :discriminator

    # @return [true, false] whether this user is a Discord bot account
    attr_reader :bot_account
    alias_method :bot_account?, :bot_account

    # @return [String] the ID of this user's current avatar, can be used to generate an avatar URL.
    # @see #avatar_url
    attr_reader :avatar_id

    # Utility function to mention users in messages
    # @return [String] the mention code in the form of <@id>
    def mention
      "<@#{@id}>"
    end

    # Utility function to get Discord's distinct representation of a user, i. e. username + discriminator
    # @return [String] distinct representation of user
    def distinct
      "#{@username}##{@discriminator}"
    end

    # Utility function to get a user's avatar URL.
    # @return [String] the URL to the avatar image.
    def avatar_url
      API.avatar_url(@id, @avatar_id)
    end
  end

  # User on Discord, including internal data like discriminators
  class User
    include IDObject
    include UserAttributes

    # @!attribute [r] status
    #   @return [Symbol] the current online status of the user (`:online`, `:offline` or `:idle`)
    attr_accessor :status

    # @!attribute [r] game
    #   @return [String, nil] the game the user is currently playing, or `nil` if none is being played.
    attr_accessor :game

    def initialize(data, bot)
      @bot = bot

      @username = data['username']
      @id = data['id'].to_i
      @discriminator = data['discriminator']
      @avatar_id = data['avatar']
      @roles = {}

      @bot_account = false
      @bot_account = true if data['bot']

      @status = :offline
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

    # Set the user's name
    # @note for internal use only
    # @!visibility private
    def update_username(username)
      @username = username
    end

    # Add an await for a message from this user. Specifically, this adds a global await for a MessageEvent with this
    # user's ID as a :from attribute.
    # @see Bot#add_await
    def await(key, attributes = {}, &block)
      @bot.add_await(key, Discordrb::Events::MessageEvent, { from: @id }.merge(attributes), &block)
    end

    # Gets the member this user is on a server
    # @param server [Server] The server to get the member for
    # @return [Member] this user as a member on a particular server
    def on(server)
      id = server.resolve_id
      @bot.server(id).member(@id)
    end

    # Is the user the bot?
    # @return [true, false] whether this user is the bot
    def current_bot?
      @bot.profile.id == @id
    end

    [:offline, :idle, :online].each do |e|
      define_method(e.to_s + '?') do
        @status.to_sym == e
      end
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<User username=#{@username} id=#{@id} discriminator=#{@discriminator}>"
    end
  end

  # Mixin for the attributes members and private members should have
  module MemberAttributes
    # @return [true, false] whether this member is muted server-wide.
    attr_reader :mute
    alias_method :muted?, :mute

    # @return [true, false] whether this member is deafened server-wide.
    attr_reader :deaf
    alias_method :deafened?, :deaf

    # @return [true, false] whether this member has muted themselves.
    attr_reader :self_mute
    alias_method :self_muted?, :self_mute

    # @return [true, false] whether this member has deafened themselves.
    attr_reader :self_deaf
    alias_method :self_deafened?, :self_deaf

    # @return [Time] when this member joined the server.
    attr_reader :joined_at

    # @return [String, nil] the nickname this member has, or nil if it has none.
    attr_reader :nick
    alias_method :nickname, :nick

    # @return [Array<Role>] the roles this member has.
    attr_reader :roles

    # @return [Server] the server this member is on.
    attr_reader :server

    # @return [Channel] the voice channel the user is in.
    attr_reader :voice_channel
  end

  # Mixin to calculate resulting permissions from overrides etc.
  module PermissionCalculator
    # Checks whether this user can do the particular action, regardless of whether it has the permission defined,
    # through for example being the server owner or having the Manage Roles permission
    # @param action [Symbol] The permission that should be checked. See also {Permissions::Flags} for a list.
    # @param channel [Channel, nil] If channel overrides should be checked too, this channel specifies where the overrides should be checked.
    # @return [true, false] whether or not this user has the permission.
    def permission?(action, channel = nil)
      # If the member is the server owner, it irrevocably has all permissions.
      return true if owner?

      # First, check whether the user has Manage Roles defined.
      # (Coincidentally, Manage Permissions is the same permission as Manage Roles, and a
      # Manage Permissions deny overwrite will override Manage Roles, so we can just check for
      # Manage Roles once and call it a day.)
      return true if defined_permission?(:manage_roles, channel)

      # Otherwise, defer to defined_permission
      defined_permission?(action, channel)
    end

    # Checks whether this user has a particular permission defined (i. e. not implicit, through for example
    # Manage Roles)
    # @param action [Symbol] The permission that should be checked. See also {Permissions::Flags} for a list.
    # @param channel [Channel, nil] If channel overrides should be checked too, this channel specifies where the overrides should be checked.
    # @return [true, false] whether or not this user has the permission defined.
    def defined_permission?(action, channel = nil)
      # Get the permission the user's roles have
      role_permission = defined_role_permission?(action, channel)

      # Once we have checked the role permission, we have to check the channel overrides for the
      # specific user
      user_specific_override = permission_overwrite(action, channel, id) # Use the ID reader as members have no ID instance variable

      # Merge the two permissions - if an override is defined, it has to be allow, otherwise we only care about the role
      return role_permission unless user_specific_override
      user_specific_override == :allow
    end

    # Define methods for querying permissions
    Discordrb::Permissions::Flags.each_value do |flag|
      define_method "can_#{flag}?" do |channel = nil|
        permission? flag, channel
      end
    end

    private

    def defined_role_permission?(action, channel)
      # For each role, check if
      #   (1) the channel explicitly allows or permits an action for the role and
      #   (2) if the user is allowed to do the action if the channel doesn't specify
      @roles.reduce(false) do |can_act, role|
        # Get the override defined for the role on the channel
        channel_allow = permission_overwrite(action, channel, role.id)
        can_act = if channel_allow
                    # If the channel has an override, check whether it is an allow - if yes,
                    # the user can act, if not, it can't
                    channel_allow == :allow
                  else
                    # Otherwise defer to the role
                    role.permissions.instance_variable_get("@#{action}") || can_act
                  end
        can_act
      end
    end

    def permission_overwrite(action, channel, id)
      # If no overwrites are defined, or no channel is set, no overwrite will be present
      return nil unless channel && channel.permission_overwrites[id]

      # Otherwise, check the allow and deny objects
      allow = channel.permission_overwrites[id].allow
      deny = channel.permission_overwrites[id].deny
      if allow.instance_variable_get("@#{action}")
        :allow
      elsif deny.instance_variable_get("@#{action}")
        :deny
      end

      # If there's no variable defined, nil will implicitly be returned
    end
  end

  # A member is a user on a server. It differs from regular users in that it has roles, voice statuses and things like
  # that.
  class Member < DelegateClass(User)
    include MemberAttributes

    # @!visibility private
    def initialize(data, server, bot)
      @bot = bot

      @user = bot.ensure_user(data['user'])
      super @user # Initialize the delegate class

      # Somehow, Discord doesn't send the server ID in the standard member format...
      raise ArgumentError, 'Cannot create a member without any information about the server!' if server.nil? && data['guild_id'].nil?
      @server = server || bot.server(data['guild_id'].to_i)

      # Initialize the roles by getting the roles from the server one-by-one
      update_roles(data['roles'])

      @nick = data['nick']

      @deaf = data['deaf']
      @mute = data['mute']
      @joined_at = data['joined_at'] ? Time.parse(data['joined_at']) : nil
    end

    # @return [true, false] whether this member is the server owner.
    def owner?
      @server.owner == self
    end

    # @param role [Role, Integer, #resolve_id] the role to check or its ID.
    # @return [true, false] whether this member has the specified role.
    def role?(role)
      role = role.resolve_id
      @roles.any? { |e| e.id == role }
    end

    # Adds one or more roles to this member.
    # @param role [Role, Array<Role>] The role(s) to add.
    def add_role(role)
      role_ids = role_id_array(role)
      old_role_ids = @roles.map(&:id)
      new_role_ids = (old_role_ids + role_ids).uniq

      API.update_user_roles(@bot.token, @server.id, @user.id, new_role_ids)
    end

    # Removes one or more roles from this member.
    # @param role [Role, Array<Role>] The role(s) to remove.
    def remove_role(role)
      old_role_ids = @roles.map(&:id)
      role_ids = role_id_array(role)
      new_role_ids = old_role_ids.reject { |i| role_ids.include?(i) }

      API.update_user_roles(@bot.token, @server.id, @user.id, new_role_ids)
    end

    # Sets or resets this member's nickname. Requires the Change Nickname permission for the bot itself and Manage
    # Nicknames for other users.
    # @param nick [String, nil] The string to set the nickname to, or nil if it should be reset.
    def nick=(nick)
      # Discord uses the empty string to signify 'no nickname' so we convert nil into that
      nick ||= ''

      API.change_nickname(@bot.token, @server.id, @user.id, nick)
    end

    alias_method :nickname=, :nick=

    # @return [String] the name the user displays as (nickname if they have one, username otherwise)
    def display_name
      nickname || username
    end

    # Update this member's roles
    # @note For internal use only.
    # @!visibility private
    def update_roles(roles)
      @roles = roles.map do |role|
        role.is_a?(Role) ? role : @server.role(role.to_i)
      end
    end

    # Update this member's nick
    # @note For internal use only.
    # @!visibility private
    def update_nick(nick)
      @nick = nick
    end

    # Update this member's voice state
    # @note For internal use only.
    # @!visibility private
    def update_voice_state(channel, mute, deaf, self_mute, self_deaf)
      @voice_channel = channel
      @mute = mute
      @deaf = deaf
      @self_mute = self_mute
      @self_deaf = self_deaf
    end

    include PermissionCalculator

    # Overwriting inspect for debug purposes
    def inspect
      "<Member user=#{@user.inspect} server=#{@server.inspect} joined_at=#{@joined_at} roles=#{@roles.inspect} voice_channel=#{@voice_channel.inspect} mute=#{@mute} deaf=#{@deaf} self_mute=#{@self_mute} self_deaf=#{@self_deaf}>"
    end

    private

    # Utility method to get a list of role IDs from one role or an array of roles
    def role_id_array(role)
      if role.is_a? Array
        role.map(&:resolve_id)
      else
        [role.resolve_id]
      end
    end
  end

  # Recipients are members on private channels - they exist for completeness purposes, but all
  # the attributes will be empty.
  class Recipient < DelegateClass(User)
    include MemberAttributes

    # @return [Channel] the private channel this recipient is the recipient of.
    attr_reader :channel

    # @!visibility private
    def initialize(user, channel, bot)
      @bot = bot
      @channel = channel
      raise ArgumentError, 'Tried to create a recipient for a public channel!' unless @channel.private?

      @user = user
      super @user

      # Member attributes
      @mute = @deaf = @self_mute = @self_deaf = false
      @voice_channel = nil
      @server = nil
      @roles = []
      @joined_at = @channel.creation_time
    end

    # Overwriting inspect for debug purposes
    def inspect
      "<Recipient user=#{@user.inspect} channel=#{@channel.inspect}>"
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
    def current_bot?
      true
    end

    # Sets the bot's username.
    # @param username [String] The new username.
    def username=(username)
      update_profile_data(username: username)
    end

    # Sets the bot's email address. If you use this method, make sure that the login email in the script matches this
    # one afterwards, so the bot doesn't have any trouble logging in in the future.
    # @param email [String] The new email address.
    def email=(email)
      update_profile_data(email: email)
    end

    # Changes the bot's password. This will invalidate all tokens so you will have to relog the bot.
    # @param password [String] The new password.
    def password=(password)
      update_profile_data(new_password: password)
    end

    # Changes the bot's avatar.
    # @param avatar [String, #read] A JPG file to be used as the avatar, either
    #  something readable (e. g. File) or as a data URL.
    def avatar=(avatar)
      if avatar.respond_to? :read
        # Set the file to binary mode if supported, so we don't get problems with Windows
        avatar.binmode if avatar.respond_to?(:binmode)

        avatar_string = 'data:image/jpg;base64,'
        avatar_string += Base64.strict_encode64(avatar.read)
        update_profile_data(avatar: avatar_string)
      else
        update_profile_data(avatar: avatar)
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

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Profile email=#{@email} user=#{super}>"
    end

    private

    def update_profile_data(new_data)
      API.update_user(@bot.token,
                      new_data[:email] || @email,
                      @password,
                      new_data[:username] || @username,
                      new_data[:avatar],
                      new_data[:new_password] || nil)
      update_data(new_data)
    end
  end

  # A Discord role that contains permissions and applies to certain users
  class Role
    include IDObject

    # @return [Permissions] this role's permissions.
    attr_reader :permissions

    # @return [String] this role's name ("new role" if it hasn't been changed)
    attr_reader :name

    # @return [true, false] whether or not this role should be displayed separately from other users
    attr_reader :hoist

    # @return [true, false] whether this role can be mentioned using a role mention
    attr_reader :mentionable
    alias_method :mentionable?, :mentionable

    # @return [ColourRGB] the role colour
    attr_reader :colour

    alias_method :color, :colour

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
      @mentionable = data['mentionable']

      @colour = ColourRGB.new(data['color'])
    end

    # @return [String] a string that will mention this role, if it is mentionable.
    def mention
      "<@&#{@id}>"
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

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Role name=#{@name} permissions=#{@permissions.inspect} hoist=#{@hoist} colour=#{@colour.inspect} server=#{@server.inspect}>"
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

  # A channel referenced by an invite. It has less data than regular channels, so it's a separate class
  class InviteChannel
    include IDObject

    # @return [String] this channel's name.
    attr_reader :name

    # @return [String] this channel's type (text or voice)
    attr_reader :type

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @id = data['id'].to_i
      @name = data['name']
      @type = data['type']
    end
  end

  # A server referenced to by an invite
  class InviteServer
    include IDObject

    # @return [String] this server's name.
    attr_reader :name

    # @return [String, nil] the hash of the server's invite splash screen (for partnered servers) or nil if none is
    #   present
    attr_reader :splash_hash

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @id = data['id'].to_i
      @name = data['name']
      @splash_hash = data['splash_hash']
    end
  end

  # A Discord invite to a channel
  class Invite
    # @return [InviteChannel] the channel this invite references.
    attr_reader :channel

    # @return [InviteServer] the server this invite references.
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

      @channel = InviteChannel.new(data['channel'], bot)
      @server = InviteServer.new(data['guild'], bot)
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

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Invite code=#{@code} channel=#{@channel} uses=#{@uses} temporary=#{@temporary} revoked=#{@revoked} xkcd=#{@xkcd}>"
    end

    # Creates an invite URL.
    def url
      "https://discord.gg/#{@code}"
    end
  end

  # A Discord channel, including data like the topic
  class Channel
    # The type string that stands for a text channel
    # @see Channel#type
    TEXT_TYPE = 'text'.freeze

    # The type string that stands for a voice channel
    # @see Channel#type
    VOICE_TYPE = 'voice'.freeze

    include IDObject

    # @return [String] this channel's name.
    attr_reader :name

    # @return [Server, nil] the server this channel is on. If this channel is a PM channel, it will be nil.
    attr_reader :server

    # @return [String] the type of this channel (currently either 'text' or 'voice')
    attr_reader :type

    # @return [Recipient, nil] the recipient of the private messages, or nil if this is not a PM channel
    attr_reader :recipient

    # @return [String] the channel's topic
    attr_reader :topic

    # @return [Integer] the channel's position on the channel list
    attr_reader :position

    # This channel's permission overwrites, represented as a hash of role/user ID to an OpenStruct which has the
    # `allow` and `deny` properties which are {Permissions} objects respectively.
    # @return [Hash<Integer => OpenStruct>] the channel's permission overwrites
    attr_reader :permission_overwrites

    # @return [true, false] whether or not this channel is a PM channel.
    def private?
      @server.nil?
    end

    # @return [String] a string that will mention the channel as a clickable link on Discord.
    def mention
      "<##{@id}>"
    end

    # @!visibility private
    def initialize(data, bot, server = nil)
      @bot = bot

      # data is a sometimes a Hash and othertimes an array of Hashes, you only want the last one if it's an array
      data = data[-1] if data.is_a?(Array)

      @id = data['id'].to_i
      @type = data['type'] || TEXT_TYPE
      @topic = data['topic']
      @position = data['position']

      @is_private = data['is_private']
      if @is_private
        recipient_user = bot.ensure_user(data['recipient'])
        @recipient = Recipient.new(recipient_user, self, bot)
        @name = @recipient.username
      else
        @name = data['name']
        @server = if server
                    server
                  else
                    bot.server(data['guild_id'].to_i)
                  end
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

    # @return [true, false] whether or not this channel is a text channel
    def text?
      @type == TEXT_TYPE
    end

    # @return [true, false] whether or not this channel is a voice channel
    def voice?
      @type == VOICE_TYPE
    end

    # Sends a message to this channel.
    # @param content [String] The content to send. Should not be longer than 2000 characters or it will result in an error.
    # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
    # @return [Message] the message that was sent.
    def send_message(content, tts = false)
      @bot.send_message(@id, content, tts, @server && @server.id)
    end

    # Sends multiple messages to a channel
    # @param content [Array<String>] The messages to send.
    def send_multiple(content)
      content.each { |e| send_message(e) }
    end

    # Splits a message into chunks whose length is at most the Discord character limit, then sends them individually.
    # Useful for sending long messages, but be wary of rate limits!
    def split_send(content)
      send_multiple(Discordrb.split_message(content))
    end

    # Sends a file to this channel. If it is an image, it will be embedded.
    # @param file [File] The file to send. There's no clear size limit for this, you'll have to attempt it for yourself (most non-image files are fine, large images may fail to embed)
    # @param caption [string] The caption for the file.
    # @param tts [true, false] Whether or not this file's caption should be sent using Discord text-to-speech.
    def send_file(file, caption: nil, tts: false)
      @bot.send_file(@id, file, caption: caption, tts: tts)
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

    # Defines a permission overwrite for this channel that sets the specified thing to the specified allow and deny
    # permission sets, or change an existing one.
    # @param thing [User, Role] What to define an overwrite for.
    # @param allow [#bits, Permissions, Integer] The permission sets that should receive an `allow` override (i. e. a
    #   green checkmark on Discord)
    # @param deny [#bits, Permissions, Integer] The permission sets that should receive a `deny` override (i. e. a red
    #   cross on Discord)
    # @example Define a permission overwrite for a user that can then mention everyone and use TTS, but not create any invites
    #   allow = Discordrb::Permissions.new
    #   allow.can_mention_everyone = true
    #   allow.can_send_tts_messages = true
    #
    #   deny = Discordrb::Permissions.new
    #   deny.can_create_instant_invite = true
    #
    #   channel.define_overwrite(user, allow, deny)
    def define_overwrite(thing, allow, deny)
      allow_bits = allow.respond_to?(:bits) ? allow.bits : allow
      deny_bits = deny.respond_to?(:bits) ? deny.bits : deny

      if thing.is_a? User
        API.update_user_overrides(@bot.token, @id, thing.id, allow_bits, deny_bits)
      elsif thing.is_a? Role
        API.update_role_overrides(@bot.token, @id, thing.id, allow_bits, deny_bits)
      end
    end

    # Updates the cached data from another channel.
    # @note For internal use only
    # @!visibility private
    def update_from(other)
      @topic = other.topic
      @name = other.name
      @recipient = other.recipient
      @permission_overwrites = other.permission_overwrites
    end

    # The list of users currently in this channel. This is mostly useful for a voice channel, for a text channel it will
    # just return the users on the server that are online.
    # @return [Array<Member>] the users in this channel
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

    # Deletes the last N messages on this channel. Each delete request is performed in a separate thread for performance
    # reasons, so if a large number of messages are pruned, many threads will be created.
    # @note As of the April 29 update, the message delete request is rate limited, which means this method will take
    #   a long time. It will eventually be updated to use batch deletes once those are released, but that will be in the
    #   far future.
    # @param amount [Integer] How many messages to delete. Must be 100 or less (Discord limitation)
    # @raise [ArgumentError] if more than 100 messages are requested.
    def prune(amount)
      raise ArgumentError, "Can't prune more than 100 messages!" if amount > 100

      threads = []
      history(amount).each do |message|
        threads << Thread.new { message.delete }
      end

      # Make sure all requests have finished
      threads.each(&:join)

      # Delete the threads
      threads.map! { nil }
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

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Channel name=#{@name} id=#{@id} topic=\"#{@topic}\" type=#{@type} position=#{@position} server=#{@server}>"
    end

    private

    def update_channel_data
      API.update_channel(@bot.token, @id, @name, @topic, @position)
    end
  end

  # An attachment to a message
  class Attachment
    include IDObject

    # @return [Message] the message this attachment belongs to.
    attr_reader :message

    # @return [String] the CDN URL this attachment can be downloaded at.
    attr_reader :url

    # @return [String] the attachment's proxy URL - I'm not sure what exactly this does, but I think it has something to
    #   do with CDNs
    attr_reader :proxy_url

    # @return [String] the attachment's filename.
    attr_reader :filename

    # @return [Integer] the attachment's file size in bytes.
    attr_reader :size

    # @return [Integer, nil] the width of an image file, in pixels, or nil if the file is not an image.
    attr_reader :width

    # @return [Integer, nil] the height of an image file, in pixels, or nil if the file is not an image.
    attr_reader :height

    # @!visibility private
    def initialize(data, message, bot)
      @bot = bot
      @message = message

      @url = data['url']
      @proxy_url = data['proxy_url']
      @filename = data['filename']

      @size = data['size']

      @width = data['width']
      @height = data['height']
    end

    # @return [true, false] whether this file is an image file.
    def image?
      !(@width.nil? || @height.nil?)
    end
  end

  # A message on Discord that was sent to a text channel
  class Message
    include IDObject

    # @return [String] the content of this message.
    attr_reader :content

    # @return [Member] the user that sent this message.
    attr_reader :author

    # @return [Channel] the channel in which this message was sent.
    attr_reader :channel

    # @return [Time] the timestamp at which this message was sent.
    attr_reader :timestamp

    # @return [Array<User>] the users that were mentioned in this message.
    attr_reader :mentions

    # @return [Array<Role>] the roles that were mentioned in this message.
    attr_reader :role_mentions

    # @return [Array<Attachment>] the files attached to this message.
    attr_reader :attachments

    alias_method :user, :author
    alias_method :text, :content
    alias_method :to_s, :content

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @content = data['content']
      @channel = bot.channel(data['channel_id'].to_i)

      @author = if data['author']
                  if @channel.private?
                    # Turn the message user into a recipient - we can't use the channel recipient
                    # directly because the bot may also send messages to the channel
                    Recipient.new(bot.user(data['author']['id'].to_i), @channel, bot)
                  else
                    member = @channel.server.member(data['author']['id'].to_i, false)
                    Discordrb::LOGGER.warn("Member with ID #{data['author']['id']} not cached even though it should be.") unless member
                    member
                  end
                end

      @timestamp = Time.parse(data['timestamp']) if data['timestamp']
      @id = data['id'].to_i

      @mentions = []

      data['mentions'].each do |element|
        @mentions << bot.ensure_user(element)
      end if data['mentions']

      @role_mentions = []

      # Role mentions can only happen on public servers so make sure we only parse them there
      unless @channel.private?
        data['mention_roles'].each do |element|
          @role_mentions << @channel.server.role(element.to_i)
        end if data['mention_roles']
      end

      @attachments = []
      @attachments = data['attachments'].map { |e| Attachment.new(e, self, @bot) } if data['attachments']
    end

    # Replies to this message with the specified content.
    # @see Channel#send_message
    def reply(content)
      @channel.send_message(content)
    end

    # Edits this message to have the specified content instead.
    # @param new_content [String] the new content the message should have.
    # @return [Message] the resulting message.
    def edit(new_content)
      response = API.edit_message(@bot.token, @channel.id, @id, new_content)
      Message.new(JSON.parse(response), @bot)
    end

    # Deletes this message.
    def delete
      API.delete_message(@bot.token, @channel.id, @id)
      nil
    end

    # Add an {Await} for a message with the same user and channel.
    # @see Bot#add_await
    def await(key, attributes = {}, &block)
      @bot.add_await(key, Discordrb::Events::MessageEvent, { from: @author.id, in: @channel.id }.merge(attributes), &block)
    end

    # @return [true, false] whether this message was sent by the current {Bot}.
    def from_bot?
      @author && @author.current_bot?
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Message content=\"#{@content}\" id=#{@id} timestamp=#{@timestamp} author=#{@author} channel=#{@channel}>"
    end
  end

  # Basic attributes a server should have
  module ServerAttributes
    # @return [String] this server's name.
    attr_reader :name

    # @return [String] the hexadecimal ID used to identify this server's icon.
    attr_reader :icon_id

    # Utility function to get the URL for the icon image
    # @return [String] the URL to the icon image
    def icon_url
      API.icon_url(@id, @icon_id)
    end
  end

  # A server on Discord
  class Server
    include IDObject
    include ServerAttributes

    # @return [String] the region the server is on (e. g. `amsterdam`).
    attr_reader :region

    # @return [Member] The server owner.
    attr_reader :owner

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

    # @return [Integer] the amount of time after which a voice user gets moved into the AFK channel, in seconds.
    attr_reader :afk_timeout

    # @return [Channel, nil] the AFK voice channel of this server, or nil if none is set
    attr_reader :afk_channel

    # @!visibility private
    def initialize(data, bot, exists = true)
      @bot = bot
      @owner_id = data['owner_id'].to_i
      @id = data['id'].to_i
      update_data(data)

      @large = data['large']
      @member_count = data['member_count']
      @members = {}

      process_roles(data['roles'])
      process_members(data['members'])
      process_presences(data['presences'])
      process_channels(data['channels'])
      process_voice_states(data['voice_states'])

      # Whether this server's members have been chunked (resolved using op 8 and GUILD_MEMBERS_CHUNK) yet
      @chunked = false
      @processed_chunk_members = 0

      # Only get the owner of the server actually exists (i. e. not for ServerDeleteEvent)
      @owner = member(@owner_id) if exists
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

    # Gets a member on this server based on user ID
    # @param id [Integer] The user ID to look for
    # @param request [true, false] Whether the member should be requested from Discord if it's not cached
    def member(id, request = true)
      id = id.resolve_id
      return @members[id] if member_cached?(id)
      return nil unless request

      member = @bot.member(@id, id)
      @members[id] = member
    end

    # @return [Array<Member>] an array of all the members on this server.
    def members
      return @members.values if @chunked

      @bot.debug("Members for server #{@id} not chunked yet - initiating")
      @bot.request_chunks(@id)
      sleep 0.05 until @chunked
      @members.values
    end

    alias_method :users, :members

    # @param include_idle [true, false] Whether to count idle members as online.
    # @param include_bots [true, false] Whether to include bot accounts in the count.
    # @return [Array<Member>] an array of online members on this server.
    def online_members(include_idle: false, include_bots: true)
      @members.values.select do |e|
        ((include_idle ? e.idle? : false) || e.online?) && (include_bots ? true : !e.bot_account?)
      end
    end

    alias_method :online_users, :online_members

    # @return [Array<Channel>] an array of text channels on this server
    def text_channels
      @channels.select(&:text?)
    end

    # @return [Array<Channel>] an array of voice channels on this server
    def voice_channels
      @channels.select(&:voice?)
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
      @members.each do |_, member|
        new_roles = member.roles.reject { |r| r.id == role_id }
        member.update_roles(new_roles)
      end
      @channels.each do |channel|
        overwrites = channel.permission_overwrites.reject { |id, _| id == role_id }
        channel.update_overwrites(overwrites)
      end
    end

    # Adds a member to the member cache.
    # @note For internal use only
    # @!visibility private
    def add_member(member)
      @members[member.id] = member
      @member_count += 1
    end

    # Removes a member from the member cache.
    # @note For internal use only
    # @!visibility private
    def delete_member(user_id)
      @members.delete(user_id)
      @member_count -= 1
    end

    # Checks whether a member is cached
    # @note For internal use only
    # @!visibility private
    def member_cached?(user_id)
      @members.include?(user_id)
    end

    # Adds a member to the cache
    # @note For internal use only
    # @!visibility private
    def cache_member(member)
      @members[member.id] = member
    end

    # Creates a channel on this server with the given name.
    # @return [Channel] the created channel.
    def create_channel(name, type = 'text')
      response = API.create_channel(@bot.token, @id, name, type)
      Channel.new(JSON.parse(response), @bot)
    end

    # Creates a role on this server which can then be modified. It will be initialized (on Discord's side)
    # with the regular role defaults the client uses, i. e. name is "new role", permissions are the default,
    # colour is the default etc.
    # @return [Role] the created role.
    def create_role
      response = API.create_role(@bot.token, @id)
      role = Role.new(JSON.parse(response), @bot, self)
      @roles << role
      role
    end

    # @return [Array<User>] a list of banned users on this server.
    def bans
      users = JSON.parse(API.bans(@bot.token, @id))
      users.map { |e| User.new(e['user'], @bot) }
    end

    # Bans a user from this server.
    # @param user [User, #resolve_id] The user to ban.
    # @param message_days [Integer] How many days worth of messages sent by the user should be deleted.
    def ban(user, message_days = 0)
      API.ban_user(@bot.token, @id, user.resolve_id, message_days)
    end

    # Unbans a previously banned user from this server.
    # @param user [User, #resolve_id] The user to unban.
    def unban(user)
      API.unban_user(@bot.token, @id, user.resolve_id)
    end

    # Kicks a user from this server.
    # @param user [User, #resolve_id] The user to kick.
    def kick(user)
      API.kick_user(@bot.token, @id, user.resolve_id)
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

    # Leave the server
    def leave
      API.leave_server(@bot.token, @id)
    end

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
    # @param icon [String, #read] The new icon, in base64-encoded JPG format.
    def icon=(icon)
      if icon.respond_to? :read
        icon_string = 'data:image/jpg;base64,'
        icon_string += Base64.strict_encode64(icon.read)
        update_server_data(icon: icon_string)
      else
        update_server_data(icon: icon)
      end
    end

    # Sets the server's AFK channel.
    # @param afk_channel [Channel, nil] The new AFK channel, or `nil` if there should be none set.
    def afk_channel=(afk_channel)
      update_server_data(afk_channel_id: afk_channel.resolve_id)
    end

    # Sets the amount of time after which a user gets moved into the AFK channel.
    # @param afk_timeout [Integer] The AFK timeout, in seconds.
    def afk_timeout=(afk_timeout)
      update_server_data(afk_timeout: afk_timeout)
    end

    # Processes a GUILD_MEMBERS_CHUNK packet, specifically the members field
    # @note For internal use only
    # @!visibility private
    def process_chunk(members)
      process_members(members)
      @processed_chunk_members += members.length
      LOGGER.debug("Processed one chunk on server #{@id} - length #{members.length}")

      # Don't bother with the rest of the method if it's not truly the last packet
      return unless @processed_chunk_members == @member_count

      LOGGER.debug("Finished chunking server #{@id}")

      # Reset everything to normal
      @chunked = true
      @processed_chunk_members = 0
    end

    # Updates the cached data with new data
    # @note For internal use only
    # @!visibility private
    def update_data(new_data)
      @name = new_data[:name] || new_data['name'] || @name
      @region = new_data[:region] || new_data['region'] || @region
      @icon_id = new_data[:icon] || new_data['icon'] || @icon_id
      @afk_timeout = new_data[:afk_timeout] || new_data['afk_timeout'].to_i || @afk_timeout

      @afk_channel_id = new_data[:afk_channel_id] || new_data['afk_channel_id'].to_i || @afk_channel.id
      @afk_channel = @bot.channel(@afk_channel_id, self) if @afk_channel_id != 0 && (!@afk_channel || @afk_channel_id != @afk_channel.id)
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Server name=#{@name} id=#{@id} large=#{@large} region=#{@region} owner=#{@owner} afk_channel_id=#{@afk_channel_id} afk_timeout=#{@afk_timeout}>"
    end

    private

    def update_server_data(new_data)
      API.update_server(@bot.token, @id,
                        new_data[:name] || @name,
                        new_data[:region] || @region,
                        new_data[:icon_id] || @icon_id,
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
      return unless members
      members.each do |element|
        member = Member.new(element, self, @bot)
        if @members[member.id] && @members[member.id].voice_channel
          @bot.debug("Preserving voice state of member #{member.id} while chunking")
          old_member = @members[member.id]
          member.update_voice_state(
            old_member.voice_channel,
            old_member.mute,
            old_member.deaf,
            old_member.self_mute,
            old_member.self_deaf
          )
        end
        @members[member.id] = member
      end
    end

    def process_presences(presences)
      # Update user statuses with presence info
      return unless presences
      presences.each do |element|
        next unless element['user']
        user_id = element['user']['id'].to_i
        user = @members[user_id]
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
        channel = @bot.ensure_channel(element, self)
        @channels << channel
        @channels_by_id[channel.id] = channel
      end
    end

    def process_voice_states(voice_states)
      return unless voice_states
      voice_states.each do |element|
        user_id = element['user_id'].to_i
        member = @members[user_id]
        next unless member
        channel_id = element['channel_id'].to_i
        channel = channel_id ? @channels_by_id[channel_id] : nil

        member.update_voice_state(
          channel,
          element['mute'],
          element['deaf'],
          element['self_mute'],
          element['self_deaf'])
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
