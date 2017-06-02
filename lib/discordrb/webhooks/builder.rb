require 'discordrb/webhooks/embeds'

module Discordrb::Webhooks
  # A class that acts as a builder for a webhook message object.
  class Builder
    def initialize(content: '', username: nil, avatar_url: nil, tts: false, file: nil, embeds: [])
      @content = content
      @username = username
      @avatar_url = avatar_url
      @tts = tts
      @file = file
      @embeds = embeds
    end

    # The content of the message. May be 2000 characters long at most.
    # @return [String] the content of the message.
    attr_accessor :content

    # The username the webhook will display as. If this is not set, the default username set in the webhook's settings
    # will be used instead.
    # @return [String] the username.
    attr_accessor :username

    # The URL of an image file to be used as an avatar. If this is not set, the default avatar from the webhook's
    # settings will be used instead.
    # @return [String] the avatar URL.
    attr_accessor :avatar_url

    # Whether this message should use TTS or not. By default, it doesn't.
    # @return [true, false] the TTS status.
    attr_accessor :tts

    # Sets a file to be sent together with the message. Mutually exclusive with embeds; a webhook message can contain
    # either a file to be sent or an embed.
    # @param file [File] A file to be sent.
    def file=(file)
      raise ArgumentError, 'Embeds and files are mutually exclusive!' unless @embeds.empty?
      @file = file
    end

    # Adds an embed to this message.
    # @param embed [Embed] The embed to add.
    def <<(embed)
      raise ArgumentError, 'Embeds and files are mutually exclusive!' if @file
      @embeds << embed
    end

    # Convenience method to add an embed using a block-style builder pattern
    # @example Add an embed to a message
    #   builder.add_embed do |embed|
    #     embed.title = 'Testing'
    #     embed.image = Discordrb::Webhooks::EmbedImage.new(url: 'https://i.imgur.com/PcMltU7.jpg')
    #   end
    # @param embed [Embed, nil] The embed to start the building process with, or nil if one should be created anew.
    # @return [Embed] The created embed.
    def add_embed(embed = nil)
      embed ||= Embed.new
      yield(embed)
      self << embed
      embed
    end

    # @return [File, nil] the file attached to this message.
    attr_reader :file

    # @return [Array<Embed>] the embeds attached to this message.
    attr_reader :embeds

    # @return [Hash] a hash representation of the created message, for JSON format.
    def to_json_hash
      {
        content: @content,
        username: @username,
        avatar_url: @avatar_url,
        tts: @tts,
        embeds: @embeds.map(&:to_hash)
      }
    end

    # @return [Hash] a hash representation of the created message, for multipart format.
    def to_multipart_hash
      {
        content: @content,
        username: @username,
        avatar_url: @avatar_url,
        tts: @tts,
        file: @file
      }
    end
  end
end
