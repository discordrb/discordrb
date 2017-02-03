# frozen_string_literal: true

# These classes hold relevant Discord data, such as messages or channels.

require 'ostruct'
require 'discordrb/permissions'
require 'discordrb/errors'
require 'discordrb/api'
require 'discordrb/api/channel'
require 'discordrb/api/server'
require 'discordrb/api/invite'
require 'discordrb/api/user'
require 'discordrb/webhooks/embeds'
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
    ideal_ary = ideal.length > CHARACTER_LIMIT ? ideal.chars.each_slice(CHARACTER_LIMIT).map(&:join) : [ideal]

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

    # Creates an artificial snowflake at the given point in time. Useful for comparing against.
    # @param time [Time] The time the snowflake should represent.
    # @return [Integer] a snowflake with the timestamp data as the given time
    def self.synthesise(time)
      ms = (time.to_f * 1000).to_i
      (ms - DISCORD_EPOCH) << 22
    end

    class << self
      alias_method :synthesize, :synthesise
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
    attr_accessor :avatar_id

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
      API::User.avatar_url(@id, @avatar_id)
    end
  end

  # User on Discord, including internal data like discriminators
  class User
    include IDObject
    include UserAttributes

    # @return [Symbol] the current online status of the user (`:online`, `:offline` or `:idle`)
    attr_reader :status

    # @return [String, nil] the game the user is currently playing, or `nil` if none is being played.
    attr_reader :game

    # @return [String, nil] the URL to the stream, if the user is currently streaming something.
    attr_reader :stream_url

    # @return [String, Integer, nil] the type of the stream. Can technically be set to anything, most of the time it
    #   will be 0 for no stream or 1 for Twitch streams.
    attr_reader :stream_type

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
        @bot.pm_channel(@id)
      end
    end

    alias_method :dm, :pm

    # Send the user a file.
    # @param file [File] The file to send to the user
    # @param caption [String] The caption of the file being sent
    # @return [Message] the message sent to this user.
    def send_file(file, caption = nil)
      pm.send_file(file, caption: caption)
    end

    # Set the user's name
    # @note for internal use only
    # @!visibility private
    def update_username(username)
      @username = username
    end

    # Set the user's presence data
    # @note for internal use only
    # @!visibility private
    def update_presence(data)
      @status = data['status'].to_sym

      if data['game']
        game = data['game']

        @game = game['name']
        @stream_url = game['url']
        @stream_type = game['type']
      else
        @game = @stream_url = @stream_type = nil
      end
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

    # @return [true, false] whether this user is a fake user for a webhook message
    def webhook?
      @discriminator == Message::ZERO_DISCRIM
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

  # OAuth Application information
  class Application
    include IDObject

    # @return [String] the application name
    attr_reader :name

    # @return [String] the application description
    attr_reader :description

    # @return [Array<String>] the applications origins permitted to use RPC
    attr_reader :rpc_origins

    # @return [Integer]
    attr_reader :flags

    # Gets the user object of the owner. May be limited to username, discriminator,
    # ID and avatar if the bot cannot reach the owner.
    # @return [User] the user object of the owner
    attr_reader :owner

    def initialize(data, bot)
      @bot = bot

      @name = data['name']
      @id = data['id'].to_i
      @description = data['description']
      @icon_id = data['icon']
      @rpc_origins = data['rpc_origins']
      @flags = data['flags']
      @owner = @bot.ensure_user(data['owner'])
    end

    # Utility function to get a application's icon URL.
    # @return [String, nil] the URL to the icon image (nil if no image is set).
    def icon_url
      return nil if @icon_id.nil?
      API.app_icon_url(@id, @icon_id)
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Application name=#{@name} id=#{@id}>"
    end
  end

  # Mixin for the attributes members and private members should have
  module MemberAttributes
    # @return [Time] when this member joined the server.
    attr_reader :joined_at

    # @return [String, nil] the nickname this member has, or nil if it has none.
    attr_reader :nick
    alias_method :nickname, :nick

    # @return [Array<Role>] the roles this member has.
    attr_reader :roles

    # @return [Server] the server this member is on.
    attr_reader :server
  end

  # Mixin to calculate resulting permissions from overrides etc.
  module PermissionCalculator
    # Checks whether this user can do the particular action, regardless of whether it has the permission defined,
    # through for example being the server owner or having the Manage Roles permission
    # @param action [Symbol] The permission that should be checked. See also {Permissions::Flags} for a list.
    # @param channel [Channel, nil] If channel overrides should be checked too, this channel specifies where the overrides should be checked.
    # @example Check if the bot can send messages to a specific channel in a server.
    #   bot_profile = bot.profile.on(event.server)
    #   can_send_messages = bot_profile.permission?(:send_messages, channel)
    # @return [true, false] whether or not this user has the permission.
    def permission?(action, channel = nil)
      # If the member is the server owner, it irrevocably has all permissions.
      return true if owner?

      # First, check whether the user has Manage Roles defined.
      # (Coincidentally, Manage Permissions is the same permission as Manage Roles, and a
      # Manage Permissions deny overwrite will override Manage Roles, so we can just check for
      # Manage Roles once and call it a day.)
      return true if defined_permission?(:administrator, channel)

      # Otherwise, defer to defined_permission
      defined_permission?(action, channel)
    end

    # Checks whether this user has a particular permission defined (i. e. not implicit, through for example
    # Manage Roles)
    # @param action [Symbol] The permission that should be checked. See also {Permissions::Flags} for a list.
    # @param channel [Channel, nil] If channel overrides should be checked too, this channel specifies where the overrides should be checked.
    # @example Check if a member has the Manage Channels permission defined in the server.
    #   has_manage_channels = member.defined_permission?(:manage_channels)
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

    alias_method :can_administrate?, :can_administrator?

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

  # A voice state represents the state of a member's connection to a voice channel. It includes data like the voice
  # channel the member is connected to and mute/deaf flags.
  class VoiceState
    # @return [Integer] the ID of the user whose voice state is represented by this object.
    attr_reader :user_id

    # @return [true, false] whether this voice state's member is muted server-wide.
    attr_reader :mute

    # @return [true, false] whether this voice state's member is deafened server-wide.
    attr_reader :deaf

    # @return [true, false] whether this voice state's member has muted themselves.
    attr_reader :self_mute

    # @return [true, false] whether this voice state's member has deafened themselves.
    attr_reader :self_deaf

    # @return [Channel] the voice channel this voice state's member is in.
    attr_reader :voice_channel

    # @!visibility private
    def initialize(user_id)
      @user_id = user_id
    end

    # Update this voice state with new data from Discord
    # @note For internal use only.
    # @!visibility private
    def update(channel, mute, deaf, self_mute, self_deaf)
      @voice_channel = channel
      @mute = mute
      @deaf = deaf
      @self_mute = self_mute
      @self_deaf = self_deaf
    end
  end

  # A presence represents a

  # A member is a user on a server. It differs from regular users in that it has roles, voice statuses and things like
  # that.
  class Member < DelegateClass(User)
    # @return [true, false] whether this member is muted server-wide.
    def mute
      voice_state_attribute(:mute)
    end

    # @return [true, false] whether this member is deafened server-wide.
    def deaf
      voice_state_attribute(:deaf)
    end

    # @return [true, false] whether this member has muted themselves.
    def self_mute
      voice_state_attribute(:self_mute)
    end

    # @return [true, false] whether this member has deafened themselves.
    def self_deaf
      voice_state_attribute(:self_deaf)
    end

    # @return [Channel] the voice channel this member is in.
    def voice_channel
      voice_state_attribute(:voice_channel)
    end

    alias_method :muted?, :mute
    alias_method :deafened?, :deaf
    alias_method :self_muted?, :self_mute
    alias_method :self_deafened?, :self_deaf

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

    # Bulk sets a member's roles.
    # @param role [Role, Array<Role>] The role(s) to set.
    def roles=(role)
      role_ids = role_id_array(role)
      API::Server.update_member(@bot.token, @server.id, @user.id, roles: role_ids)
    end

    # Adds and removes roles from a member.
    # @param add [Role, Array<Role>] The role(s) to add.
    # @param remove [Role, Array<Role>] The role(s) to remove.
    # @example Remove the 'Member' role from a user, and add the 'Muted' role to them.
    #   to_add = server.roles.find {|role| role.name == 'Muted'}
    #   to_remove = server.roles.find {|role| role.name == 'Member'}
    #   member.modify_roles(to_add, to_remove)
    def modify_roles(add, remove)
      add_role_ids = role_id_array(add)
      remove_role_ids = role_id_array(remove)
      old_role_ids = @roles.map(&:id)
      new_role_ids = (old_role_ids - remove_role_ids + add_role_ids).uniq

      API::Server.update_member(@bot.token, @server.id, @user.id, roles: new_role_ids)
    end

    # Adds one or more roles to this member.
    # @param role [Role, Array<Role>] The role(s) to add.
    def add_role(role)
      role_ids = role_id_array(role)
      old_role_ids = @roles.map(&:id)
      new_role_ids = (old_role_ids + role_ids).uniq

      API::Server.update_member(@bot.token, @server.id, @user.id, roles: new_role_ids)
    end

    # Removes one or more roles from this member.
    # @param role [Role, Array<Role>] The role(s) to remove.
    def remove_role(role)
      old_role_ids = @roles.map(&:id)
      role_ids = role_id_array(role)
      new_role_ids = old_role_ids.reject { |i| role_ids.include?(i) }

      API::Server.update_member(@bot.token, @server.id, @user.id, roles: new_role_ids)
    end

    # Server deafens this member.
    def server_deafen
      API::Server.update_member(@bot.token, @server.id, @user.id, deaf: true)
    end

    # Server undeafens this member.
    def server_undeafen
      API::Server.update_member(@bot.token, @server.id, @user.id, deaf: false)
    end

    # Server mutes this member.
    def server_mute
      API::Server.update_member(@bot.token, @server.id, @user.id, mute: true)
    end

    # Server unmutes this member.
    def server_unmute
      API::Server.update_member(@bot.token, @server.id, @user.id, mute: false)
    end

    # Sets or resets this member's nickname. Requires the Change Nickname permission for the bot itself and Manage
    # Nicknames for other users.
    # @param nick [String, nil] The string to set the nickname to, or nil if it should be reset.
    def nick=(nick)
      # Discord uses the empty string to signify 'no nickname' so we convert nil into that
      nick ||= ''

      if @user.current_bot?
        API::User.change_own_nickname(@bot.token, @server.id, nick)
      else
        API::Server.update_member(@bot.token, @server.id, @user.id, nick: nick)
      end
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

    # Utility method to get data out of this member's voice state
    def voice_state_attribute(name)
      voice_state = @server.voice_states[@user.id]
      voice_state.send name if voice_state
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

  # This class is a special variant of User that represents the bot's user profile (things like own username and the avatar).
  # It can be accessed using {Bot#profile}.
  class Profile < User
    def initialize(data, bot)
      super(data, bot)
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

    alias_method :name=, :username=

    # Changes the bot's avatar.
    # @param avatar [String, #read] A JPG file to be used as the avatar, either
    #  something readable (e. g. File Object) or as a data URL.
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
      @username = new_data[:username] || @username
      @avatar_id = new_data[:avatar_id] || @avatar_id
    end

    # Sets the user status setting to Online.
    # @note Only usable on User accounts.
    def online
      update_profile_status_setting('online')
    end

    # Sets the user status setting to Idle.
    # @note Only usable on User accounts.
    def idle
      update_profile_status_setting('idle')
    end

    # Sets the user status setting to Do Not Disturb.
    # @note Only usable on User accounts.
    def dnd
      update_profile_status_setting('dnd')
    end

    alias_method(:busy, :dnd)

    # Sets the user status setting to Invisible.
    # @note Only usable on User accounts.
    def invisible
      update_profile_status_setting('invisible')
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Profile user=#{super}>"
    end

    private

    # Internal handler for updating the user's status setting
    def update_profile_status_setting(status)
      API::User.change_status_setting(@bot.token, status)
    end

    def update_profile_data(new_data)
      API::User.update_profile(@bot.token,
                               nil, nil,
                               new_data[:username] || @username,
                               new_data.key?(:avatar) ? new_data[:avatar] : @avatar_id)
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

    # @return [Integer] the position of this role in the hierarchy
    attr_reader :position

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

      # The inspect method is overridden, in this case to prevent the token being leaked
      def inspect
        "<RoleWriter role=#{@role} token=...>"
      end
    end

    # @!visibility private
    def initialize(data, bot, server = nil)
      @bot = bot
      @server = server
      @permissions = Permissions.new(data['permissions'], RoleWriter.new(self, @bot.token))
      @name = data['name']
      @id = data['id'].to_i

      @position = data['position']

      @hoist = data['hoist']
      @mentionable = data['mentionable']

      @colour = ColourRGB.new(data['color'])
    end

    # @return [String] a string that will mention this role, if it is mentionable.
    def mention
      "<@&#{@id}>"
    end

    # @return [Array<Member>] an array of members who have this role.
    # @note This requests a member chunk if it hasn't for the server before, which may be slow initially
    def members
      @server.members.select { |m| m.role? role }
    end

    alias_method :users, :members

    # Updates the data cache from another Role object
    # @note For internal use only
    # @!visibility private
    def update_from(other)
      @permissions = other.permissions
      @name = other.name
      @hoist = other.hoist
      @colour = other.colour
      @position = other.position
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

    # Changes whether or not this role can be mentioned
    # @param mentionable [true, false] The value it should be changed to
    def mentionable=(mentionable)
      update_role_data(mentionable: mentionable)
    end

    # Sets the role colour to something new
    # @param colour [ColourRGB] The new colour
    def colour=(colour)
      update_role_data(colour: colour)
    end

    alias_method :color=, :colour=

    # Changes this role's permissions to a fixed bitfield. This allows setting multiple permissions at once with just
    # one API call.
    #
    # Information on how this bitfield is structured can be found at
    # https://discordapp.com/developers/docs/topics/permissions.
    # @example Remove all permissions from a role
    #   role.packed = 0
    # @param packed [Integer] A bitfield with the desired permissions value.
    # @param update_perms [true, false] Whether the internal data should also be updated. This should always be true
    #   when calling externally.
    def packed=(packed, update_perms = true)
      update_role_data(permissions: packed)
      @permissions.bits = packed if update_perms
    end

    # Deletes this role. This cannot be undone without recreating the role!
    def delete
      API::Server.delete_role(@bot.token, @server.id, @id)
      @server.delete_role(@id)
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Role name=#{@name} permissions=#{@permissions.inspect} hoist=#{@hoist} colour=#{@colour.inspect} server=#{@server.inspect}>"
    end

    private

    def update_role_data(new_data)
      API::Server.update_role(@bot.token, @server.id, @id,
                              new_data[:name] || @name,
                              (new_data[:colour] || @colour).combined,
                              new_data[:hoist].nil? ? @hoist : new_data[:hoist],
                              new_data[:mentionable].nil? ? @mentionable : new_data[:mentionable],
                              new_data[:permissions] || @permissions.bits)
      update_data(new_data)
    end
  end

  # A channel referenced by an invite. It has less data than regular channels, so it's a separate class
  class InviteChannel
    include IDObject

    # @return [String] this channel's name.
    attr_reader :name

    # @return [Integer] this channel's type (0: text, 1: private, 2: voice, 3: group).
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
    alias_method :max_uses, :uses

    # @return [User, nil] the user that made this invite. May also be nil if the user can't be determined.
    attr_reader :inviter
    alias_method :user, :inviter

    # @return [true, false] whether or not this invite is temporary.
    attr_reader :temporary
    alias_method :temporary?, :temporary

    # @return [true, false] whether this invite is still valid.
    attr_reader :revoked
    alias_method :revoked?, :revoked

    # @return [String] this invite's code
    attr_reader :code

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @channel = InviteChannel.new(data['channel'], bot)
      @server = InviteServer.new(data['guild'], bot)
      @uses = data['uses']
      @inviter = data['inviter'] ? (@bot.user(data['inviter']['id'].to_i) || User.new(data['inviter'], bot)) : nil
      @temporary = data['temporary']
      @revoked = data['revoked']

      @code = data['code']
    end

    # Code based comparison
    def ==(other)
      other.respond_to?(:code) ? (@code == other.code) : (@code == other)
    end

    # Deletes this invite
    def delete
      API::Invite.delete(@bot.token, @code)
    end

    alias_method :revoke, :delete

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Invite code=#{@code} channel=#{@channel} uses=#{@uses} temporary=#{@temporary} revoked=#{@revoked}>"
    end

    # Creates an invite URL.
    def url
      "https://discord.gg/#{@code}"
    end
  end

  # A Discord channel, including data like the topic
  class Channel
    include IDObject

    # @return [String] this channel's name.
    attr_reader :name

    # @return [Server, nil] the server this channel is on. If this channel is a PM channel, it will be nil.
    attr_reader :server

    # @return [Integer] the type of this channel (0: text, 1: private, 2: voice, 3: group)
    attr_reader :type

    # @return [Integer, nil] the id of the owner of the group channel or nil if this is not a group channel.
    attr_reader :owner_id

    # @return [Array<Recipient>, nil] the array of recipients of the private messages, or nil if this is not a Private channel
    attr_reader :recipients

    # @return [String] the channel's topic
    attr_reader :topic

    # @return [Integer] the bitrate (in bps) of the channel
    attr_reader :bitrate

    # @return [Integer] the amount of users that can be in the channel. `0` means it is unlimited.
    attr_reader :user_limit
    alias_method :limit, :user_limit

    # @return [Integer] the channel's position on the channel list
    attr_reader :position

    # This channel's permission overwrites, represented as a hash of role/user ID to an OpenStruct which has the
    # `allow` and `deny` properties which are {Permissions} objects respectively.
    # @return [Hash<Integer => OpenStruct>] the channel's permission overwrites
    attr_reader :permission_overwrites
    alias_method :overwrites, :permission_overwrites

    # @return [true, false] whether or not this channel is a PM or group channel.
    def private?
      pm? || group?
    end

    # @return [String] a string that will mention the channel as a clickable link on Discord.
    def mention
      "<##{@id}>"
    end

    # @return [Recipient, nil] the recipient of the private messages, or nil if this is not a PM channel
    def recipient
      @recipients.first if pm?
    end

    # @!visibility private
    def initialize(data, bot, server = nil)
      @bot = bot
      # data is a sometimes a Hash and other times an array of Hashes, you only want the last one if it's an array
      data = data[-1] if data.is_a?(Array)

      @id = data['id'].to_i
      @type = data['type'] || 0
      @topic = data['topic']
      @bitrate = data['bitrate']
      @user_limit = data['user_limit']
      @position = data['position']

      if private?
        @recipients = []
        if data['recipients']
          data['recipients'].each do |recipient|
            recipient_user = bot.ensure_user(recipient)
            @recipients << Recipient.new(recipient_user, self, bot)
          end
        end
        if pm?
          @name = @recipients.first.username
        else
          @name = data['name']
          @owner_id = data['owner_id']
        end
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
      @type.zero?
    end

    # @return [true, false] whether or not this channel is a PM channel.
    def pm?
      @type == 1
    end

    # @return [true, false] whether or not this channel is a voice channel.
    def voice?
      @type == 2
    end

    # @return [true, false] whether or not this channel is a group channel.
    def group?
      @type == 3
    end

    # Sends a message to this channel.
    # @param content [String] The content to send. Should not be longer than 2000 characters or it will result in an error.
    # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
    # @param embed [Hash, Discordrb::Webhooks::Embed, nil] The rich embed to append to this message.
    # @return [Message] the message that was sent.
    def send_message(content, tts = false, embed = nil)
      @bot.send_message(@id, content, tts, embed)
    end

    alias_method :send, :send_message

    # Sends a temporary message to this channel.
    # @param content [String] The content to send. Should not be longer than 2000 characters or it will result in an error.
    # @param timeout [Float] The amount of time in seconds after which the message sent will be deleted.
    # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
    # @param embed [Hash, Discordrb::Webhooks::Embed, nil] The rich embed to append to this message.
    def send_temporary_message(content, timeout, tts = false, embed = nil)
      @bot.send_temporary_message(@id, content, timeout, tts, embed)
    end

    # Convenience method to send a message with an embed.
    # @example Send a message with an embed
    #   channel.send_embed do |embed|
    #     embed.title = 'The Ruby logo'
    #     embed.image = Discordrb::Webhooks::EmbedImage.new(url: 'https://www.ruby-lang.org/images/header-ruby-logo.png')
    #   end
    # @param message [String] The message that should be sent along with the embed. If this is the empty string, only the embed will be shown.
    # @param embed [Discordrb::Webhooks::Embed, nil] The embed to start the building process with, or nil if one should be created anew.
    # @yield [embed] Yields the embed to allow for easy building inside a block.
    # @yieldparam embed [Discordrb::Webhooks::Embed] The embed from the parameters, or a new one.
    # @return [Message] The resulting message.
    def send_embed(message = '', embed = nil)
      embed ||= Discordrb::Webhooks::Embed.new
      yield(embed) if block_given?
      send_message(message, false, embed)
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

    # Deletes a message on this channel. Mostly useful in case a message needs to be deleted when only the ID is known
    # @param message [Message, String, Integer, #resolve_id] The message that should be deleted.
    def delete_message(message)
      API::Channel.delete_message(@bot.token, @id, message.resolve_id)
    end

    # Permanently deletes this channel
    def delete
      API::Channel.delete(@bot.token, @id)
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
      raise 'Tried to set topic on voice channel' if voice?
      @topic = topic
      update_channel_data
    end

    # Sets this channel's bitrate.
    # @param bitrate [Integer] The new bitrate (in bps). Number has to be between 8000-96000 (128000 for VIP servers)
    def bitrate=(bitrate)
      raise 'Tried to set bitrate on text channel' if text?
      @bitrate = bitrate
      update_channel_data
    end

    # Sets this channel's user limit.
    # @param limit [Integer] The new user limit. `0` for unlimited, has to be a number between 0-99
    def user_limit=(limit)
      raise 'Tried to set user_limit on text channel' if text?
      @user_limit = limit
      update_channel_data
    end

    alias_method :limit=, :user_limit=

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

      type = if thing.is_a?(User) || thing.is_a?(Member) || thing.is_a?(Recipient) || thing.is_a?(Profile)
               :member
             elsif thing.is_a? Role
               :role
             else
               raise ArgumentError, '`thing` in define_overwrite needs to be a kind of User (User, Member, Recipient, Profile) or a Role!'
             end

      API::Channel.update_permission(@bot.token, @id, thing.id, allow_bits, deny_bits, type)
    end

    # Deletes a permission overwrite for this channel
    # @param target [Member, User, Role, Profile, Recipient, #resolve_id] What permission overwrite to delete
    def delete_overwrite(target)
      raise 'Tried deleting a overwrite for an invalid target' unless target.is_a?(Member) || target.is_a?(User) || target.is_a?(Role) || target.is_a?(Profile) || target.is_a?(Recipient) || target.respond_to?(:resolve_id)

      API::Channel.delete_permission(@bot.token, @id, target.resolve_id)
    end

    # Updates the cached data from another channel.
    # @note For internal use only
    # @!visibility private
    def update_from(other)
      @topic = other.topic
      @name = other.name
      @position = other.position
      @topic = other.topic
      @recipients = other.recipients
      @bitrate = other.bitrate
      @user_limit = other.user_limit
      @permission_overwrites = other.permission_overwrites
    end

    # The list of users currently in this channel. For a voice channel, it will return all the members currently
    # in that channel. For a text channel, it will return all online members that have permission to read it.
    # @return [Array<Member>] the users in this channel
    def users
      if text?
        @server.online_members(include_idle: true).select { |u| u.can_read_messages? self }
      elsif voice?
        @server.voice_states.map { |id, voice_state| @server.member(id) if !voice_state.voice_channel.nil? && voice_state.voice_channel.id == @id }.compact
      end
    end

    # Retrieves some of this channel's message history.
    # @param amount [Integer] How many messages to retrieve. This must be less than or equal to 100, if it is higher
    #   than 100 it will be treated as 100 on Discord's side.
    # @param before_id [Integer] The ID of the most recent message the retrieval should start at, or nil if it should
    #   start at the current message.
    # @param after_id [Integer] The ID of the oldest message the retrieval should start at, or nil if it should start
    #   as soon as possible with the specified amount.
    # @example Count the number of messages in the last 50 messages that contain the letter 'e'.
    #   message_count = channel.history(50).count {|message| message.content.include? "e"}
    # @return [Array<Message>] the retrieved messages.
    def history(amount, before_id = nil, after_id = nil)
      logs = API::Channel.messages(@bot.token, @id, amount, before_id, after_id)
      JSON.parse(logs).map { |message| Message.new(message, @bot) }
    end

    # Retrieves message history, but only message IDs for use with prune
    # @note For internal use only
    # @!visibility private
    def history_ids(amount, before_id = nil, after_id = nil)
      logs = API::Channel.messages(@bot.token, @id, amount, before_id, after_id)
      JSON.parse(logs).map { |message| message['id'].to_i }
    end

    # Returns a single message from this channel's history by ID.
    # @param message_id [Integer] The ID of the message to retrieve.
    # @return [Message] the retrieved message.
    def load_message(message_id)
      response = API::Channel.message(@bot.token, @id, message_id)
      return Message.new(JSON.parse(response), @bot)
    rescue RestClient::ResourceNotFound
      return nil
    end

    alias_method :message, :load_message

    # Requests all pinned messages of a channel.
    # @return [Array<Message>] the received messages.
    def pins
      msgs = API::Channel.pinned_messages(@bot.token, @id)
      JSON.parse(msgs).map { |msg| Message.new(msg, @bot) }
    end

    # Delete the last N messages on this channel.
    # @param amount [Integer] How many messages to delete. Must be a value between 2 and 100 (Discord limitation)
    # @param strict [true, false] Whether an error should be raised when a message is reached that is too old to be bulk
    #   deleted. If this is false only a warning message will be output to the console.
    # @raise [ArgumentError] if the amount of messages is not a value between 2 and 100
    def prune(amount, strict = false)
      raise ArgumentError, 'Can only prune between 2 and 100 messages!' unless amount.between?(2, 100)

      messages = history_ids(amount)
      bulk_delete(messages, strict)
    end

    # Deletes a collection of messages
    # @param messages [Array<Message, Integer>] the messages (or message IDs) to delete. Total must be an amount between 2 and 100 (Discord limitation)
    # @param strict [true, false] Whether an error should be raised when a message is reached that is too old to be bulk
    #   deleted. If this is false only a warning message will be output to the console.
    # @raise [ArgumentError] if the amount of messages is not a value between 2 and 100
    def delete_messages(messages, strict = false)
      raise ArgumentError, 'Can only delete between 2 and 100 messages!' unless messages.count.between?(2, 100)

      messages.map!(&:resolve_id)
      bulk_delete(messages, strict)
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
    # @return [Invite] the created invite.
    def make_invite(max_age = 0, max_uses = 0, temporary = false)
      response = API::Channel.create_invite(@bot.token, @id, max_age, max_uses, temporary)
      Invite.new(JSON.parse(response), @bot)
    end

    alias_method :invite, :make_invite

    # Starts typing, which displays the typing indicator on the client for five seconds.
    # If you want to keep typing you'll have to resend this every five seconds. (An abstraction
    # for this will eventually be coming)
    def start_typing
      API::Channel.start_typing(@bot.token, @id)
    end

    # Creates a Group channel
    # @param user_ids [Array<Integer>] Array of user IDs to add to the new group channel (Excluding
    # the recipient of the PM channel).
    # @return [Channel] the created channel.
    def create_group(user_ids)
      raise 'Attempted to create group channel on a non-pm channel!' unless pm?
      response = API::Channel.create_group(@bot.token, @id, user_ids.shift)
      channel = Channel.new(JSON.parse(response), @bot)
      channel.add_group_users(user_ids)
    end

    # Adds a user to a Group channel
    # @param user_ids [Array<#resolve_id>, #resolve_id] User ID or array of user IDs to add to the group channel.
    # @return [Channel] the group channel.
    def add_group_users(user_ids)
      raise 'Attempted to add a user to a non-group channel!' unless group?
      user_ids = [user_ids] unless user_ids.is_a? Array
      user_ids.each do |user_id|
        API::Channel.add_group_user(@bot.token, @id, user_id.resolve_id)
      end
      self
    end

    alias_method :add_group_user, :add_group_users

    # Removes a user from a group channel.
    # @param user_ids [Array<#resolve_id>, #resolve_id] User ID or array of user IDs to remove from the group channel.
    # @return [Channel] the group channel.
    def remove_group_users(user_ids)
      raise 'Attempted to remove a user from a non-group channel!' unless group?
      user_ids = [user_ids] unless user_ids.is_a? Array
      user_ids.each do |user_id|
        API::Channel.remove_group_user(@bot.token, @id, user_id.resolve_id)
      end
      self
    end

    alias_method :remove_group_user, :remove_group_users

    # Leaves the group
    def leave_group
      raise 'Attempted to leave a non-group channel!' unless group?
      API::Channel.leave_group(@bot.token, @id)
    end

    alias_method :leave, :leave_group

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Channel name=#{@name} id=#{@id} topic=\"#{@topic}\" type=#{@type} position=#{@position} server=#{@server}>"
    end

    # Adds a recipient to a group channel.
    # @param recipient [Recipient] the recipient to add to the group
    # @raise [ArgumentError] if tried to add a non-recipient
    # @note For internal use only
    # @!visibility private
    def add_recipient(recipient)
      raise 'Tried to add recipient to a non-group channel' unless group?
      raise ArgumentError, 'Tried to add a non-recipient to a group' unless recipient.is_a?(Recipient)
      @recipients << recipient
    end

    # Removes a recipient from a group channel.
    # @param recipient [Recipient] the recipient to remove from the group
    # @raise [ArgumentError] if tried to remove a non-recipient
    # @note For internal use only
    # @!visibility private
    def remove_recipient(recipient)
      raise 'Tried to remove recipient from a non-group channel' unless group?
      raise ArgumentError, 'Tried to remove a non-recipient from a group' unless recipient.is_a?(Recipient)
      @recipients.delete(recipient)
    end

    private

    # For bulk_delete checking
    TWO_WEEKS = 86_400 * 14

    # Deletes a list of messages on this channel using bulk delete
    def bulk_delete(ids, strict = false)
      min_snowflake = IDObject.synthesise(Time.now - TWO_WEEKS)

      ids.reject! do |e|
        next unless e < min_snowflake

        message = "Attempted to bulk_delete message #{e} which is too old (min = #{min_snowflake})"
        raise ArgumentError, message if strict
        Discordrb::LOGGER.warn(message)
        false
      end

      API::Channel.bulk_delete_messages(@bot.token, @id, ids)
    end

    def update_channel_data
      API::Channel.update(@bot.token, @id, @name, @topic, @position, @bitrate, @user_limit)
    end
  end

  # An Embed object that is contained in a message
  # A freshly generated embed object will not appear in a message object
  # unless grabbed from its ID in a channel.
  class Embed
    # @return [Message] the message this embed object is contained in.
    attr_reader :message

    # @return [String] the URL this embed object is based on.
    attr_reader :url

    # @return [String, nil] the title of the embed object. `nil` if there is not a title
    attr_reader :title

    # @return [String, nil] the description of the embed object. `nil` if there is not a description
    attr_reader :description

    # @return [Symbol] the type of the embed object. Possible types are:
    #
    #   * `:link`
    #   * `:video`
    #   * `:image`
    attr_reader :type

    # @return [EmbedProvider, nil] the provider of the embed object. `nil` is there is not a provider
    attr_reader :provider

    # @return [EmbedThumbnail, nil] the thumbnail of the embed object. `nil` is there is not a thumbnail
    attr_reader :thumbnail

    # @return [EmbedAuthor, nil] the author of the embed object. `nil` is there is not an author
    attr_reader :author

    # @!visibility private
    def initialize(data, message)
      @message = message

      @url = data['url']
      @title = data['title']
      @type = data['type'].to_sym
      @description = data['description']
      @provider = data['provider'].nil? ? nil : EmbedProvider.new(data['provider'], self)
      @thumbnail = data['thumbnail'].nil? ? nil : EmbedThumbnail.new(data['thumbnail'], self)
      @author = data['author'].nil? ? nil : EmbedAuthor.new(data['author'], self)
    end
  end

  # An Embed thumbnail for the embed object
  class EmbedThumbnail
    # @return [Embed] the embed object this is based on.
    attr_reader :embed

    # @return [String] the CDN URL this thumbnail can be downloaded at.
    attr_reader :url

    # @return [String] the thumbnail's proxy URL - I'm not sure what exactly this does, but I think it has something to
    #   do with CDNs
    attr_reader :proxy_url

    # @return [Integer] the width of this thumbnail file, in pixels.
    attr_reader :width

    # @return [Integer] the height of this thumbnail file, in pixels.
    attr_reader :height

    # @!visibility private
    def initialize(data, embed)
      @embed = embed

      @url = data['url']
      @proxy_url = data['proxy_url']
      @width = data['width']
      @height = data['height']
    end
  end

  # An Embed provider for the embed object
  class EmbedProvider
    # @return [Embed] the embed object this is based on.
    attr_reader :embed

    # @return [String] the provider's name.
    attr_reader :name

    # @return [String, nil] the URL of the provider. `nil` is there is no URL
    attr_reader :url

    # @!visibility private
    def initialize(data, embed)
      @embed = embed

      @name = data['name']
      @url = data['url']
    end
  end

  # An Embed author for the embed object
  class EmbedAuthor
    # @return [Embed] the embed object this is based on.
    attr_reader :embed

    # @return [String] the author's name.
    attr_reader :name

    # @return [String, nil] the URL of the author's website. `nil` is there is no URL
    attr_reader :url

    # @!visibility private
    def initialize(data, embed)
      @embed = embed

      @name = data['name']
      @url = data['url']
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
    alias_method :text, :content
    alias_method :to_s, :content

    # @return [Member, User] the user that sent this message. (Will be a {Member} most of the time, it should only be a
    #   {User} for old messages when the author has left the server since then)
    attr_reader :author
    alias_method :user, :author
    alias_method :writer, :author

    # @return [Channel] the channel in which this message was sent.
    attr_reader :channel

    # @return [Time] the timestamp at which this message was sent.
    attr_reader :timestamp

    # @return [Time] the timestamp at which this message was edited. `nil` if the message was never edited.
    attr_reader :edited_timestamp
    alias_method :edit_timestamp, :edited_timestamp

    # @return [Array<User>] the users that were mentioned in this message.
    attr_reader :mentions

    # @return [Array<Role>] the roles that were mentioned in this message.
    attr_reader :role_mentions

    # @return [Array<Attachment>] the files attached to this message.
    attr_reader :attachments

    # @return [Array<Embed>] the embed objects contained in this message.
    attr_reader :embeds

    # @return [Hash<String, Reaction>] the reaction objects attached to this message keyed by the name of the reaction
    attr_reader :reactions

    # @return [true, false] whether the message used Text-To-Speech (TTS) or not.
    attr_reader :tts
    alias_method :tts?, :tts

    # @return [String] used for validating a message was sent
    attr_reader :nonce

    # @return [true, false] whether the message was edited or not.
    attr_reader :edited
    alias_method :edited?, :edited

    # @return [true, false] whether the message mentioned everyone or not.
    attr_reader :mention_everyone
    alias_method :mention_everyone?, :mention_everyone
    alias_method :mentions_everyone?, :mention_everyone

    # @return [true, false] whether the message is pinned or not.
    attr_reader :pinned
    alias_method :pinned?, :pinned

    # @return [Integer, nil] the webhook ID that sent this message, or nil if it wasn't sent through a webhook.
    attr_reader :webhook_id

    # The discriminator that webhook user accounts have.
    ZERO_DISCRIM = '0000'.freeze

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @content = data['content']
      @channel = bot.channel(data['channel_id'].to_i)
      @pinned = data['pinned']
      @tts = data['tts']
      @nonce = data['nonce']
      @mention_everyone = data['mention_everyone']

      @author = if data['author']
                  if data['author']['discriminator'] == ZERO_DISCRIM
                    # This is a webhook user! It would be pointless to try to resolve a member here, so we just create
                    # a User and return that instead.
                    Discordrb::LOGGER.debug("Webhook user: #{data['author']['id']}")
                    User.new(data['author'], @bot)
                  elsif @channel.private?
                    # Turn the message user into a recipient - we can't use the channel recipient
                    # directly because the bot may also send messages to the channel
                    Recipient.new(bot.user(data['author']['id'].to_i), @channel, bot)
                  else
                    member = @channel.server.member(data['author']['id'].to_i)

                    unless member
                      Discordrb::LOGGER.debug("Member with ID #{data['author']['id']} not cached (possibly left the server).")
                      member = @bot.user(data['author']['id'].to_i)
                    end

                    member
                  end
                end

      @webhook_id = data['webhook_id'].to_i if data['webhook_id']

      @timestamp = Time.parse(data['timestamp']) if data['timestamp']
      @edited_timestamp = data['edited_timestamp'].nil? ? nil : Time.parse(data['edited_timestamp'])
      @edited = !@edited_timestamp.nil?
      @id = data['id'].to_i

      @emoji = []

      @reactions = {}

      if data['reactions']
        data['reactions'].each do |element|
          @reactions[element['emoji']['name']] = Reaction.new(element)
        end
      end

      @mentions = []

      if data['mentions']
        data['mentions'].each do |element|
          @mentions << bot.ensure_user(element)
        end
      end

      @role_mentions = []

      # Role mentions can only happen on public servers so make sure we only parse them there
      if @channel.text?
        if data['mention_roles']
          data['mention_roles'].each do |element|
            @role_mentions << @channel.server.role(element.to_i)
          end
        end
      end

      @attachments = []
      @attachments = data['attachments'].map { |e| Attachment.new(e, self, @bot) } if data['attachments']

      @embeds = []
      @embeds = data['embeds'].map { |e| Embed.new(e, self) } if data['embeds']
    end

    # Replies to this message with the specified content.
    # @see Channel#send_message
    def reply(content)
      @channel.send_message(content)
    end

    # Edits this message to have the specified content instead.
    # You can only edit your own messages.
    # @param new_content [String] the new content the message should have.
    # @param new_embed [Hash, Discordrb::Webhooks::Embed, nil] The new embed the message should have. If nil the message will be changed to have no embed.
    # @return [Message] the resulting message.
    def edit(new_content, new_embed = nil)
      response = API::Channel.edit_message(@bot.token, @channel.id, @id, new_content, [], new_embed ? new_embed.to_hash : nil)
      Message.new(JSON.parse(response), @bot)
    end

    # Deletes this message.
    def delete
      API::Channel.delete_message(@bot.token, @channel.id, @id)
      nil
    end

    # Pins this message
    def pin
      API::Channel.pin_message(@bot.token, @channel.id, @id)
      @pinned = true
      nil
    end

    # Unpins this message
    def unpin
      API::Channel.unpin_message(@bot.token, @channel.id, @id)
      @pinned = false
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

    # @return [true, false] whether this message has been sent over a webhook.
    def webhook?
      !@webhook_id.nil?
    end

    # @!visibility private
    # @return [Array<String>] the emoji mentions found in the message
    def scan_for_emoji
      emoji = @content.split
      emoji = emoji.grep(/<:(?<name>\w+):(?<id>\d+)>?/)
      emoji
    end

    # @return [Array<Emoji>] the emotes that were used/mentioned in this message (Only returns Emoji the bot has access to, else nil).
    def emoji
      return if @content.nil?

      emoji = scan_for_emoji
      emoji.each do |element|
        @emoji << @bot.parse_mention(element)
      end
      @emoji
    end

    # Check if any emoji got used in this message
    # @return [true, false] whether or not any emoji got used
    def emoji?
      emoji = scan_for_emoji
      return true unless emoji.empty?
    end

    # Check if any reactions got used in this message
    # @return [true, false] whether or not this message has reactions
    def reactions?
      @reactions.any?
    end

    # Returns the reactions made by the current bot or user
    # @return [Array<Reaction>] the reactions
    def my_reactions
      @reactions.select(&:me)
    end

    # Reacts to a message
    # @param [String, #to_reaction] the unicode emoji, Emoji, or GlobalEmoji
    def create_reaction(reaction)
      reaction = reaction.to_reaction if reaction.respond_to?(:to_reaction)
      API::Channel.create_reaction(@bot.token, @channel.id, @id, reaction)
      nil
    end

    alias_method :react, :create_reaction

    # Returns the list of users who reacted with a certain reaction
    # @param [String, #to_reaction] the unicode emoji, Emoji, or GlobalEmoji
    # @return [Array<User>] the users who used this reaction
    def reacted_with(reaction)
      reaction = reaction.to_reaction if reaction.respond_to?(:to_reaction)
      response = JSON.parse(API::Channel.get_reactions(@bot.token, @channel.id, @id, reaction))
      response.map { |d| User.new(d, @bot) }
    end

    # Deletes a reaction made by a user on this message
    # @param [User, #resolve_id] the user who used this reaction
    # @param [String, #to_reaction] the reaction to remove
    def delete_reaction(user, reaction)
      reaction = reaction.to_reaction if reaction.respond_to?(:to_reaction)
      API::Channel.delete_user_reaction(@bot.token, @channel.id, @id, reaction, user.resolve_id)
    end

    # Delete's this clients reaction on this message
    # @param [String, #to_reaction] the reaction to remove
    def delete_own_reaction(reaction)
      reaction = reaction.to_reaction if reaction.respond_to?(:to_reaction)
      API::Channel.delete_own_reaction(@bot.token, @channel.id, @id, reaction)
    end

    # Removes all reactions from this message
    def delete_all_reactions
      API::Channel.delete_all_reactions(@bot.token, @channel.id, @id)
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Message content=\"#{@content}\" id=#{@id} timestamp=#{@timestamp} author=#{@author} channel=#{@channel}>"
    end
  end

  # A reaction to a message
  class Reaction
    # @return [Integer] the amount of users who have reacted with this reaction
    attr_reader :count

    # @return [true, false] whether the current bot or user used this reaction
    attr_reader :me
    alias_method :me?, :me

    # @return [Integer] the ID of the emoji, if it was custom
    attr_reader :id

    # @return [String] the name or unicode representation of the emoji
    attr_reader :name

    def initialize(data)
      @count = data['count']
      @me = data['me']
      @id = data['emoji']['id'].nil? ? nil : data['emoji']['id'].to_i
      @name = data['emoji']['name']
    end
  end

  # Server emoji
  class Emoji
    include IDObject

    # @return [String] the emoji name
    attr_reader :name

    # @return [Server] the server of this emoji
    attr_reader :server

    # @return [Array<Role>] roles this emoji is active for
    attr_reader :roles

    def initialize(data, bot, server)
      @bot = bot
      @roles = nil

      @name = data['name']
      @server = server
      @id = data['id'].nil? ? nil : data['id'].to_i

      process_roles(data['roles']) if server
    end

    # @return [String] the layout to mention it (or have it used) in a message
    def mention
      "<:#{@name}:#{@id}>"
    end

    alias_method :use, :mention
    alias_method :to_s, :mention

    # @return [String] the layout to use this emoji in a reaction
    def to_reaction
      "#{@name}:#{@id}"
    end

    # @return [String] the icon URL of the emoji
    def icon_url
      API.emoji_icon_url(@id)
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Emoji name=#{@name} id=#{@id}>"
    end

    # @!visibility private
    def process_roles(roles)
      @roles = []
      return unless roles
      roles.each do |role_id|
        role = server.role(role_id)
        @roles << role
      end
    end
  end

  # Emoji that is not tailored to a server
  class GlobalEmoji
    include IDObject

    # @return [String] the emoji name
    attr_reader :name

    # @return [Hash<Integer => Array<Role>>] roles this emoji is active for in every server
    attr_reader :role_associations

    def initialize(data, bot)
      @bot = bot
      @roles = nil

      @name = data.name
      @id = data.id
      @role_associations = Hash.new([])
      @role_associations[data.server.id] = data.roles
    end

    # @return [String] the layout to mention it (or have it used) in a message
    def mention
      "<:#{@name}:#{@id}>"
    end

    alias_method :use, :mention
    alias_method :to_s, :mention

    # @return [String] the layout to use this emoji in a reaction
    def to_reaction
      "#{@name}:#{@id}"
    end

    # @return [String] the icon URL of the emoji
    def icon_url
      API.emoji_icon_url(@id)
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<GlobalEmoji name=#{@name} id=#{@id}>"
    end

    # @!visibility private
    def process_roles(roles)
      new_roles = []
      return unless roles
      roles.each do
        role = server.role(role_id)
        new_roles << role
      end
      new_roles
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
      return nil unless @icon_id
      API.icon_url(@id, @icon_id)
    end
  end

  # Integration Account
  class IntegrationAccount
    # @return [String] this account's name.
    attr_reader :name

    # @return [Integer] this account's ID.
    attr_reader :id

    def initialize(data)
      @name = data['name']
      @id = data['id'].to_i
    end
  end

  # Server integration
  class Integration
    include IDObject

    # @return [String] the integration name
    attr_reader :name

    # @return [Server] the server the integration is linked to
    attr_reader :server

    # @return [User] the user the integration is linked to
    attr_reader :user

    # @return [Role, nil] the role that this integration uses for "subscribers"
    attr_reader :role

    # @return [true, false] whether emoticons are enabled
    attr_reader :emoticon
    alias_method :emoticon?, :emoticon

    # @return [String] the integration type (Youtube, Twitch, etc.)
    attr_reader :type

    # @return [true, false] whether the integration is enabled
    attr_reader :enabled

    # @return [true, false] whether the integration is syncing
    attr_reader :syncing

    # @return [IntegrationAccount] the integration account information
    attr_reader :account

    # @return [Time] the time the integration was synced at
    attr_reader :synced_at

    # @return [Symbol] the behaviour of expiring subscribers (:remove = Remove User from role; :kick = Kick User from server)
    attr_reader :expire_behaviour
    alias_method :expire_behavior, :expire_behaviour

    # @return [Integer] the grace period before subscribers expire (in days)
    attr_reader :expire_grace_period

    def initialize(data, bot, server)
      @bot = bot

      @name = data['name']
      @server = server
      @id = data['id'].to_i
      @enabled = data['enabled']
      @syncing = data['syncing']
      @type = data['type']
      @account = IntegrationAccount.new(data['account'])
      @synced_at = Time.parse(data['synced_at'])
      @expire_behaviour = [:remove, :kick][data['expire_behavior']]
      @expire_grace_period = data['expire_grace_period']
      @user = @bot.ensure_user(data['user'])
      @role = server.role(data['role_id']) || nil
      @emoticon = data['enable_emoticons']
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Integration name=#{@name} id=#{@id} type=#{@type} enabled=#{@enabled}>"
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

    # @return [Hash<Integer, Emoji>] a hash of all the emoji available on this server.
    attr_reader :emoji
    alias_method :emojis, :emoji

    # @return [true, false] whether or not this server is large (members > 100). If it is,
    # it means the members list may be inaccurate for a couple seconds after starting up the bot.
    attr_reader :large
    alias_method :large?, :large

    # @return [Array<Symbol>] the features of the server (eg. "INVITE_SPLASH")
    attr_reader :features

    # @return [Integer] the absolute number of members on this server, offline or not.
    attr_reader :member_count

    # @return [Symbol] the verification level of the server (:none = none, :low = 'Must have a verified email on their Discord account', :medium = 'Has to be registered with Discord for at least 5 minutes', :high = 'Has to be a member of this server for at least 10 minutes').
    attr_reader :verification_level

    # @return [Integer] the amount of time after which a voice user gets moved into the AFK channel, in seconds.
    attr_reader :afk_timeout

    # @return [Channel, nil] the AFK voice channel of this server, or nil if none is set
    attr_reader :afk_channel

    # @return [Hash<Integer => VoiceState>] the hash (user ID => voice state) of voice states of members on this server
    attr_reader :voice_states

    # @!visibility private
    def initialize(data, bot, exists = true)
      @bot = bot
      @owner_id = data['owner_id'].to_i
      @id = data['id'].to_i
      update_data(data)

      @large = data['large']
      @member_count = data['member_count']
      @verification_level = [:none, :low, :medium, :high][data['verification_level']]
      @splash_id = nil
      @embed = nil
      @features = data['features'].map { |element| element.downcase.to_sym }
      @members = {}
      @voice_states = {}
      @emoji = {}

      process_roles(data['roles'])
      process_emoji(data['emojis'])
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
    # @param id [Integer, String, #resolve_id] The role ID to look for.
    def role(id)
      id = id.resolve_id
      @roles.find { |e| e.id == id }
    end

    # Gets a member on this server based on user ID
    # @param id [Integer] The user ID to look for
    # @param request [true, false] Whether the member should be requested from Discord if it's not cached
    def member(id, request = true)
      id = id.resolve_id
      return @members[id] if member_cached?(id)
      return nil unless request

      member = @bot.member(self, id)
      @members[id] = member
    rescue
      nil
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

    # @return [Array<Integration>] an array of all the integrations connected to this server.
    def integrations
      integration = JSON.parse(API::Server.integrations(@bot.token, @id))
      integration.map { |element| Integration.new(element, @bot, self) }
    end

    # Cache @embed
    # @note For internal use only
    # @!visibility private
    def cache_embed
      @embed ||= JSON.parse(API::Server.resolve(@bot.token, @id))['embed_enabled']
    end

    # @return [true, false] whether or not the server has widget enabled
    def embed?
      cache_embed if @embed.nil?
      @embed
    end

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

    # @return [String, nil] the widget URL to the server that displays the amount of online members in a
    #   stylish way. `nil` if the widget is not enabled.
    def widget_url
      cache_embed if @embed.nil?
      return nil unless @embed
      API.widget_url(@id)
    end

    # @param style [Symbol] The style the picture should have. Possible styles are:
    #   * `:banner1` creates a rectangular image with the server name, member count and icon, a "Powered by Discord" message on the bottom and an arrow on the right.
    #   * `:banner2` creates a less tall rectangular image that has the same information as `banner1`, but the Discord logo on the right - together with the arrow and separated by a diagonal separator.
    #   * `:banner3` creates an image similar in size to `banner1`, but it has the arrow in the bottom part, next to the Discord logo and with a "Chat now" text.
    #   * `:banner4` creates a tall, almost square, image that prominently features the Discord logo at the top and has a "Join my server" in a pill-style button on the bottom. The information about the server is in the same format as the other three `banner` styles.
    #   * `:shield` creates a very small, long rectangle, of the style you'd find at the top of GitHub `README.md` files. It features a small version of the Discord logo at the left and the member count at the right.
    # @return [String, nil] the widget banner URL to the server that displays the amount of online members,
    #   server icon and server name in a stylish way. `nil` if the widget is not enabled.
    def widget_banner_url(style)
      return nil unless @embed
      cache_embed if @embed.nil?
      API.widget_url(@id, style)
    end

    # @return [String] the hexadecimal ID used to identify this server's splash image for their VIP invite page.
    def splash_id
      @splash_id ||= JSON.parse(API::Server.resolve(@bot.token, @id))['splash']
    end

    # @return [String, nil] the splash image URL for the server's VIP invite page.
    #   `nil` if there is no splash image.
    def splash_url
      splash_id if @splash_id.nil?
      return nil unless @splash_id
      API.splash_url(@id, @splash_id)
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

    # Updates a member's voice state
    # @note For internal use only
    # @!visibility private
    def update_voice_state(data)
      user_id = data['user_id'].to_i

      if data['channel_id']
        unless @voice_states[user_id]
          # Create a new voice state for the user
          @voice_states[user_id] = VoiceState.new(user_id)
        end

        # Update the existing voice state (or the one we just created)
        channel = @channels_by_id[data['channel_id'].to_i]
        @voice_states[user_id].update(
          channel,
          data['mute'],
          data['deaf'],
          data['self_mute'],
          data['self_deaf']
        )
      else
        # The user is not in a voice channel anymore, so delete its voice state
        @voice_states.delete(user_id)
      end
    end

    # Creates a channel on this server with the given name.
    # @param name [String] Name of the channel to create
    # @param type [Integer] Type of channel to create (0: text, 2: voice)
    # @return [Channel] the created channel.
    # @raise [ArgumentError] if type is not 0 or 2
    def create_channel(name, type = 0)
      raise ArgumentError, 'Channel type must be either 0 (text) or 2 (voice)!' unless [0, 2].include?(type)
      response = API::Server.create_channel(@bot.token, @id, name, type)
      Channel.new(JSON.parse(response), @bot)
    end

    # Creates a role on this server which can then be modified. It will be initialized (on Discord's side)
    # with the regular role defaults the client uses, i. e. name is "new role", permissions are the default,
    # colour is the default etc.
    # @return [Role] the created role.
    def create_role
      response = API::Server.create_role(@bot.token, @id)
      role = Role.new(JSON.parse(response), @bot, self)
      @roles << role
      role
    end

    # @return [Array<User>] a list of banned users on this server.
    def bans
      users = JSON.parse(API::Server.bans(@bot.token, @id))
      users.map { |e| User.new(e['user'], @bot) }
    end

    # Bans a user from this server.
    # @param user [User, #resolve_id] The user to ban.
    # @param message_days [Integer] How many days worth of messages sent by the user should be deleted.
    def ban(user, message_days = 0)
      API::Server.ban_user(@bot.token, @id, user.resolve_id, message_days)
    end

    # Unbans a previously banned user from this server.
    # @param user [User, #resolve_id] The user to unban.
    def unban(user)
      API::Server.unban_user(@bot.token, @id, user.resolve_id)
    end

    # Kicks a user from this server.
    # @param user [User, #resolve_id] The user to kick.
    def kick(user)
      API::Server.remove_member(@bot.token, @id, user.resolve_id)
    end

    # Forcibly moves a user into a different voice channel. Only works if the bot has the permission needed.
    # @param user [User, #resolve_id] The user to move.
    # @param channel [Channel, #resolve_id] The voice channel to move into.
    def move(user, channel)
      API::Server.update_member(@bot.token, @id, user.resolve_id, channel_id: channel.resolve_id)
    end

    # Deletes this server. Be aware that this is permanent and impossible to undo, so be careful!
    def delete
      API::Server.delete(@bot.token, @id)
    end

    # Leave the server
    def leave
      API::User.leave_server(@bot.token, @id)
    end

    # Transfers server ownership to another user.
    # @param user [User, #resolve_id] The user who should become the new owner.
    def owner=(user)
      API::Server.transfer_ownership(@bot.token, @id, user.resolve_id)
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

    # @return [true, false] whether this server has any emoji or not.
    def any_emoji?
      @emoji.any?
    end

    alias_method :has_emoji?, :any_emoji?
    alias_method :emoji?, :any_emoji?

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

      begin
        @afk_channel = @bot.channel(@afk_channel_id, self) if @afk_channel_id.nonzero? && (!@afk_channel || @afk_channel_id != @afk_channel.id)
      rescue Discordrb::Errors::NoPermission
        LOGGER.debug("AFK channel #{@afk_channel_id} on server #{@id} is unreachable, setting to nil even though one exists")
        @afk_channel = nil
      end
    end

    # Adds a channel to this server's cache
    # @note For internal use only
    # @!visibility private
    def add_channel(channel)
      @channels << channel
      @channels_by_id[channel.id] = channel
    end

    # Deletes a channel from this server's cache
    # @note For internal use only
    # @!visibility private
    def delete_channel(id)
      @channels.reject! { |e| e.id == id }
      @channels_by_id.delete(id)
    end

    # Updates the cached emoji data with new data
    # @note For internal use only
    # @!visibility private
    def update_emoji_data(new_data)
      @emoji = {}
      process_emoji(new_data['emojis'])
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Server name=#{@name} id=#{@id} large=#{@large} region=#{@region} owner=#{@owner} afk_channel_id=#{@afk_channel_id} afk_timeout=#{@afk_timeout}>"
    end

    private

    def update_server_data(new_data)
      API::Server.update(@bot.token, @id,
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

    def process_emoji(emoji)
      return if emoji.empty?
      emoji.each do |element|
        new_emoji = Emoji.new(element, @bot, self)
        @emoji[new_emoji.id] = new_emoji
      end
    end

    def process_members(members)
      return unless members
      members.each do |element|
        member = Member.new(element, self, @bot)
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
          user.update_presence(element)
        else
          LOGGER.warn "Rogue presence update! #{element['user']['id']} on #{@id}"
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
        update_voice_state(element)
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
