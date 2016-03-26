# frozen_string_literal: true

# This module contains classes to allow connections to bots without a connection to the gateway socket, i. e. bots
# that only use the REST part of the API.
module Discordrb::Light
  # A bot that only uses the REST part of the API. Hierarchically unrelated to the regular {Discordrb::Bot}. Useful to
  # make applications integrated to Discord over OAuth, for example.
  class LightBot
    # Create a new LightBot. This does no networking yet, all networking is done by the methods on this class.
    # @param token [String] The token that should be used to authenticate to Discord. Can be an OAuth token or a regular
    #   user account token.
    def initialize(token)
      @token = token
    end
  end
end
