require 'rest-client'

module Discordrb::Webhooks
  # A client for a particular webhook added to a Discord channel.
  class Client
    # Create a new webhook
    # @param url [String] The URL to post messages to.
    # @param id [Integer] The webhook's ID. Will only be used if `url` is not
    #   set.
    # @param token [String] The webhook's authorisation token. Will only be used
    #   if `url` is not set.
    def initialize(url: nil, id: nil, token: nil)
      @url = if url
               url
             else
               generate_url(id, token)
             end
    end

    private

    def post_multipart(builder)
      RestClient.post(@url, builder.to_multipart_hash)
    end

    def generate_url(id, token)
      "https://discordapp.com/api/v6/webhooks/#{id}/#{token}"
    end
  end
end
