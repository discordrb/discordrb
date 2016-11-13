require 'json'
require 'time'

require 'discordrb/data'
require 'discordrb/api'

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
    include Discordrb::IDObject

    # @return [true, false] whether this message was sent by a blocked user (content hidden by default).
    attr_reader :blocked
    alias_method :blocked?, :blocked

    # @return [String] the message's content.
    attr_reader :content

    # @return [ColourRGB, nil] the colour the username shows up as on the client, or nil if it is the default colour.
    attr_reader :author_colour

    # @return [Time] the timestamp when this message was sent.
    attr_reader :timestamp

    # @return [true, false] whether this message is a text-to-speech message.
    attr_reader :tts
    alias_method :tts?, :tts

    # @return [Array<Integer>] the IDs of users that have been mentioned.
    attr_reader :mentions

    # @return [Array<Integer>] the IDs of roles that have been mentioned.
    attr_reader :mention_roles

    # @return [Array<Embed>] this message's embeds.
    attr_reader :embeds

    # @return [Array<Attachment>] this message's attachments.
    attr_reader :attachments

    # @return [RPCUser] the user that sent this message.
    attr_reader :author

    # @return [String, nil] the nickname the author has, if there is one.
    attr_reader :nick

    # @return [true, false] whether this message is pinned to the channel it is in.
    attr_reader :pinned
    alias_method :pinned?, :pinned

    # @return [Integer] the type this message is (0 = regular, 6 = pin notification, etc.)
    attr_reader :type

    # @!visibility private
    def initialize(data)
      @id = data['id'].to_i
      @blocked = data['blocked']
      # @bot = data['bot'] - unsure what this does, was always nil for me

      @content = data['content']
      # TODO: content_parsed

      @author_colour = Discordrb::ColourRGB.new(data['author_color'][1..-1].to_i(16)) if data['author_color']
      @timestamp = Time.parse(data['timestamp'])
      @tts = data['tts']

      @mentions = data['mentions'].map(&:to_i)
      @mention_roles = data['mention_roles'].map(&:to_i)

      @embeds = data['embeds'].map { |e| Discordrb::Embed.new(e, self) }
      @attachments = data['attachments'].map { |e| Discordrb::Attachment.new(e, self) }

      @author = RPCUser.new(data['author'])
      @nick = data['nick']
      @pinned = data['pinned']
      @type = data['type']
    end
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

    # @return [Integer] the user's relative volume, where 100 is default.
    attr_reader :volume

    # @return [Pan] this user's pan status.
    attr_reader :pan

    # @return [RPCVoiceState] this user's voice state.
    attr_reader :voice_state

    # @!visibility private
    def initialize(data)
      @user = RPCUser.new(data['user'])
      super @user

      @nick = data['nick']
      @mute = data['mute']
      @volume = data['volume']

      @pan = Pan.new(data['pan'])
      @voice_state = RPCVoiceState.new(data['voice_state'])
    end
  end

  # Represents a channel as sent over RPC.
  class RPCChannel
    include Discordrb::IDObject

    # @return [String] the channel's name (without a prefixed #), empty if not applicable.
    attr_reader :name

    # @return [String] the channel's topic, empty if not applicable.
    attr_reader :topic

    # @return [Integer] the channel's numeric type.
    attr_reader :type

    # @return [Integer] the channel's bitrate in bits per second, 0 if not applicable.
    attr_reader :bitrate

    # @return [Integer] the channel's user limit, 0 if not applicable.
    attr_reader :user_limit

    # @return [Integer, nil] the channel's server ID, `nil` if not applicable.
    attr_reader :server_id

    # @return [Integer] the channel's position on the server, 0 if not applicable.
    attr_reader :position

    # @return [Array<RPCMessage>] the last 50 messages on this channel, empty if not applicable.
    attr_reader :messages

    # @return [Array<RPCVoiceUser>] the users in this voice channel, empty if not applicable.
    attr_reader :voice_states
    alias_method :voice_users, :voice_states

    # @!visibility private
    def initialize(data)
      @id = data['id'].to_i
      @name = data['name']
      @type = data['type']
      @topic = data['topic']
      @bitrate = data['bitrate']
      @user_limit = data['user_limit']
      @server_id = data['guild_id'].to_i
      @position = data['position']

      @messages = data['messages'].map { |e| RPCMessage.new(e) }
      @voice_states = data['voice_states'].map { |e| RPCVoiceUser.new(e) }
    end
  end

  # Represents an OAuth2 application as sent over RPC
  class RPCApplication
    include Discordrb::IDObject

    # @return [String] this application's description as set in the settings.
    attr_reader :description

    # @return [String] the hexadecimal ID that identifies the application's icon.
    attr_reader :icon_id

    # @return [Array<String>] the permitted RPC origins.
    attr_reader :rpc_origins

    # @return [String] this application's name.
    attr_reader :name

    # @!visibililty private
    def initialize(data)
      @description = data['description']
      @icon_id = data['icon_id']
      @id = data['id'].to_i
      @rpc_origins = data['rpc_origins']
      @name = data['name']
    end

    # Utility function to get a application's icon URL.
    # @return [String, nil] the URL to the icon image (nil if no image is set).
    def icon_url
      return nil if @icon_id.nil?
      Discordrb::API.app_icon_url(@id, @icon_id)
    end
  end

  # A response to a RPC AUTHENTICATE request.
  class AuthenticateResponse
  end
end
