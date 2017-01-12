# frozen_string_literal: true

module Discordrb
  # List of permissions Discord uses
  class Permissions
    # This hash maps bit positions to logical permissions.
    # I'm not sure what the unlabeled bits are reserved for.
    Flags = {
      # Bit => Permission # Value
      0 => :create_instant_invite, # 1
      1 => :kick_members,          # 2
      2 => :ban_members,           # 4
      3 => :administrator,         # 8
      4 => :manage_channels,       # 16
      5 => :manage_server,         # 32
      6 => :add_reactions,         # 64
      # 7                          # 128
      # 8                          # 256
      # 9                          # 512
      10 => :read_messages,        # 1024
      11 => :send_messages,        # 2048
      12 => :send_tts_messages,    # 4096
      13 => :manage_messages,      # 8192
      14 => :embed_links,          # 16384
      15 => :attach_files,         # 32768
      16 => :read_message_history, # 65536
      17 => :mention_everyone,     # 131072
      18 => :use_external_emoji,   # 262144
      # 19                         # 524288
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

    Flags.each do |position, flag|
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

    alias_method :can_administrate=, :can_administrator=

    attr_reader :bits

    # Set the raw bitset of this permission object
    # @param bits [Integer] A number whose binary representation is the desired bitset.
    def bits=(bits)
      @bits = bits
      init_vars
    end

    # Initialize the instance variables based on the bitset.
    def init_vars
      Flags.each do |position, flag|
        flag_set = ((@bits >> position) & 0x1) == 1
        instance_variable_set "@#{flag}", flag_set
      end
    end

    # Create a new Permissions object either as a blank slate to add permissions to (for example for
    #   {Channel#define_overwrite}) or from existing bit data to read out.
    # @param bits [Integer] The permission bits that should be set from the beginning.
    # @param writer [RoleWriter] The writer that should be used to update data when a permission is set.
    def initialize(bits = 0, writer = nil)
      @writer = writer
      @bits = bits
      init_vars
    end
  end
end
