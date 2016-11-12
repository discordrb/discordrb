require 'json'

require 'discordrb/data'

# Support for Discord's RPC protocol
module Discordrb::RPC
  # Represents a user as sent over RPC.
  class RPCUser
    include Discordrb::IDObject
    include Discordrb::UserAttributes

    # @!visibility private
    def initialize(data)
      @username = data['username']
      @id = data['id'].to_i
      @discriminator = data['discriminator']
      @avatar_id = data['avatar']

      @bot_account = false
      @bot_account = true if data['bot']
    end
  end

  # The game the user is currently playing or streaming.
  class Activity
    # @return [String] the name of the played game.
    attr_reader :name

    # @return [Integer] the type of activity (0 = playing, 1 = Twitch streaming)
    attr_reader :type

    # @return [String, nil] the stream URL, or nil if no streaming is being done
    attr_reader :url

    # @!visibility private
    def initialize(data)
      @name = data['name']
      @type = data['type'].to_i
      @url = data['url']
    end
  end

  # Represents a member as sent over RPC, i. e. user, status, possibly nick,
  # and "activity".
  class RPCMember < DelegateClass(RPCUser)
    # @return [String, nil] this member's nickname, or nil if none is set.
    attr_reader :nick

    # @return [Symbol] the user's presence status (`:online`, `:idle`, or `:dnd`).
    attr_reader :status

    # @return [Activity, nil] the game the user is currently playing.
    attr_reader :activity

    # @!visibility private
    def initialize(data)
      @user = RPCUser.new(data['user'])
      super @user

      @nick = data['nick']
      @status = data['status'].to_sym
      @activity = Activity.new(data['activity']) if data['activity']
    end
  end

  # Represents a server as sent over RPC, without member data (i.e. only ID,
  # name, and icon URL).
  class RPCLightServer
    include Discordrb::IDObject
    include Discordrb::ServerAttributes

    # @return [String, nil] the URL to the server icon image, or nil if none exists.
    attr_reader :icon_url

    # @!visibility private
    def initialize(data)
      @id = data['id'].to_i
      @name = data['name']

      return unless data['icon_url']

      @icon_id = data['icon_url'].scan(/[0-9a-f]{32}/).first
      @icon_url = data['icon_url']
    end
  end

  # Represents a server as sent over RPC.
  class RPCServer < RPCLightServer
    # @return [Array<RPCMember>] the server's online members.
    attr_reader :members

    # @!visibility private
    def initialize(data)
      super data

      @members = data['members'].map { |e| RPCMember.new(e) }
    end
  end

  # Represents a message as sent over RPC.
  class RPCMessage
  end

  # Represents a voice state as sent over RPC.
  class RPCVoiceState
    include Discordrb::VoiceAttributes

    # @return [true, false] whether this user is suppressed.
    attr_reader :suppress

    # @!visibility private
    def initialize(data)
      @mute = data['mute']
      @deaf = data['deaf']
      @self_mute = data['self_mute']
      @self_deaf = data['self_deaf']
      @suppress = data['suppress']
    end
  end

  # A voice user's pan status.
  class Pan
    # @return [Float] how much this user is panned to the left.
    attr_reader :left

    # @return [Float] how much this user is panned to the right.
    attr_reader :right

    # @!visibility private
    def initialize(data)
      @left = data['left'].to_f
      @right = data['right'].to_f
    end
  end

  # Represents a user in a voice channel.
  class RPCVoiceUser < DelegateClass(RPCUser)
    # @return [String] the name the user shows up as in the voice channel.
    attr_reader :nick

    # @return [true, false] whether this user is muted.
    attr_reader :mute

    # @!visibility private
    def initialize(data)
      @user = RPCUser.new(data['user'])
      super @user

      @nick = data['nick']
      @mute = data['mute']
      @volume = data['volume']

      @pan = Pan.new(data['pan'])
      @voice_state = RPCVoiceState.new(data['pan'])
    end
  end

  # Represents a channel as sent over RPC.
  class RPCChannel
  end
end
