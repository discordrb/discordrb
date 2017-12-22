# frozen_string_literal: true

module Discordrb
  # List of permissions Discord uses
  class Permissions
    # @!macro [attach] add_flag
    #   @method can_$2=(value)
    #     Sets whether this resource can `$2`
    #     @param value [true, false]
    # @!macro [attach] add_flag
    #   @method $2
    #     @return [true, false] whether this resouce can `$2`
    def self.add_flag(position, flag)
      @@flags ||= {}
      @@flags[position] = flag

      attr_reader flag

      define_method "can_#{flag}=" do |value|
        new_bits = @bits
        if value
          new_bits |= (1 << position)
        else
          new_bits &= ~(1 << position)
        end
        @writer.write(new_bits) if @writer
        @bits = new_bits
        init_vars
      end
    end

    add_flag(0, :create_instant_invite)
    add_flag(1, :kick_members)
    add_flag(2, :ban_members)
    add_flag(3, :administrator)
    add_flag(4, :manage_channels)
    add_flag(5, :manage_server)
    add_flag(6, :add_reactions)
    add_flag(7, :view_audit_log)
    add_flag(10, :read_messages)
    add_flag(11, :send_messages)
    add_flag(12, :send_tts_messages)
    add_flag(13, :manage_messages)
    add_flag(14, :embed_links)
    add_flag(15, :attach_files)
    add_flag(16, :read_message_history)
    add_flag(17, :mention_everyone)
    add_flag(18, :use_external_emoji)
    add_flag(20, :connect)
    add_flag(21, :speak)
    add_flag(22, :mute_members)
    add_flag(23, :deafen_members)
    add_flag(24, :move_members)
    add_flag(25, :use_voice_activity)
    add_flag(26, :change_nickname)
    add_flag(27, :manage_nicknames)
    add_flag(28, :manage_roles)
    add_flag(29, :manage_webhooks)
    add_flag(30, :manage_emojis)

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
      @@flags.each do |position, flag|
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

      @@flags.each do |position, flag|
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
  end
end
