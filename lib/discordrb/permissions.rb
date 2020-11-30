# frozen_string_literal: true

module Discordrb
  # List of permissions Discord uses
  class Permissions
    # This hash maps bit positions to logical permissions.
    FLAGS = {
      # Bit => Permission # Value
      0 => :create_instant_invite, # 1
      1 => :kick_members,          # 2
      2 => :ban_members,           # 4
      3 => :administrator,         # 8
      4 => :manage_channels,       # 16
      5 => :manage_server,         # 32
      6 => :add_reactions,         # 64
      7 => :view_audit_log,        # 128
      8 => :priority_speaker,      # 256
      9 => :stream,                # 512
      10 => :read_messages,        # 1024
      11 => :send_messages,        # 2048
      12 => :send_tts_messages,    # 4096
      13 => :manage_messages,      # 8192
      14 => :embed_links,          # 16384
      15 => :attach_files,         # 32768
      16 => :read_message_history, # 65536
      17 => :mention_everyone,     # 131072
      18 => :use_external_emoji,   # 262144
      19 => :view_server_insights, # 524288
      20 => :connect,              # 1048576
      21 => :speak,                # 2097152
      22 => :mute_members,         # 4194304
      23 => :deafen_members,       # 8388608
      24 => :move_members,         # 16777216
      25 => :use_voice_activity,   # 33554432
      26 => :change_nickname,      # 67108864
      27 => :manage_nicknames,     # 134217728
      28 => :manage_roles,         # 268435456, also Manage Permissions
      29 => :manage_webhooks,      # 536870912
      30 => :manage_emojis         # 1073741824
    }.freeze

    FLAGS.each do |position, flag|
      attr_reader flag

      define_method "can_#{flag}=" do |value|
        new_bits = @bits
        if value
          new_bits |= (1 << position)
        else
          new_bits &= ~(1 << position)
        end
        @writer&.write(new_bits)
        @bits = new_bits
        init_vars
      end
    end

    alias_method :can_administrate=, :can_administrator=
    alias_method :administrate, :administrator

    attr_reader :bits

    # Set the raw bitset of this permission object
    # @param bits [Integer] A number whose binary representation is the desired bitset.
    def bits=(bits)
      @bits = bits
      init_vars
    end

    # Initialize the instance variables based on the bitset.
    def init_vars
      FLAGS.each do |position, flag|
        flag_set = ((@bits >> position) & 0x1) == 1
        instance_variable_set "@#{flag}", flag_set
      end
    end

    # Return the corresponding bits for an array of permission flag symbols.
    # This is a class method that can be used to calculate bits instead
    # of instancing a new Permissions object.
    # @example Get the bits for permissions that could allow/deny read messages, connect, and speak
    #   Permissions.bits [:read_messages, :connect, :speak] #=> 3146752
    # @param list [Array<Symbol>]
    # @return [Integer] the computed permissions integer
    def self.bits(list)
      value = 0

      FLAGS.each do |position, flag|
        value += 2**position if list.include? flag
      end

      value
    end

    # Create a new Permissions object either as a blank slate to add permissions to (for example for
    #   {Channel#define_overwrite}) or from existing bit data to read out.
    # @example Create a permissions object that could allow/deny read messages, connect, and speak by setting flags
    #   permission = Permissions.new
    #   permission.can_read_messages = true
    #   permission.can_connect = true
    #   permission.can_speak = true
    # @example Create a permissions object that could allow/deny read messages, connect, and speak by an array of symbols
    #   Permissions.new [:read_messages, :connect, :speak]
    # @param bits [Integer, Array<Symbol>] The permission bits that should be set from the beginning, or an array of permission flag symbols
    # @param writer [RoleWriter] The writer that should be used to update data when a permission is set.
    def initialize(bits = 0, writer = nil)
      @writer = writer

      @bits = if bits.is_a? Array
                self.class.bits(bits)
              else
                bits
              end

      init_vars
    end

    # Comparison based on permission bits
    def ==(other)
      false unless other.is_a? Discordrb::Permissions
      bits == other.bits
    end
  end

  # Mixin to calculate resulting permissions from overrides etc.
  module PermissionCalculator
    # Checks whether this user can do the particular action, regardless of whether it has the permission defined,
    # through for example being the server owner or having the Manage Roles permission
    # @param action [Symbol] The permission that should be checked. See also {Permissions::FLAGS} for a list.
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

    # Checks whether this user has a particular permission defined (i.e. not implicit, through for example
    # Manage Roles)
    # @param action [Symbol] The permission that should be checked. See also {Permissions::FLAGS} for a list.
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
    Discordrb::Permissions::FLAGS.each_value do |flag|
      define_method "can_#{flag}?" do |channel = nil|
        permission? flag, channel
      end
    end

    alias_method :can_administrate?, :can_administrator?

    private

    def defined_role_permission?(action, channel)
      roles_to_check = [@server.everyone_role] + @roles

      # For each role, check if
      #   (1) the channel explicitly allows or permits an action for the role and
      #   (2) if the user is allowed to do the action if the channel doesn't specify
      roles_to_check.sort_by(&:position).reduce(false) do |can_act, role|
        # Get the override defined for the role on the channel
        channel_allow = permission_overwrite(action, channel, role.id)
        if channel_allow
          # If the channel has an override, check whether it is an allow - if yes,
          # the user can act, if not, it can't
          break true if channel_allow == :allow

          false
        else
          # Otherwise defer to the role
          role.permissions.instance_variable_get("@#{action}") || can_act
        end
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
end
