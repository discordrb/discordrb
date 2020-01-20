# frozen_string_literal: true

require 'discordrb/api'
require 'discordrb/api/invite'
require 'discordrb/api/user'
require 'discordrb/light/data'
require 'discordrb/light/integrations'

# This module contains classes to allow connections to bots without a connection to the gateway socket, i.e. bots
# that only use the REST part of the API.
module Discordrb::Light
  # A bot that only uses the REST part of the API. Hierarchically unrelated to the regular {Discordrb::Bot}. Useful to
  # make applications integrated to Discord over OAuth, for example.
  class LightBot
    # Create a new LightBot. This does no networking yet, all networking is done by the methods on this class.
    # @param token [String] The token that should be used to authenticate to Discord. Can be an OAuth token or a regular
    #   user account token.
    def initialize(token)
      if token.respond_to? :token
        # Parse AccessTokens from the OAuth2 gem
        token = token.token
      end

      unless token.include? '.'
        # Discord user/bot tokens always contain two dots, so if there's none we can assume it's an OAuth token.
        token = "Bearer #{token}" # OAuth tokens have to be prefixed with 'Bearer' for Discord to be able to use them
      end

      @token = token
    end

    # @return [LightProfile] the details of the user this bot is connected to.
    def profile
      response = Discordrb::API::User.profile(@token)
      LightProfile.new(JSON.parse(response), self)
    end

    # @return [Array<LightServer>] the servers this bot is connected to.
    def servers
      response = Discordrb::API::User.servers(@token)
      JSON.parse(response).map { |e| LightServer.new(e, self) }
    end

    # Joins a server using an instant invite.
    # @param code [String] The code part of the invite (for example 0cDvIgU2voWn4BaD if the invite URL is
    #   https://discord.gg/0cDvIgU2voWn4BaD)
    def join(code)
      Discordrb::API::Invite.accept(@token, code)
    end

    # Gets the connections associated with this account.
    # @return [Array<Connection>] this account's connections.
    def connections
      response = Discordrb::API::User.connections(@token)
      JSON.parse(response).map { |e| Connection.new(e, self) }
    end
  end
end
