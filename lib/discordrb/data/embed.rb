# frozen_string_literal: true

module Discordrb
  # An Embed object that is contained in a message
  # A freshly generated embed object will not appear in a message object
  # unless grabbed from its ID in a channel.
  class Embed
    # @return [Message] the message this embed object is contained in.
    attr_reader :message

    # @return [String] the URL this embed object is based on.
    attr_reader :url

    # @return [String, nil] the title of the embed object. `nil` if there is not a title
    attr_reader :title

    # @return [String, nil] the description of the embed object. `nil` if there is not a description
    attr_reader :description

    # @return [Symbol] the type of the embed object. Possible types are:
    #
    #   * `:link`
    #   * `:video`
    #   * `:image`
    attr_reader :type

    # @return [Time, nil] the timestamp of the embed object. `nil` if there is not a timestamp
    attr_reader :timestamp

    # @return [String, nil] the color of the embed object. `nil` if there is not a color
    attr_reader :color
    alias_method :colour, :color

    # @return [EmbedFooter, nil] the footer of the embed object. `nil` if there is not a footer
    attr_reader :footer

    # @return [EmbedProvider, nil] the provider of the embed object. `nil` if there is not a provider
    attr_reader :provider

    # @return [EmbedImage, nil] the image of the embed object. `nil` if there is not an image
    attr_reader :image

    # @return [EmbedThumbnail, nil] the thumbnail of the embed object. `nil` if there is not a thumbnail
    attr_reader :thumbnail

    # @return [EmbedVideo, nil] the video of the embed object. `nil` if there is not a video
    attr_reader :video

    # @return [EmbedAuthor, nil] the author of the embed object. `nil` if there is not an author
    attr_reader :author

    # @return [Array<EmbedField>, nil] the fields of the embed object. `nil` if there are no fields
    attr_reader :fields

    # @!visibility private
    def initialize(data, message)
      @message = message

      @url = data['url']
      @title = data['title']
      @type = data['type'].to_sym
      @description = data['description']
      @timestamp = data['timestamp'].nil? ? nil : Time.parse(data['timestamp'])
      @color = data['color']
      @footer = data['footer'].nil? ? nil : EmbedFooter.new(data['footer'], self)
      @image = data['image'].nil? ? nil : EmbedImage.new(data['image'], self)
      @video = data['video'].nil? ? nil : EmbedVideo.new(data['video'], self)
      @provider = data['provider'].nil? ? nil : EmbedProvider.new(data['provider'], self)
      @thumbnail = data['thumbnail'].nil? ? nil : EmbedThumbnail.new(data['thumbnail'], self)
      @author = data['author'].nil? ? nil : EmbedAuthor.new(data['author'], self)
      @fields = data['fields'].nil? ? nil : data['fields'].map { |field| EmbedField.new(field, self) }
    end
  end

  # An Embed footer for the embed object.
  class EmbedFooter
    # @return [Embed] the embed object this is based on.
    attr_reader :embed

    # @return [String] the footer text.
    attr_reader :text

    # @return [String] the URL of the footer icon.
    attr_reader :icon_url

    # @return [String] the proxied URL of the footer icon.
    attr_reader :proxy_icon_url

    # @!visibility private
    def initialize(data, embed)
      @embed = embed

      @text = data['text']
      @icon_url = data['icon_url']
      @proxy_icon_url = data['proxy_icon_url']
    end
  end

  # An Embed image for the embed object.
  class EmbedImage
    # @return [Embed] the embed object this is based on.
    attr_reader :embed

    # @return [String] the source URL of the image.
    attr_reader :url

    # @return [String] the proxy URL of the image.
    attr_reader :proxy_url

    # @return [Integer] the width of the image, in pixels.
    attr_reader :width

    # @return [Integer] the height of the image, in pixels.
    attr_reader :height

    # @!visibility private
    def initialize(data, embed)
      @embed = embed

      @url = data['url']
      @proxy_url = data['proxy_url']
      @width = data['width']
      @height = data['height']
    end
  end

  # An Embed video for the embed object
  class EmbedVideo
    # @return [Embed] the embed object this is based on.
    attr_reader :embed

    # @return [String] the source URL of the video.
    attr_reader :url

    # @return [Integer] the width of the video, in pixels.
    attr_reader :width

    # @return [Integer] the height of the video, in pixels.
    attr_reader :height

    # @!visibility private
    def initialize(data, embed)
      @embed = embed

      @url = data['url']
      @width = data['width']
      @height = data['height']
    end
  end

  # An Embed thumbnail for the embed object
  class EmbedThumbnail
    # @return [Embed] the embed object this is based on.
    attr_reader :embed

    # @return [String] the CDN URL this thumbnail can be downloaded at.
    attr_reader :url

    # @return [String] the thumbnail's proxy URL - I'm not sure what exactly this does, but I think it has something to
    #   do with CDNs.
    attr_reader :proxy_url

    # @return [Integer] the width of this thumbnail file, in pixels.
    attr_reader :width

    # @return [Integer] the height of this thumbnail file, in pixels.
    attr_reader :height

    # @!visibility private
    def initialize(data, embed)
      @embed = embed

      @url = data['url']
      @proxy_url = data['proxy_url']
      @width = data['width']
      @height = data['height']
    end
  end

  # An Embed provider for the embed object
  class EmbedProvider
    # @return [Embed] the embed object this is based on.
    attr_reader :embed

    # @return [String] the provider's name.
    attr_reader :name

    # @return [String, nil] the URL of the provider, or `nil` if there is no URL.
    attr_reader :url

    # @!visibility private
    def initialize(data, embed)
      @embed = embed

      @name = data['name']
      @url = data['url']
    end
  end

  # An Embed author for the embed object
  class EmbedAuthor
    # @return [Embed] the embed object this is based on.
    attr_reader :embed

    # @return [String] the author's name.
    attr_reader :name

    # @return [String, nil] the URL of the author's website, or `nil` if there is no URL.
    attr_reader :url

    # @return [String, nil] the icon of the author, or `nil` if there is no icon.
    attr_reader :icon_url

    # @return [String, nil] the Discord proxy URL, or `nil` if there is no `icon_url`.
    attr_reader :proxy_icon_url

    # @!visibility private
    def initialize(data, embed)
      @embed = embed

      @name = data['name']
      @url = data['url']
      @icon_url = data['icon_url']
      @proxy_icon_url = data['proxy_icon_url']
    end
  end

  # An Embed field for the embed object
  class EmbedField
    # @return [Embed] the embed object this is based on.
    attr_reader :embed

    # @return [String] the field's name.
    attr_reader :name

    # @return [String] the field's value.
    attr_reader :value

    # @return [true, false] whether this field is inline.
    attr_reader :inline

    # @!visibility private
    def initialize(data, embed)
      @embed = embed

      @name = data['name']
      @value = data['value']
      @inline = data['inline']
    end
  end
end
