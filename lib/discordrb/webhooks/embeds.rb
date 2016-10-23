module Discordrb::Webhooks
  # An embed is a multipart-style attachment to a webhook message that can have a variety of different purposes and
  # appearances.
  class Embed
    def initialize(title: nil, description: nil, url: nil, timestamp: nil, colour: nil, footer: nil, image: nil,
                   thumbnail: nil, video: nil, provider: nil, author: nil, fields: [])
      @title = title
      @description = description
      @url = url
      @timestamp = timestamp
      @colour = colour
      @footer = footer
      @image = image
      @thumbnail = thumbnail
      @video = video
      @provider = provider
      @author = author
      @fields = fields
    end

    # The title of this embed that will be displayed above everything else.
    # @return [String]
    attr_accessor :title

    # The description for this embed.
    # @return [String]
    attr_accessor :description

    # The URL the title should point to.
    # @return [String]
    attr_accessor :url

    # The timestamp for this embed. Will be displayed just below the title.
    # @return [Time]
    attr_accessor :timestamp
  end
end
