# frozen_string_literal: true

module Discordrb
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
    # @return [InviteChannel, Channel] the channel this invite references.
    attr_reader :channel

    # @return [InviteServer, Server] the server this invite references.
    attr_reader :server

    # @return [Integer] the amount of uses left on this invite.
    attr_reader :uses
    alias_method :max_uses, :uses

    # @return [User, nil] the user that made this invite. May also be nil if the user can't be determined.
    attr_reader :inviter
    alias_method :user, :inviter

    # @return [true, false] whether or not this invite grants temporary membership. If someone joins a server with this invite, they will be removed from the server when they go offline unless they've received a role.
    attr_reader :temporary
    alias_method :temporary?, :temporary

    # @return [true, false] whether this invite is still valid.
    attr_reader :revoked
    alias_method :revoked?, :revoked

    # @return [String] this invite's code
    attr_reader :code

    # @return [Integer, nil] the amount of members in the server. Will be nil if it has not been resolved.
    attr_reader :member_count
    alias_method :user_count, :member_count

    # @return [Integer, nil] the amount of online members in the server. Will be nil if it has not been resolved.
    attr_reader :online_member_count
    alias_method :online_user_count, :online_member_count

    # @return [Integer, nil] the invites max age before it expires, or nil if it's unknown. If the max age is 0, the invite will never expire unless it's deleted.
    attr_reader :max_age

    # @return [Time, nil] when this invite was created, or nil if it's unknown
    attr_reader :created_at

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @channel = if data['channel_id']
                   bot.channel(data['channel_id'])
                 else
                   InviteChannel.new(data['channel'], bot)
                 end

      @server = if data['guild_id']
                  bot.server(data['guild_id'])
                else
                  InviteServer.new(data['guild'], bot)
                end

      @uses = data['uses']
      @inviter = data['inviter'] ? (@bot.user(data['inviter']['id'].to_i) || User.new(data['inviter'], bot)) : nil
      @temporary = data['temporary']
      @revoked = data['revoked']
      @online_member_count = data['approximate_presence_count']
      @member_count = data['approximate_member_count']
      @max_age = data['max_age']
      @created_at = data['created_at']

      @code = data['code']
    end

    # Code based comparison
    def ==(other)
      other.respond_to?(:code) ? (@code == other.code) : (@code == other)
    end

    # Deletes this invite
    # @param reason [String] The reason the invite is being deleted.
    def delete(reason = nil)
      API::Invite.delete(@bot.token, @code, reason)
    end

    alias_method :revoke, :delete

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Invite code=#{@code} channel=#{@channel} uses=#{@uses} temporary=#{@temporary} revoked=#{@revoked} created_at=#{@created_at} max_age=#{@max_age}>"
    end

    # Creates an invite URL.
    def url
      "https://discord.gg/#{@code}"
    end
  end
end
