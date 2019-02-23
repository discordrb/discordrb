# frozen_string_literal: true

module Discordrb
  # An attachment to a message
  class Attachment
    include IDObject

    # @return [Message] the message this attachment belongs to.
    attr_reader :message

    # @return [String] the CDN URL this attachment can be downloaded at.
    attr_reader :url

    # @return [String] the attachment's proxy URL - I'm not sure what exactly this does, but I think it has something to
    #   do with CDNs.
    attr_reader :proxy_url

    # @return [String] the attachment's filename.
    attr_reader :filename

    # @return [Integer] the attachment's file size in bytes.
    attr_reader :size

    # @return [Integer, nil] the width of an image file, in pixels, or `nil` if the file is not an image.
    attr_reader :width

    # @return [Integer, nil] the height of an image file, in pixels, or `nil` if the file is not an image.
    attr_reader :height

    # @!visibility private
    def initialize(data, message, bot)
      @bot = bot
      @message = message

      @id = data['id'].to_i
      @url = data['url']
      @proxy_url = data['proxy_url']
      @filename = data['filename']

      @size = data['size']

      @width = data['width']
      @height = data['height']
    end

    # @return [true, false] whether this file is an image file.
    def image?
      !(@width.nil? || @height.nil?)
    end

    # @return [true, false] whether this file is tagged as a spoiler.
    def spoiler?
      @filename.start_with? 'SPOILER_'
    end
  end
end
