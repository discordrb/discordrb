# frozen_string_literal: true

module Discordrb
  # Mixin for the attributes members and private members should have
  module MemberAttributes
    # @return [Time] when this member joined the server.
    attr_reader :joined_at

    # @return [Time, nil] when this member boosted this server, `nil` if they haven't.
    attr_reader :boosting_since

    # @return [String, nil] the nickname this member has, or `nil` if it has none.
    attr_reader :nick
    alias_method :nickname, :nick

    # @return [Array<Role>] the roles this member has.
    attr_reader :roles

    # @return [Server] the server this member is on.
    attr_reader :server
  end

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
      @boosting_since = data['premium_since'] ? Time.parse(data['premium_since']) : nil
    end

    # @return [true, false] if this user is a Nitro Booster of this server.
    def boosting?
      !@boosting_since.nil?
    end

    # @return [true, false] whether this member is the server owner.
    def owner?
      @server.owner == self
    end

    # @param role [Role, String, Integer] the role to check or its ID.
    # @return [true, false] whether this member has the specified role.
    def role?(role)
      role = role.resolve_id
      @roles.any? { |e| e.id == role }
    end

    # @see Member#set_roles
    def roles=(role)
      set_roles(role)
    end

    # Bulk sets a member's roles.
    # @param role [Role, Array<Role>] The role(s) to set.
    # @param reason [String] The reason the user's roles are being changed.
    def set_roles(role, reason = nil)
      role_ids = role_id_array(role)
      API::Server.update_member(@bot.token, @server.id, @user.id, roles: role_ids, reason: reason)
    end

    # Adds and removes roles from a member.
    # @param add [Role, Array<Role>] The role(s) to add.
    # @param remove [Role, Array<Role>] The role(s) to remove.
    # @param reason [String] The reason the user's roles are being changed.
    # @example Remove the 'Member' role from a user, and add the 'Muted' role to them.
    #   to_add = server.roles.find {|role| role.name == 'Muted'}
    #   to_remove = server.roles.find {|role| role.name == 'Member'}
    #   member.modify_roles(to_add, to_remove)
    def modify_roles(add, remove, reason = nil)
      add_role_ids = role_id_array(add)
      remove_role_ids = role_id_array(remove)
      old_role_ids = @roles.map(&:id)
      new_role_ids = (old_role_ids - remove_role_ids + add_role_ids).uniq

      API::Server.update_member(@bot.token, @server.id, @user.id, roles: new_role_ids, reason: reason)
    end

    # Adds one or more roles to this member.
    # @param role [Role, Array<Role, String, Integer>, String, Integer] The role(s), or their ID(s), to add.
    # @param reason [String] The reason the user's roles are being changed.
    def add_role(role, reason = nil)
      role_ids = role_id_array(role)

      if role_ids.count == 1
        API::Server.add_member_role(@bot.token, @server.id, @user.id, role_ids[0], reason)
      else
        old_role_ids = @roles.map(&:id)
        new_role_ids = (old_role_ids + role_ids).uniq
        API::Server.update_member(@bot.token, @server.id, @user.id, roles: new_role_ids, reason: reason)
      end
    end

    # Removes one or more roles from this member.
    # @param role [Role, Array<Role>] The role(s) to remove.
    # @param reason [String] The reason the user's roles are being changed.
    def remove_role(role, reason = nil)
      role_ids = role_id_array(role)

      if role_ids.count == 1
        API::Server.remove_member_role(@bot.token, @server.id, @user.id, role_ids[0], reason)
      else
        old_role_ids = @roles.map(&:id)
        new_role_ids = old_role_ids.reject { |i| role_ids.include?(i) }
        API::Server.update_member(@bot.token, @server.id, @user.id, roles: new_role_ids, reason: reason)
      end
    end

    # @return [Role] the highest role this member has.
    def highest_role
      @roles.max_by(&:position)
    end

    # @return [Role, nil] the role this member is being hoisted with.
    def hoist_role
      hoisted_roles = @roles.select(&:hoist)
      return nil if hoisted_roles.empty?

      hoisted_roles.max_by(&:position)
    end

    # @return [Role, nil] the role this member is basing their colour on.
    def colour_role
      coloured_roles = @roles.select { |v| v.colour.combined.nonzero? }
      return nil if coloured_roles.empty?

      coloured_roles.max_by(&:position)
    end
    alias_method :color_role, :colour_role

    # @return [ColourRGB, nil] the colour this member has.
    def colour
      return nil unless colour_role

      colour_role.color
    end
    alias_method :color, :colour

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

    # @see Member#set_nick
    def nick=(nick)
      set_nick(nick)
    end

    alias_method :nickname=, :nick=

    # Sets or resets this member's nickname. Requires the Change Nickname permission for the bot itself and Manage
    # Nicknames for other users.
    # @param nick [String, nil] The string to set the nickname to, or nil if it should be reset.
    # @param reason [String] The reason the user's nickname is being changed.
    def set_nick(nick, reason = nil)
      # Discord uses the empty string to signify 'no nickname' so we convert nil into that
      nick ||= ''

      if @user.current_bot?
        API::User.change_own_nickname(@bot.token, @server.id, nick, reason)
      else
        API::Server.update_member(@bot.token, @server.id, @user.id, nick: nick, reason: nil)
      end
    end

    alias_method :set_nickname, :set_nick

    # @return [String] the name the user displays as (nickname if they have one, username otherwise)
    def display_name
      nickname || username
    end

    # Update this member's roles
    # @note For internal use only.
    # @!visibility private
    def update_roles(role_ids)
      @roles = [@server.role(@server.id)]
      role_ids.each do |id|
        # It is possible for members to have roles that do not exist
        # on the server any longer. See https://github.com/shardlab/discordrb/issues/371
        role = @server.role(id)
        @roles << role if role
      end
    end

    # Update this member's nick
    # @note For internal use only.
    # @!visibility private
    def update_nick(nick)
      @nick = nick
    end

    # Update this member's boosting timestamp
    # @note For internal user only.
    # @!visibility private
    def update_boosting_since(time)
      @boosting_since = time
    end

    # Update this member
    # @note For internal use only.
    # @!visibility private
    def update_data(data)
      update_roles(data['roles']) if data['roles']
      update_nick(data['nick']) if data.key?('nick')
      @mute = data['mute'] if data.key?('mute')
      @deaf = data['deaf'] if data.key?('deaf')

      @joined_at = Time.parse(data['joined_at']) if data['joined_at']
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
      voice_state&.send name
    end
  end
end
