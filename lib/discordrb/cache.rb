# frozen_string_literal: true

require 'discordrb/api'
require 'discordrb/api/server'
require 'discordrb/api/invite'
require 'discordrb/api/user'
require 'discordrb/data'

module Discordrb
  # This mixin module does caching stuff for the library. It conveniently separates the logic behind
  # the caching (like, storing the user hashes or making API calls to retrieve things) from the Bot that
  # actually uses it.
  module Cache
    # Initializes this cache
    def init_cache
      @users = {}

      @servers = {}

      @channels = {}
      @pm_channels = {}

      @restricted_channels = []
    end

    # Gets a channel given its ID. This queries the internal channel cache, and if the channel doesn't
    # exist in there, it will get the data from Discord.
    # @param id [Integer] The channel ID for which to search for.
    # @param server [Server] The server for which to search the channel for. If this isn't specified, it will be
    #   inferred using the API
    # @return [Channel] The channel identified by the ID.
    def channel(id, server = nil)
      id = id.resolve_id

      raise Discordrb::Errors::NoPermission if @restricted_channels.include? id

      debug("Obtaining data for channel with id #{id}")
      return @channels[id] if @channels[id]

      begin
        begin
          response = API::Channel.resolve(token, id)
        rescue RestClient::ResourceNotFound
          return nil
        end
        channel = Channel.new(JSON.parse(response), self, server)
        @channels[id] = channel
      rescue Discordrb::Errors::NoPermission
        debug "Tried to get access to restricted channel #{id}, blacklisting it"
        @restricted_channels << id
        raise
      end
    end

    alias_method :group_channel, :channel

    # Gets a user by its ID.
    # @note This can only resolve users known by the bot (i.e. that share a server with the bot).
    # @param id [Integer] The user ID that should be resolved.
    # @return [User, nil] The user identified by the ID, or `nil` if it couldn't be found.
    def user(id)
      resolve_cache(id, @users, 'User')
    end

    # Gets a server by its ID.
    # @note This can only resolve servers the bot is currently in.
    # @param id [Integer] The server ID that should be resolved.
    # @return [Server, nil] The server identified by the ID, or `nil` if it couldn't be found.
    def server(id)
      resolve_cache(id, @servers, 'Server')
    end

    # Gets a member by both IDs, or `Server` and user ID.
    # @param server_or_id [Server, Integer] The `Server` or server ID for which a member should be resolved
    # @param user_id [Integer] The ID of the user that should be resolved
    # @return [Member, nil] The member identified by the IDs, or `nil` if none could be found
    def member(server_or_id, user_id)
      server_id = server_or_id.resolve_id
      user_id = user_id.resolve_id

      server = server_or_id.is_a?(Server) ? server_or_id : self.server(server_id)

      return server.member(user_id) if server.member_cached?(user_id)

      LOGGER.out("Resolving member #{user_id} on server #{server_id}")
      begin
        response = API::Server.resolve_member(token, server_id, user_id)
      rescue RestClient::ResourceNotFound
        return nil
      end
      member = Member.new(JSON.parse(response), server, self)
      server.cache_member(member)
    end

    # Creates a PM channel for the given user ID, or if one exists already, returns that one.
    # It is recommended that you use {User#pm} instead, as this is mainly for internal use. However,
    # usage of this method may be unavoidable if only the user ID is known.
    # @param id [Integer] The user ID to generate a private channel for.
    # @return [Channel] A private channel for that user.
    def pm_channel(id)
      id = id.resolve_id
      return @pm_channels[id] if @pm_channels[id]
      debug("Creating pm channel with user id #{id}")
      response = API::User.create_pm(token, id)
      channel = Channel.new(JSON.parse(response), self)
      @pm_channels[id] = channel
    end

    alias_method :private_channel, :pm_channel

    # Ensures a given user object is cached and if not, cache it from the given data hash.
    # @param data [Hash] A data hash representing a user.
    # @return [User] the user represented by the data hash.
    def ensure_user(data)
      ensure_cache(@users, User, data)
    end

    # Ensures a given server object is cached and if not, cache it from the given data hash.
    # @param data [Hash] A data hash representing a server.
    # @return [Server] the server represented by the data hash.
    def ensure_server(data)
      ensure_cache(@servers, Server, data)
    end

    # Ensures a given channel object is cached and if not, cache it from the given data hash.
    # @param data [Hash] A data hash representing a channel.
    # @param server [Server, nil] The server the channel is on, if known.
    # @return [Channel] the channel represented by the data hash.
    def ensure_channel(data, server = nil)
      ensure_cache(@channels, Channel, data, server)
    end

    # Requests member chunks for a given server ID.
    # @param id [Integer] The server ID to request chunks for.
    def request_chunks(id)
      @gateway.send_request_members(id, '', 0)
    end

    # Gets the code for an invite.
    # @param invite [String, Invite] The invite to get the code for. Possible formats are:
    #
    #    * An {Invite} object
    #    * The code for an invite
    #    * A fully qualified invite URL (e. g. `https://discordapp.com/invite/0A37aN7fasF7n83q`)
    #    * A short invite URL with protocol (e. g. `https://discord.gg/0A37aN7fasF7n83q`)
    #    * A short invite URL without protocol (e. g. `discord.gg/0A37aN7fasF7n83q`)
    # @return [String] Only the code for the invite.
    def resolve_invite_code(invite)
      invite = invite.code if invite.is_a? Discordrb::Invite
      invite = invite[invite.rindex('/') + 1..-1] if invite.start_with?('http', 'discord.gg')
      invite
    end

    # Gets information about an invite.
    # @param invite [String, Invite] The invite to join. For possible formats see {#resolve_invite_code}.
    # @return [Invite] The invite with information about the given invite URL.
    def invite(invite)
      code = resolve_invite_code(invite)
      Invite.new(JSON.parse(API::Invite.resolve(token, code)), self)
    end

    # Finds a channel given its name and optionally the name of the server it is in.
    # @param channel_name [String] The channel to search for.
    # @param server_name [String] The server to search for, or `nil` if only the channel should be searched for.
    # @param type [Integer, nil] The type of channel to search for (0: text, 1: private, 2: voice, 3: group), or `nil` if any type of
    #   channel should be searched for
    # @return [Array<Channel>] The array of channels that were found. May be empty if none were found.
    def find_channel(channel_name, server_name = nil, type: nil)
      results = []

      if /<#(?<id>\d+)>?/ =~ channel_name
        # Check for channel mentions separately
        return [channel(id)]
      end

      @servers.values.each do |server|
        server.channels.each do |channel|
          results << channel if channel.name == channel_name && (server_name || server.name) == server.name && (!type || (channel.type == type))
        end
      end

      results
    end

    # Finds a user given its username.
    # @param username [String] The username to look for.
    # @return [Array<User>] The array of users that were found. May be empty if none were found.
    def find_user(username)
      @users.values.find_all { |e| e.username == username }
    end

    private

    def resolve_cache(id, cache, class_name)
      id = id.resolve_id
      return cache[id] if cache[id]

      LOGGER.out("Resolving #{class_name.downcase} #{id}")
      begin
        response = "Discordrb::API::#{class_name}".constantize.resolve(token, id)
      rescue RestClient::ResourceNotFound
        return nil
      end
      cache[id] = "Discordrb::#{class_name}".constantize.new(JSON.parse(response), self)
    end

    def ensure_cache(cache, cache_class, *data)
      id = data[0]['id'].to_i
      return cache[id] if cache.include?(id)
      cache[id] = if cache_class == Channel
                    cache_class.new(data[0], self, data[1])
                  else
                    cache_class.new(data[0], self)
                  end
    end
  end
end
