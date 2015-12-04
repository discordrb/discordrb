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
      3 => :manage_roles,          # 8
      4 => :manage_channels,       # 16
      5 => :manage_server,         # 32
      # 6                          # 64
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
      # 18                         # 262144
      # 19                         # 524288
      20 => :connect,              # 1048576
      21 => :speak,                # 2097152
      22 => :mute_members,         # 4194304
      23 => :deafen_members,       # 8388608
      24 => :move_members,         # 16777216
      25 => :use_voice_activity    # 33554432
    }

    Flags.each do |position, flag|
      attr_reader flag
      define_method "can_#{flag}=" do |value|
        if @writer
          new_bits = @bits
          if value
            new_bits |= (1 << position)
          else
            new_bits &= ~(1 << position)
          end
          @writer.write(new_bits)
          @bits = new_bits
          init_vars
        end
      end
    end

    attr_reader :bits

    def bits=(bits)
      @bits = bits
      init_vars
    end

    def init_vars
      Flags.each do |position, flag|
        flag_set = ((@bits >> position) & 0x1) == 1
        instance_variable_set "@#{flag}", flag_set
      end
    end

    def initialize(bits, writer = nil)
      @writer = writer
      @bits = bits
      init_vars
    end
  end
end
