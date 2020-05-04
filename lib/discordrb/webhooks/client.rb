# frozen_string_literal: true

require 'rest-client'
require 'json'

require 'discordrb/webhooks/builder'

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
      @url = url || generate_url(id, token)
    end

    # Executes the webhook this client points to with the given data.
    # @param builder [Builder, nil] The builder to start out with, or nil if one should be created anew.
    # @param wait [true, false] Whether Discord should wait for the message to be successfully received by clients, or
    #   whether it should return immediately after sending the message.
    # @yield [builder] Gives the builder to the block to add additional steps, or to do the entire building process.
    # @yieldparam builder [Builder] The builder given as a parameter which is used as the initial step to start from.
    # @example Execute the webhook with an already existing builder
    #   builder = Discordrb::Webhooks::Builder.new # ...
    #   client.execute(builder)
    # @example Execute the webhook by building a new message
    #   client.execute do |builder|
    #     builder.content = 'Testing'
    #     builder.username = 'discordrb'
    #     builder.add_embed do |embed|
    #       embed.timestamp = Time.now
    #       embed.title = 'Testing'
    #       embed.image = Discordrb::Webhooks::EmbedImage.new(url: 'https://i.imgur.com/PcMltU7.jpg')
    #     end
    #   end
    # @return [RestClient::Response] the response returned by Discord.
    def execute(builder = nil, wait = false)
      raise TypeError, 'builder needs to be nil or like a Discordrb::Webhooks::Builder!' unless
        builder.respond_to?(:file) && builder.respond_to?(:to_multipart_hash) || builder.respond_to?(:to_json_hash) || builder.nil?

      builder ||= Builder.new

      yield builder if block_given?

      if builder.file
        post_multipart(builder, wait)
      else
        post_json(builder, wait)
      end
    end

    private

    def post_json(builder, wait)
      RestClient.post(@url + (wait ? '?wait=true' : ''), builder.to_json_hash.to_json, content_type: :json)
    end

    def post_multipart(builder, wait)
      RestClient.post(@url + (wait ? '?wait=true' : ''), builder.to_multipart_hash)
    end

    def generate_url(id, token)
      "https://discord.com/api/v6/webhooks/#{id}/#{token}"
    end
  end
end
